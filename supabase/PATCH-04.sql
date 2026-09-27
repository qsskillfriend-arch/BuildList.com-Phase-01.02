-- ═══════════════════════════════════════════════════════════════
-- PATCH 04 — online payments
-- Run after PATCH-03. Safe to run again.
-- ═══════════════════════════════════════════════════════════════

create table if not exists orders (
  id              bigserial primary key,
  tx_ref          text unique not null,
  product         text not null,
  target          text,
  amount          integer not null,
  currency        text not null default 'UGX',
  status          text not null default 'pending'
                  check (status in ('pending','paid','failed','refunded')),
  customer_name   text,
  customer_email  text,
  customer_phone  text,
  flw_id          text,
  note            text,
  created_at      timestamptz not null default now(),
  paid_at         timestamptz,
  fulfilled_at    timestamptz
);
create index if not exists orders_status_idx on orders (status, created_at desc);

-- Orders hold customers' contact details: staff only, never public.
-- The payment functions use the service key, which RLS does not limit.
alter table orders enable row level security;
drop policy if exists "staff read orders" on orders;
create policy "staff read orders" on orders for select using (is_staff());

-- When a paid tier or featured vacancy runs out
alter table firms add column if not exists tier_expires_at timestamptz;
alter table jobs  add column if not exists featured_until  timestamptz;

-- Check
select count(*) as orders from orders;
