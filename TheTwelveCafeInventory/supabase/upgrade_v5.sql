-- THE TWELVE CAFE INVENTORY v5
-- Adds safe item creation, richer item metadata, audited physical-count corrections,
-- archive/restore, and employee display-name editing.
-- Run ONCE after upgrade_v2.sql and upgrade_v3.sql on an existing working project.
-- This migration does not delete, reset, or re-import existing inventory.

BEGIN;

ALTER TABLE public.inventory_items ADD COLUMN IF NOT EXISTS item_category text;
ALTER TABLE public.inventory_items ADD COLUMN IF NOT EXISTS storage_location text;
ALTER TABLE public.inventory_items ADD COLUMN IF NOT EXISTS supplier_name text;
ALTER TABLE public.inventory_items ADD COLUMN IF NOT EXISTS barcode text;

CREATE UNIQUE INDEX IF NOT EXISTS inventory_items_barcode_unique_v5
  ON public.inventory_items (barcode)
  WHERE barcode IS NOT NULL AND btrim(barcode) <> '';

CREATE SEQUENCE IF NOT EXISTS public.inventory_code_seq_v5;
SELECT setval(
  'public.inventory_code_seq_v5',
  GREATEST(
    COALESCE((
      SELECT max(substring(code from '^TC-([0-9]+)$')::bigint)
      FROM public.inventory_items
      WHERE code ~ '^TC-[0-9]+$'
    ), 0),
    1
  ),
  true
);

CREATE OR REPLACE FUNCTION public.add_inventory_item_v5(
  p_name text,
  p_inventory_type text,
  p_stock_unit text,
  p_code text,
  p_pack_unit text,
  p_units_per_pack numeric,
  p_min numeric,
  p_target numeric,
  p_notes text,
  p_category text,
  p_storage_location text,
  p_supplier_name text,
  p_barcode text,
  p_initial_qty numeric
)
RETURNS text
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $$
DECLARE
  v_id uuid;
  v_code text;
  v_barcode text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
  IF public.current_role() NOT IN ('manager','admin') THEN RAISE EXCEPTION 'Manager access required'; END IF;
  IF btrim(coalesce(p_name,'')) = '' THEN RAISE EXCEPTION 'Item name required'; END IF;
  IF p_inventory_type NOT IN ('General Inventory','Production Inventory') THEN RAISE EXCEPTION 'Invalid inventory type'; END IF;
  IF btrim(coalesce(p_stock_unit,'')) = '' THEN RAISE EXCEPTION 'Base unit required'; END IF;
  IF p_initial_qty IS NOT NULL AND p_initial_qty < 0 THEN RAISE EXCEPTION 'Initial quantity cannot be negative'; END IF;
  IF (p_min IS NOT NULL AND p_min < 0) OR (p_target IS NOT NULL AND p_target < 0) THEN RAISE EXCEPTION 'Invalid stock threshold'; END IF;
  IF p_min IS NOT NULL AND p_target IS NOT NULL AND p_target < p_min THEN RAISE EXCEPTION 'Target must be at least minimum'; END IF;
  IF nullif(btrim(coalesce(p_pack_unit,'')),'') IS NOT NULL AND (p_units_per_pack IS NULL OR p_units_per_pack <= 0) THEN
    RAISE EXCEPTION 'Define a positive purchase-unit conversion';
  END IF;

  v_barcode := nullif(btrim(coalesce(p_barcode,'')), '');
  IF v_barcode IS NOT NULL AND EXISTS (SELECT 1 FROM public.inventory_items WHERE barcode = v_barcode) THEN
    RAISE EXCEPTION 'Barcode / QR value is already assigned to another item';
  END IF;

  v_code := upper(nullif(btrim(coalesce(p_code,'')), ''));
  IF v_code IS NULL THEN
    LOOP
      v_code := 'TC-' || lpad(nextval('public.inventory_code_seq_v5')::text, 4, '0');
      EXIT WHEN NOT EXISTS (SELECT 1 FROM public.inventory_items WHERE code = v_code);
    END LOOP;
  ELSIF EXISTS (SELECT 1 FROM public.inventory_items WHERE code = v_code) THEN
    RAISE EXCEPTION 'Item ID already exists';
  END IF;

  INSERT INTO public.inventory_items(
    code,name,inventory_type,quantity,unit,stock_unit,pack_unit,units_per_pack,
    min_stock,target_stock,version,archived,updated_at,updated_by,notes,
    item_category,storage_location,supplier_name,barcode
  )
  VALUES(
    v_code,btrim(p_name),p_inventory_type,p_initial_qty,btrim(p_stock_unit),btrim(p_stock_unit),
    nullif(btrim(coalesce(p_pack_unit,'')),''),
    CASE WHEN nullif(btrim(coalesce(p_pack_unit,'')),'') IS NULL THEN NULL ELSE p_units_per_pack END,
    p_min,p_target,0,false,now(),auth.uid(),nullif(btrim(coalesce(p_notes,'')),''),
    nullif(btrim(coalesce(p_category,'')),''),nullif(btrim(coalesce(p_storage_location,'')),''),
    nullif(btrim(coalesce(p_supplier_name,'')),''),v_barcode
  )
  RETURNING id INTO v_id;

  INSERT INTO public.inventory_transactions(item_id,kind,before_qty,delta,after_qty,reason,actor,detail)
  VALUES(v_id,'ITEM_CREATED',NULL,NULL,NULL,'Inventory item created',auth.uid(),
    'Item ID: '||v_code||'; inventory type: '||p_inventory_type);

  IF p_initial_qty IS NOT NULL THEN
    INSERT INTO public.inventory_transactions(
      item_id,kind,before_qty,delta,after_qty,reason,actor,reason_code,detail,entered_unit,entered_quantity
    ) VALUES(
      v_id,'INITIAL_COUNT',NULL,NULL,p_initial_qty,'Initial physical count recorded during item creation',auth.uid(),
      'INITIAL_SETUP','Recorded when item was created',btrim(p_stock_unit),p_initial_qty
    );
  END IF;

  RETURN v_code;
END $$;

CREATE OR REPLACE FUNCTION public.edit_inventory_item_v5(
  p_item_id uuid,
  p_expected_version integer,
  p_name text,
  p_stock_unit text,
  p_pack_unit text,
  p_units_per_pack numeric,
  p_min numeric,
  p_target numeric,
  p_notes text,
  p_category text,
  p_storage_location text,
  p_supplier_name text,
  p_barcode text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $$
DECLARE
  v_item public.inventory_items%rowtype;
  v_barcode text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
  IF public.current_role() NOT IN ('manager','admin') THEN RAISE EXCEPTION 'Manager access required'; END IF;
  IF btrim(coalesce(p_name,''))='' OR btrim(coalesce(p_stock_unit,''))='' THEN RAISE EXCEPTION 'Name and base unit required'; END IF;
  IF (p_min IS NOT NULL AND p_min<0) OR (p_target IS NOT NULL AND p_target<0) THEN RAISE EXCEPTION 'Invalid stock threshold'; END IF;
  IF p_target IS NOT NULL AND p_min IS NOT NULL AND p_target<p_min THEN RAISE EXCEPTION 'Target must be at least minimum'; END IF;
  IF nullif(btrim(coalesce(p_pack_unit,'')),'') IS NOT NULL AND (p_units_per_pack IS NULL OR p_units_per_pack<=0) THEN RAISE EXCEPTION 'Define units per pack'; END IF;

  SELECT * INTO v_item FROM public.inventory_items WHERE id=p_item_id AND archived=false FOR UPDATE;
  IF NOT FOUND OR v_item.version<>p_expected_version THEN RAISE EXCEPTION 'Item changed; refresh'; END IF;

  IF v_item.quantity IS NOT NULL
     AND btrim(coalesce(v_item.stock_unit,v_item.unit,'')) <> ''
     AND btrim(coalesce(v_item.stock_unit,v_item.unit,'')) <> btrim(p_stock_unit) THEN
    RAISE EXCEPTION 'Cannot change base unit after stock has been recorded. Use a controlled stock conversion.';
  END IF;

  v_barcode := nullif(btrim(coalesce(p_barcode,'')), '');
  IF v_barcode IS NOT NULL AND EXISTS (
    SELECT 1 FROM public.inventory_items WHERE barcode=v_barcode AND id<>p_item_id
  ) THEN RAISE EXCEPTION 'Barcode / QR value is already assigned to another item'; END IF;

  UPDATE public.inventory_items
  SET name=btrim(p_name),
      stock_unit=btrim(p_stock_unit),
      unit=btrim(p_stock_unit),
      pack_unit=nullif(btrim(coalesce(p_pack_unit,'')),''),
      units_per_pack=CASE WHEN nullif(btrim(coalesce(p_pack_unit,'')),'') IS NULL THEN NULL ELSE p_units_per_pack END,
      min_stock=p_min,
      target_stock=p_target,
      notes=nullif(btrim(coalesce(p_notes,'')),''),
      item_category=nullif(btrim(coalesce(p_category,'')),''),
      storage_location=nullif(btrim(coalesce(p_storage_location,'')),''),
      supplier_name=nullif(btrim(coalesce(p_supplier_name,'')),''),
      barcode=v_barcode,
      version=version+1,
      updated_at=now(),
      updated_by=auth.uid()
  WHERE id=p_item_id;

  INSERT INTO public.inventory_transactions(item_id,kind,before_qty,after_qty,reason,actor,detail)
  VALUES(p_item_id,'ITEM_EDIT',v_item.quantity,v_item.quantity,'Item settings edited',auth.uid(),
    'Previous base unit: '||coalesce(v_item.stock_unit,v_item.unit,'(unset)')||'; new base unit: '||p_stock_unit);
END $$;

CREATE OR REPLACE FUNCTION public.adjust_inventory_count_v5(
  p_item_id uuid,
  p_expected_version integer,
  p_physical_count numeric,
  p_reason_code text,
  p_detail text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $$
DECLARE
  v_item public.inventory_items%rowtype;
  v_delta numeric;
  v_unit text;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
  IF public.current_role() NOT IN ('manager','admin') THEN RAISE EXCEPTION 'Manager access required'; END IF;
  IF p_physical_count IS NULL OR p_physical_count < 0 THEN RAISE EXCEPTION 'Enter a valid physical count'; END IF;
  IF p_reason_code NOT IN ('PHYSICAL_RECOUNT','COUNTING_ERROR','DATA_CORRECTION','FOUND_STOCK','OTHER') THEN RAISE EXCEPTION 'Select a valid correction reason'; END IF;
  IF p_reason_code='OTHER' AND btrim(coalesce(p_detail,''))='' THEN RAISE EXCEPTION 'Explain the correction'; END IF;

  SELECT * INTO v_item FROM public.inventory_items WHERE id=p_item_id AND archived=false FOR UPDATE;
  IF NOT FOUND OR v_item.version<>p_expected_version THEN RAISE EXCEPTION 'Inventory changed; refresh and retry'; END IF;
  IF v_item.quantity IS NULL THEN RAISE EXCEPTION 'Record the initial physical count first'; END IF;
  IF v_item.quantity=p_physical_count THEN RAISE EXCEPTION 'Physical count already matches recorded stock'; END IF;

  v_delta := p_physical_count-v_item.quantity;
  v_unit := coalesce(nullif(v_item.stock_unit,''),nullif(v_item.unit,''),'unit');

  UPDATE public.inventory_items
  SET quantity=p_physical_count,version=version+1,updated_at=now(),updated_by=auth.uid()
  WHERE id=p_item_id;

  INSERT INTO public.inventory_transactions(
    item_id,kind,before_qty,delta,after_qty,reason,actor,reason_code,detail,entered_unit,entered_quantity
  ) VALUES(
    p_item_id,'ADJUSTMENT',v_item.quantity,v_delta,p_physical_count,
    p_reason_code||CASE WHEN btrim(coalesce(p_detail,''))<>'' THEN ': '||btrim(p_detail) ELSE '' END,
    auth.uid(),p_reason_code,nullif(btrim(coalesce(p_detail,'')),''),v_unit,p_physical_count
  );
END $$;

CREATE OR REPLACE FUNCTION public.archive_inventory_item_v5(
  p_item_id uuid,
  p_expected_version integer,
  p_reason text
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $$
DECLARE
  v_item public.inventory_items%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
  IF public.current_role() NOT IN ('manager','admin') THEN RAISE EXCEPTION 'Manager access required'; END IF;
  IF btrim(coalesce(p_reason,''))='' THEN RAISE EXCEPTION 'Archive reason required'; END IF;

  SELECT * INTO v_item FROM public.inventory_items WHERE id=p_item_id AND archived=false FOR UPDATE;
  IF NOT FOUND OR v_item.version<>p_expected_version THEN RAISE EXCEPTION 'Item changed; refresh'; END IF;

  IF EXISTS (
    SELECT 1 FROM public.restock_requests
    WHERE item_id=p_item_id AND status NOT IN ('RECEIVED','CANCELLED')
  ) THEN RAISE EXCEPTION 'Close open restock requests before archiving this item'; END IF;

  UPDATE public.inventory_items
  SET archived=true,version=version+1,updated_at=now(),updated_by=auth.uid()
  WHERE id=p_item_id;

  INSERT INTO public.inventory_transactions(item_id,kind,before_qty,after_qty,reason,actor,detail)
  VALUES(p_item_id,'ITEM_ARCHIVED',v_item.quantity,v_item.quantity,'Item archived',auth.uid(),btrim(p_reason));
END $$;

CREATE OR REPLACE FUNCTION public.restore_inventory_item_v5(p_item_id uuid)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $$
DECLARE
  v_item public.inventory_items%rowtype;
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
  IF public.current_role() NOT IN ('manager','admin') THEN RAISE EXCEPTION 'Manager access required'; END IF;

  SELECT * INTO v_item FROM public.inventory_items WHERE id=p_item_id AND archived=true FOR UPDATE;
  IF NOT FOUND THEN RAISE EXCEPTION 'Archived item not found'; END IF;

  UPDATE public.inventory_items
  SET archived=false,version=version+1,updated_at=now(),updated_by=auth.uid()
  WHERE id=p_item_id;

  INSERT INTO public.inventory_transactions(item_id,kind,before_qty,after_qty,reason,actor)
  VALUES(p_item_id,'ITEM_RESTORED',v_item.quantity,v_item.quantity,'Archived item restored',auth.uid());
END $$;

CREATE OR REPLACE FUNCTION public.update_my_profile_v5(p_display_name text)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path=''
AS $$
BEGIN
  IF auth.uid() IS NULL THEN RAISE EXCEPTION 'Login required'; END IF;
  IF length(btrim(coalesce(p_display_name,''))) < 2 OR length(btrim(p_display_name)) > 80 THEN
    RAISE EXCEPTION 'Display name must be between 2 and 80 characters';
  END IF;
  UPDATE public.profiles SET display_name=btrim(p_display_name) WHERE id=auth.uid();
END $$;

-- Close the direct item-write path. Creation/edit/archive must use audited functions.
REVOKE INSERT, UPDATE, DELETE ON public.inventory_items FROM authenticated;
GRANT SELECT ON public.inventory_items TO authenticated;

REVOKE ALL ON FUNCTION public.add_inventory_item_v5(text,text,text,text,text,numeric,numeric,numeric,text,text,text,text,text,numeric) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.edit_inventory_item_v5(uuid,integer,text,text,text,numeric,numeric,numeric,text,text,text,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.adjust_inventory_count_v5(uuid,integer,numeric,text,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.archive_inventory_item_v5(uuid,integer,text) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.restore_inventory_item_v5(uuid) FROM PUBLIC;
REVOKE ALL ON FUNCTION public.update_my_profile_v5(text) FROM PUBLIC;

GRANT EXECUTE ON FUNCTION public.add_inventory_item_v5(text,text,text,text,text,numeric,numeric,numeric,text,text,text,text,text,numeric) TO authenticated;
GRANT EXECUTE ON FUNCTION public.edit_inventory_item_v5(uuid,integer,text,text,text,numeric,numeric,numeric,text,text,text,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.adjust_inventory_count_v5(uuid,integer,numeric,text,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.archive_inventory_item_v5(uuid,integer,text) TO authenticated;
GRANT EXECUTE ON FUNCTION public.restore_inventory_item_v5(uuid) TO authenticated;
GRANT EXECUTE ON FUNCTION public.update_my_profile_v5(text) TO authenticated;

COMMIT;
