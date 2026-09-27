-- ═══════════════════════════════════════════════════════════════
-- PATCH 07 — fuller vacancy pages, and reviews switched on
-- Run after PATCH-06. Safe to run again.
-- ═══════════════════════════════════════════════════════════════

-- Everything the vacancy page can show. All optional: a section with
-- nothing in it is simply left off the page.
alter table jobs add column if not exists description      text;
alter table jobs add column if not exists responsibilities jsonb default '[]'::jsonb;
alter table jobs add column if not exists requirements     jsonb default '[]'::jsonb;
alter table jobs add column if not exists qualifications   jsonb default '[]'::jsonb;
alter table jobs add column if not exists skills           jsonb default '[]'::jsonb;
alter table jobs add column if not exists benefits         jsonb default '[]'::jsonb;
alter table jobs add column if not exists documents        jsonb default '[]'::jsonb;
alter table jobs add column if not exists work_mode        text;
alter table jobs add column if not exists positions        int;
alter table jobs add column if not exists reports_to       text;
alter table jobs add column if not exists education        text;
alter table jobs add column if not exists contract_length  text;
alter table jobs add column if not exists working_hours    text;
alter table jobs add column if not exists start_date       text;
alter table jobs add column if not exists apply_url        text;
alter table jobs add column if not exists apply_ref        text;

-- Reviews: make sure the columns moderation uses exist
alter table reviews add column if not exists reject_reason text;
alter table reviews add column if not exists firm_reply    text;
alter table reviews add column if not exists replied_at    timestamptz;
alter table reviews add column if not exists moderated_by  uuid;

select count(*) filter (where column_name in ('work_mode','skills','apply_url')) as new_job_columns
from information_schema.columns where table_name = 'jobs';
