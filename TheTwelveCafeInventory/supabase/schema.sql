-- Run in a new Supabase project's SQL editor. Set up Auth email accounts through Supabase.
create extension if not exists pgcrypto;
create table public.profiles (
 id uuid primary key references auth.users(id) on delete cascade,
 display_name text not null default '',
 role text not null default 'staff' check (role in ('admin','manager','staff'))
);
create table public.inventory_items (
 id uuid primary key default gen_random_uuid(),
 code text not null unique, name text not null, inventory_type text not null check (inventory_type in ('General Inventory','Production Inventory')),
 quantity numeric(16,3) check(quantity >= 0), unit text,
 min_stock numeric(16,3) check(min_stock >= 0), target_stock numeric(16,3) check(target_stock >= 0),
 version integer not null default 0, archived boolean not null default false,
 updated_at timestamptz not null default now(), updated_by uuid references auth.users(id),
 notes text, source_sheet text, source_row integer
);
create table public.inventory_transactions (
 id uuid primary key default gen_random_uuid(), item_id uuid not null references public.inventory_items(id),
 kind text not null, before_qty numeric(16,3), delta numeric(16,3), after_qty numeric(16,3),
 reason text not null, actor uuid not null references auth.users(id), created_at timestamptz not null default now(),
 constraint transaction_quantity_consistency check (after_qty is null or after_qty >= 0)
);
create table public.restock_requests (
 id uuid primary key default gen_random_uuid(), item_id uuid not null references public.inventory_items(id),
 requested_qty numeric(16,3) not null check(requested_qty>0),
 received_qty numeric(16,3) not null default 0 check(received_qty>=0),
 status text not null default 'REQUESTED' check(status in ('REQUESTED','ORDERED','PARTIALLY RECEIVED','RECEIVED','CANCELLED')),
 requested_by uuid not null references auth.users(id), created_at timestamptz not null default now(),
 check(received_qty<=requested_qty)
);
create index on public.inventory_items(inventory_type, archived);
create index on public.inventory_transactions(item_id,created_at desc);
create index on public.restock_requests(status,created_at desc);
create or replace function public.current_role() returns text language sql stable security definer set search_path='' as $$
 select role from public.profiles where id=auth.uid()
$$;
create or replace function public.handle_new_user() returns trigger language plpgsql security definer set search_path='' as $$
begin insert into public.profiles(id,display_name) values(new.id,coalesce(new.raw_user_meta_data->>'display_name','')) on conflict do nothing; return new; end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function public.handle_new_user();
alter table public.profiles enable row level security;
alter table public.inventory_items enable row level security;
alter table public.inventory_transactions enable row level security;
alter table public.restock_requests enable row level security;
create policy profiles_read on public.profiles for select to authenticated using (true);
create policy items_read on public.inventory_items for select to authenticated using (true);
-- No direct client UPDATE policy: inventory edits require audited SECURITY DEFINER RPCs.
-- Metadata edits can be added using a separate role-checked RPC.
create policy items_create on public.inventory_items for insert to authenticated with check(public.current_role() in ('manager','admin'));
create policy history_read on public.inventory_transactions for select to authenticated using (true);
create policy restocks_read on public.restock_requests for select to authenticated using (true);
create policy restocks_create on public.restock_requests for insert to authenticated with check(requested_by=auth.uid());
-- Writes to quantities/history are performed only through server-side RPCs.
create or replace function public.apply_inventory_movement(p_item_id uuid,p_kind text,p_amount numeric,p_expected_version integer,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare v_item public.inventory_items%rowtype; v_after numeric;
begin
 if auth.uid() is null then raise exception 'Login required'; end if;
 if p_kind not in ('STOCK_IN','STOCK_OUT','ADJUSTMENT','PRODUCTION','DAILY_COUNT_ADJUSTMENT') then raise exception 'Invalid transaction type'; end if;
 if p_kind in ('ADJUSTMENT','DAILY_COUNT_ADJUSTMENT') and public.current_role() not in ('manager','admin') then raise exception 'Manager approval required'; end if;
 if p_amount<=0 or p_amount is null or trim(coalesce(p_reason,''))='' then raise exception 'Provide a positive quantity and reason'; end if;
 select * into v_item from public.inventory_items where id=p_item_id and archived=false for update;
 if not found then raise exception 'Item not found'; end if;
 if v_item.version<>p_expected_version then raise exception 'Inventory changed; refresh and retry'; end if;
 if v_item.quantity is null then raise exception 'Quantity unrecorded; manager must initialize physical count'; end if;
 v_after:=v_item.quantity + case when p_kind='STOCK_OUT' then -p_amount when p_kind in ('ADJUSTMENT','DAILY_COUNT_ADJUSTMENT') then p_amount else p_amount end;
 if v_after<0 then raise exception 'Insufficient stock'; end if;
 update public.inventory_items set quantity=v_after,version=version+1,updated_at=now(),updated_by=auth.uid() where id=p_item_id;
 insert into public.inventory_transactions(item_id,kind,before_qty,delta,after_qty,reason,actor) values(p_item_id,p_kind,v_item.quantity,v_after-v_item.quantity,v_after,p_reason,auth.uid());
end $$;
-- Initial count is privileged and is always logged; NULL means genuinely unknown quantity.
create or replace function public.initialize_count(p_item_id uuid,p_count numeric,p_expected_version integer,p_reason text)
returns void language plpgsql security definer set search_path='' as $$
declare v_item public.inventory_items%rowtype;
begin
 if public.current_role() not in ('manager','admin') then raise exception 'Manager required'; end if;
 if p_count is null or p_count<0 or trim(coalesce(p_reason,''))='' then raise exception 'Invalid count or reason'; end if;
 select * into v_item from public.inventory_items where id=p_item_id and archived=false for update;
 if not found or v_item.version<>p_expected_version then raise exception 'Item changed; refresh'; end if;
 update public.inventory_items set quantity=p_count, version=version+1, updated_at=now(),updated_by=auth.uid() where id=p_item_id;
 insert into public.inventory_transactions(item_id,kind,before_qty,delta,after_qty,reason,actor) values(p_item_id,'INITIAL_COUNT',v_item.quantity,null,p_count,p_reason,auth.uid());
end $$;
create or replace function public.receive_restock(p_request_id uuid,p_amount numeric)
returns void language plpgsql security definer set search_path='' as $$
declare r public.restock_requests%rowtype; i public.inventory_items%rowtype; v_after numeric;
begin
 if public.current_role() not in ('manager','admin') then raise exception 'Manager required'; end if;
 if p_amount is null or p_amount<=0 then raise exception 'Invalid receipt'; end if;
 select * into r from public.restock_requests where id=p_request_id for update;
 if not found or r.status in ('CANCELLED','RECEIVED') or r.received_qty+p_amount>r.requested_qty then raise exception 'Invalid restock receipt'; end if;
 select * into i from public.inventory_items where id=r.item_id and archived=false for update;
 if not found or i.quantity is null then raise exception 'Stock unrecorded or item archived'; end if;
 v_after:=i.quantity+p_amount;
 update public.inventory_items set quantity=v_after,version=version+1,updated_at=now(),updated_by=auth.uid() where id=i.id;
 update public.restock_requests set received_qty=received_qty+p_amount,status=case when received_qty+p_amount=requested_qty then 'RECEIVED' else 'PARTIALLY RECEIVED' end where id=r.id;
 insert into public.inventory_transactions(item_id,kind,before_qty,delta,after_qty,reason,actor) values(i.id,'RESTOCK_RECEIVED',i.quantity,p_amount,v_after,'Restock receipt '||r.id,auth.uid());
end $$;
revoke all on function public.apply_inventory_movement(uuid,text,numeric,integer,text) from public;
revoke all on function public.initialize_count(uuid,numeric,integer,text) from public;
revoke all on function public.receive_restock(uuid,numeric) from public;
grant execute on function public.apply_inventory_movement(uuid,text,numeric,integer,text) to authenticated;
grant execute on function public.initialize_count(uuid,numeric,integer,text) to authenticated;
grant execute on function public.receive_restock(uuid,numeric) to authenticated;
