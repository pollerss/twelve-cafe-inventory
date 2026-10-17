-- THE TWELVE CAFE: upgrade existing database IN PLACE.
-- Run once in Supabase SQL Editor. Does not reset quantities or history.
BEGIN;
ALTER TABLE public.inventory_items ADD COLUMN IF NOT EXISTS stock_unit text;
ALTER TABLE public.inventory_items ADD COLUMN IF NOT EXISTS pack_unit text;
ALTER TABLE public.inventory_items ADD COLUMN IF NOT EXISTS units_per_pack numeric(16,3);
ALTER TABLE public.inventory_items ADD CONSTRAINT inventory_pack_conversion_positive CHECK (units_per_pack IS NULL OR units_per_pack > 0);
ALTER TABLE public.inventory_transactions ADD COLUMN IF NOT EXISTS reason_code text;
ALTER TABLE public.inventory_transactions ADD COLUMN IF NOT EXISTS detail text;
ALTER TABLE public.inventory_transactions ADD COLUMN IF NOT EXISTS entered_unit text;
ALTER TABLE public.inventory_transactions ADD COLUMN IF NOT EXISTS entered_quantity numeric(16,3);
ALTER TABLE public.restock_requests ADD COLUMN IF NOT EXISTS notes text;

-- Readable employee names come from profiles, not an editable actor field.
-- All mutations go through role-checked, audited RPCs.
CREATE OR REPLACE FUNCTION public.edit_inventory_item_v2(
 p_item_id uuid,p_expected_version integer,p_name text,p_stock_unit text,
 p_pack_unit text,p_units_per_pack numeric,p_min numeric,p_target numeric,p_notes text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_item public.inventory_items%rowtype;
BEGIN
 IF public.current_role() NOT IN ('manager','admin') THEN RAISE EXCEPTION 'Manager access required'; END IF;
 IF trim(coalesce(p_name,''))='' OR trim(coalesce(p_stock_unit,''))='' THEN RAISE EXCEPTION 'Name and base unit required'; END IF;
 IF (p_min IS NOT NULL AND p_min<0) OR (p_target IS NOT NULL AND p_target<0) THEN RAISE EXCEPTION 'Invalid stock threshold'; END IF;
 IF p_target IS NOT NULL AND p_min IS NOT NULL AND p_target<p_min THEN RAISE EXCEPTION 'Target must be at least minimum'; END IF;
 IF nullif(trim(coalesce(p_pack_unit,'')),'') IS NOT NULL AND (p_units_per_pack IS NULL OR p_units_per_pack<=0) THEN RAISE EXCEPTION 'Define units per pack'; END IF;
 SELECT * INTO v_item FROM public.inventory_items WHERE id=p_item_id AND archived=false FOR UPDATE;
 IF NOT FOUND OR v_item.version<>p_expected_version THEN RAISE EXCEPTION 'Item changed; refresh'; END IF;
 -- Changing base unit without migration would reinterpret existing quantities.
 IF v_item.quantity IS NOT NULL AND trim(coalesce(v_item.stock_unit,v_item.unit,'')) <> ''
    AND trim(coalesce(v_item.stock_unit,v_item.unit,'')) <> trim(p_stock_unit) THEN
   RAISE EXCEPTION 'Cannot change base unit after stock has been recorded. Convert stock using a controlled migration.';
 END IF;
 UPDATE public.inventory_items SET name=trim(p_name),stock_unit=trim(p_stock_unit),unit=trim(p_stock_unit),
   pack_unit=nullif(trim(coalesce(p_pack_unit,'')),''),units_per_pack=CASE WHEN nullif(trim(coalesce(p_pack_unit,'')),'') IS NULL THEN NULL ELSE p_units_per_pack END,
   min_stock=p_min,target_stock=p_target,notes=p_notes,version=version+1,
   updated_at=now(),updated_by=auth.uid() WHERE id=p_item_id;
 INSERT INTO public.inventory_transactions(item_id,kind,before_qty,after_qty,reason,actor,detail)
 VALUES(p_item_id,'ITEM_EDIT',v_item.quantity,v_item.quantity,'Item details, units or thresholds edited',auth.uid(),
  'Previous base unit: '||coalesce(v_item.stock_unit,v_item.unit,'(unset)')||'; new base unit: '||p_stock_unit);
END $$;

CREATE OR REPLACE FUNCTION public.move_stock_v2(
 p_item_id uuid,p_expected_version integer,p_direction text,p_amount numeric,
 p_entry_unit text,p_reason_code text,p_detail text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_item public.inventory_items%rowtype; v_delta numeric;v_after numeric;v_kind text;v_unit text;
BEGIN
 IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
 IF p_direction NOT IN ('IN','OUT') THEN RAISE EXCEPTION 'Invalid stock movement'; END IF;
 IF p_amount IS NULL OR p_amount<=0 THEN RAISE EXCEPTION 'Enter a positive quantity'; END IF;
 IF p_reason_code NOT IN ('DELIVERY','PURCHASE','PRODUCTION','RETURN','USED','SOLD','EXPIRED','DAMAGED','SPOILED','SPILLED','LOST','WASTE','TRANSFER','OTHER') THEN RAISE EXCEPTION 'Select a valid reason'; END IF;
 IF p_direction='OUT' AND p_reason_code IN ('DELIVERY','PURCHASE','PRODUCTION') THEN RAISE EXCEPTION 'Invalid stock out reason'; END IF;
 IF p_direction='IN' AND p_reason_code IN ('EXPIRED','DAMAGED','SPOILED','SPILLED','LOST','WASTE','USED','SOLD') THEN RAISE EXCEPTION 'Invalid stock in reason'; END IF;
 IF p_reason_code='OTHER' AND trim(coalesce(p_detail,''))='' THEN RAISE EXCEPTION 'Explain other reason'; END IF;
 SELECT * INTO v_item FROM public.inventory_items WHERE id=p_item_id AND archived=false FOR UPDATE;
 IF NOT FOUND THEN RAISE EXCEPTION 'Item not found'; END IF;
 IF v_item.version<>p_expected_version THEN RAISE EXCEPTION 'Inventory changed; refresh and retry'; END IF;
 IF v_item.quantity IS NULL THEN RAISE EXCEPTION 'Record a physical count first'; END IF;
 v_unit:=coalesce(nullif(v_item.stock_unit,''),nullif(v_item.unit,''),'unit');
 IF p_entry_unit=v_unit THEN v_delta:=p_amount;
 ELSIF p_entry_unit=v_item.pack_unit AND v_item.units_per_pack>0 THEN v_delta:=p_amount*v_item.units_per_pack;
 ELSE RAISE EXCEPTION 'Unit is not configured for this item'; END IF;
 IF p_direction='OUT' THEN v_delta:=-v_delta;END IF;
 v_after:=v_item.quantity+v_delta;
 IF v_after<0 THEN RAISE EXCEPTION 'Insufficient inventory'; END IF;
 v_kind:=CASE WHEN p_direction='IN' THEN 'STOCK_IN' ELSE 'STOCK_OUT' END;
 UPDATE public.inventory_items SET quantity=v_after,version=version+1,updated_at=now(),updated_by=auth.uid() WHERE id=p_item_id;
 INSERT INTO public.inventory_transactions(item_id,kind,before_qty,delta,after_qty,reason,actor,reason_code,detail,entered_unit,entered_quantity)
 VALUES(p_item_id,v_kind,v_item.quantity,v_delta,v_after,p_reason_code||CASE WHEN trim(coalesce(p_detail,''))<>'' THEN ': '||trim(p_detail) ELSE '' END,
 auth.uid(),p_reason_code,nullif(trim(coalesce(p_detail,'')),''),p_entry_unit,p_amount);
END $$;

CREATE OR REPLACE FUNCTION public.set_restock_status_v2(p_request_id uuid,p_status text)
RETURNS void LANGUAGE plpgsql SECURITY DEFINER SET search_path='' AS $$
DECLARE v_request public.restock_requests%rowtype;
BEGIN
 IF public.current_role() NOT IN ('manager','admin') THEN RAISE EXCEPTION 'Manager access required'; END IF;
 IF p_status NOT IN ('ORDERED','CANCELLED') THEN RAISE EXCEPTION 'Invalid status'; END IF;
 SELECT * INTO v_request FROM public.restock_requests WHERE id=p_request_id FOR UPDATE;
 IF NOT FOUND OR v_request.status IN ('CANCELLED','RECEIVED') THEN RAISE EXCEPTION 'Request is closed'; END IF;
 IF p_status='CANCELLED' AND v_request.received_qty>0 THEN RAISE EXCEPTION 'Partially received request cannot be cancelled'; END IF;
 UPDATE public.restock_requests SET status=p_status WHERE id=p_request_id;
 INSERT INTO public.inventory_transactions(item_id,kind,before_qty,after_qty,reason,actor)
 VALUES(v_request.item_id,'RESTOCK_'||p_status,NULL,NULL,'Restock request '||v_request.id,auth.uid());
END $$;

REVOKE ALL ON FUNCTION public.edit_inventory_item_v2(uuid,integer,text,text,text,numeric,numeric,numeric,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.move_stock_v2(uuid,integer,text,numeric,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.set_restock_status_v2(uuid,text) FROM PUBLIC;
GRANT EXECUTE ON FUNCTION public.edit_inventory_item_v2(uuid,integer,text,text,text,numeric,numeric,numeric,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.move_stock_v2(uuid,integer,text,numeric,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.set_restock_status_v2(uuid,text) TO authenticated;
GRANT SELECT ON public.profiles,public.inventory_items,public.inventory_transactions,public.restock_requests TO authenticated;
GRANT INSERT ON public.restock_requests TO authenticated;
COMMIT;
