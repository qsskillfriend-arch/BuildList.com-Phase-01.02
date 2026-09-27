-- ═══════════════════════════════════════════════════════════════
-- PATCH 06 — Tender Pro
-- Run after PATCH-05. Safe to run again.
--
-- A paid subscription for contractors: a 7am email of every new tender
-- in their sectors, deadline reminders three days before a matching
-- tender closes, and a personal calendar feed of matching deadlines.
-- ═══════════════════════════════════════════════════════════════

-- What a buyer chose at checkout (e.g. Tender Pro sectors)
alter table orders add column if not exists meta jsonb;

create table if not exists tender_subscriptions (
  id            bigserial primary key,
  email         text unique not null,
  name          text,
  phone         text,
  sectors       text[] not null default '{}',
  expires_at    timestamptz not null,
  -- The calendar feed is private to the subscriber: its address carries
  -- this long random token, and nothing else identifies them.
  feed_token    text unique not null,
  last_sent_at  timestamptz,
  created_at    timestamptz not null default now()
);
create index if not exists tender_subs_active_idx on tender_subscriptions (expires_at);

-- Subscribers' emails and phones: staff only. The alert and feed
-- functions use the service key.
alter table tender_subscriptions enable row level security;
drop policy if exists "staff read tender subscriptions" on tender_subscriptions;
create policy "staff read tender subscriptions" on tender_subscriptions for select using (is_staff());

-- Needed to find tenders posted since the last email
create index if not exists tenders_created_idx on tenders (created_at);

select count(*) as tender_pro_subscribers from tender_subscriptions;
