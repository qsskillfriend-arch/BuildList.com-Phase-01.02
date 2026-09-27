-- ═══════════════════════════════════════════════════════════════
-- PATCH 05 — firm owners' dashboard, leads, renewal reminders
-- BuildList.com, a product of Sharplink Ventures (U) Limited
--
-- Run after PATCH-04. Safe to run again.
-- ═══════════════════════════════════════════════════════════════


-- ── 1. The firm-protection trigger ─────────────────────────────
-- Two fixes.
--
-- (a) The trigger allowed only signed-in staff to change a firm's
--     tier, so it also reverted changes made by the server itself:
--     a successful online payment's upgrade, and every tier set by
--     migrate.js, were silently undone. Requests made with the
--     service-role key (the payment functions and migrate.js) and
--     the SQL editor are now allowed through.
--
-- (b) It did not protect everything an owner must not change. An
--     owner could set their own homepage "featured" flag — what
--     Platinum firms pay for — or rename the firm and so pass one
--     listing off as another business. Both are now staff-only.
create or replace function guard_firm_commercial_fields()
returns trigger as $$
begin
  if is_staff()
     or current_user in ('service_role', 'postgres', 'supabase_admin')
     or coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;
  new.tier             := old.tier;
  new.status           := old.status;
  new.verified         := old.verified;
  new.verified_at      := old.verified_at;
  new.verified_by      := old.verified_by;
  new.tier_expires_at  := old.tier_expires_at;
  new.is_group_company := old.is_group_company;
  new.owner_id         := old.owner_id;
  new.name             := old.name;
  new.slug             := old.slug;
  new.featured         := old.featured;
  new.featured_sort    := old.featured_sort;
  new.updated_at       := now();
  return new;
end;
$$ language plpgsql security definer;

alter table firms add column if not exists featured boolean not null default false;
alter table firms add column if not exists featured_sort int not null default 0;
alter table firms add column if not exists renewal_reminded_at timestamptz;

drop trigger if exists firms_guard on firms;
create trigger firms_guard before update on firms
  for each row execute function guard_firm_commercial_fields();


-- ── 2. Owners claim their listing themselves ───────────────────
-- A signed-in person can ask to manage a listing. Staff still decide,
-- by calling the number already on the listing, before owner_id is set.
drop policy if exists "user files own claim" on firm_claims;
create policy "user files own claim" on firm_claims
  for insert with check (auth.uid() = user_id and status = 'pending');
drop policy if exists "user reads own claims" on firm_claims;
create policy "user reads own claims" on firm_claims
  for select using (auth.uid() = user_id);


-- ── 3. Leads ───────────────────────────────────────────────────
-- Every quotation request becomes a lead for each live firm in that
-- category. Firms on a tier that includes lead alerts receive it in
-- full. Everyone else sees that it exists but not who sent it — and
-- upgrading unlocks the last 30 days of leads they missed.
create table if not exists leads (
  id           bigserial primary key,
  firm_id      uuid not null references firms on delete cascade,
  category     text,
  district     text,
  summary      text,
  contact_name text,
  contact_phone text,
  contact_email text,
  locked       boolean not null default true,
  status       text not null default 'new'
               check (status in ('new','contacted','quoted','won','lost')),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now()
);
create index if not exists leads_firm_idx on leads (firm_id, created_at desc);

alter table leads enable row level security;

-- Owners read their own UNLOCKED leads only: a locked lead's contact
-- details never leave the database.
drop policy if exists "owner reads own leads" on leads;
create policy "owner reads own leads" on leads for select using (
  not locked and exists (select 1 from firms f where f.id = firm_id and f.owner_id = auth.uid()));

-- Owners may move their own leads through the pipeline, nothing else.
drop policy if exists "owner updates own leads" on leads;
create policy "owner updates own leads" on leads for update using (
  not locked and exists (select 1 from firms f where f.id = firm_id and f.owner_id = auth.uid()))
  with check (not locked);

drop policy if exists "staff read leads" on leads;
create policy "staff read leads" on leads for select using (is_staff());

-- Locked leads, counted but not shown: what an owner is missing.
create or replace function my_locked_lead_count()
returns table (firm_id uuid, locked_30d bigint) as $$
  select l.firm_id, count(*)
  from leads l join firms f on f.id = l.firm_id
  where f.owner_id = auth.uid() and l.locked and l.created_at > now() - interval '30 days'
  group by l.firm_id;
$$ language sql security definer stable;
grant execute on function my_locked_lead_count() to authenticated;

-- Owners may only ever change a lead's status, whatever the policy says
create or replace function guard_lead_fields()
returns trigger as $$
begin
  if is_staff() or current_user in ('service_role','postgres','supabase_admin')
     or coalesce(auth.role(), '') = 'service_role' then
    return new;
  end if;
  new.firm_id := old.firm_id; new.category := old.category; new.district := old.district;
  new.summary := old.summary; new.contact_name := old.contact_name;
  new.contact_phone := old.contact_phone; new.contact_email := old.contact_email;
  new.locked := old.locked; new.created_at := old.created_at; new.updated_at := now();
  return new;
end;
$$ language plpgsql security definer;
drop trigger if exists leads_guard on leads;
create trigger leads_guard before update on leads
  for each row execute function guard_lead_fields();


-- ── 4. Owners read their own orders ────────────────────────────
alter table orders add column if not exists firm_id uuid references firms on delete set null;
drop policy if exists "owner reads own orders" on orders;
create policy "owner reads own orders" on orders for select using (
  exists (select 1 from firms f where f.slug = orders.target and f.owner_id = auth.uid()));


-- Check: should list the three new policies and the leads table
select tablename, policyname from pg_policies
where policyname in ('user files own claim','owner reads own leads','owner reads own orders');
