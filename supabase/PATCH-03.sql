-- ═══════════════════════════════════════════════════════════════
-- PATCH 03 — specialities, and the rating capability
-- Run after PATCH-02. Safe to run again.
-- ═══════════════════════════════════════════════════════════════

create table if not exists subcategories (
  id     serial primary key,
  parent text not null references categories(slug) on delete cascade,
  slug   text not null,
  name   text not null,
  sort   int default 0,
  unique (parent, slug)
);
alter table subcategories enable row level security;
drop policy if exists "public reads subcategories" on subcategories;
create policy "public reads subcategories" on subcategories for select using (true);
drop policy if exists "staff manage subcategories" on subcategories;
create policy "staff manage subcategories" on subcategories
  for all using (is_staff()) with check (is_staff());

create table if not exists firm_subcategories (
  firm_id        uuid not null references firms on delete cascade,
  subcategory_id int  not null references subcategories on delete cascade,
  primary key (firm_id, subcategory_id)
);
alter table firm_subcategories enable row level security;
drop policy if exists "public reads firm subcategories" on firm_subcategories;
create policy "public reads firm subcategories" on firm_subcategories
  for select using (exists (select 1 from firms f where f.id = firm_id and f.status = 'live'));
drop policy if exists "staff manage firm subcategories" on firm_subcategories;
create policy "staff manage firm subcategories" on firm_subcategories
  for all using (is_staff()) with check (is_staff());

-- ── The parent categories this patch attaches to ──────────────
-- PATCH-02 installs all 22 categories and should be run first. If it
-- has not been, the two parents used below are created here so this
-- file cannot fail halfway through on a foreign key.
alter table categories add column if not exists on_home boolean not null default false;

insert into categories (slug, name, cluster, sort) values
  ('suppliers', 'Material Suppliers', 'Supply', 9),
  ('tradesmen', 'Tradesmen', 'Trades', 22)
on conflict (slug) do update set name = excluded.name;

insert into subcategories (parent, slug, name, sort) values
  ('suppliers','cement-aggregates','Cement, Sand & Aggregates',1),
  ('suppliers','steel-rebar','Steel & Rebar',2),
  ('suppliers','timber','Timber & Boards',3),
  ('suppliers','roofing','Roofing Sheets & Accessories',4),
  ('suppliers','tiles-sanitary','Tiles & Sanitaryware',5),
  ('suppliers','paints','Paints & Finishes',6),
  ('suppliers','electrical-supplies','Electrical & Cabling',7),
  ('suppliers','plumbing-supplies','Plumbing & Pipes',8),
  ('suppliers','hardware','General Hardware',9),
  ('suppliers','glass-aluminium','Glass & Aluminium',10),
  ('tradesmen','masons','Masons & Bricklayers',1),
  ('tradesmen','carpenters','Carpenters & Joiners',2),
  ('tradesmen','steel-benders','Steel Benders & Fixers',3),
  ('tradesmen','welders','Welders & Metal Fabricators',4),
  ('tradesmen','electricians','Electricians',5),
  ('tradesmen','plumbers','Plumbers',6),
  ('tradesmen','tilers','Tilers & Terrazzo',7),
  ('tradesmen','painters','Painters & Decorators',8),
  ('tradesmen','roofers','Roofers',9),
  ('tradesmen','plasterers','Plasterers & Screeders',10),
  ('tradesmen','glaziers','Glaziers & Aluminium Fitters',11),
  ('tradesmen','scaffolders','Scaffolders',12),
  ('tradesmen','plant-operators','Plant & Machine Operators',13),
  ('tradesmen','borehole-drillers','Borehole & Water Works',14),
  ('tradesmen','solar-installers','Solar Installers',15),
  ('tradesmen','general-labour','General Labour & Casual Crews',16)
on conflict (parent, slug) do update set name = excluded.name, sort = excluded.sort;

-- Anything whose parent category is absent is dropped rather than left
-- dangling, so running this before PATCH-02 cannot corrupt the tree.
delete from subcategories
where parent not in (select slug from categories);

-- Vacancies: description and the lists shown on the vacancy page
alter table jobs add column if not exists description text;
alter table jobs add column if not exists responsibilities jsonb default '[]'::jsonb;
alter table jobs add column if not exists requirements jsonb default '[]'::jsonb;
alter table jobs add column if not exists benefits jsonb default '[]'::jsonb;

-- Articles: hero and inline images placed by [image:n] markers
alter table articles add column if not exists hero jsonb;
alter table articles add column if not exists images jsonb default '[]'::jsonb;

-- Tier capabilities, including the star rating on the top two tiers
update tiers set caps = '{"photos": 100, "logo": true, "whatsapp": true, "website": true, "descriptionChars": 5000, "services": 50, "projects": 30, "video": true, "preciseMap": true, "badge": true, "sortBoost": 4, "homepageFeature": true, "leadAlerts": true, "monthlyReport": true, "catalogue": true, "categories": 6, "reviewReply": true, "ratingDisplay": true}'::jsonb where slug = 'platinum';
update tiers set caps = '{"photos": 25, "logo": true, "whatsapp": true, "website": true, "descriptionChars": 2500, "services": 25, "projects": 12, "video": true, "preciseMap": true, "badge": true, "sortBoost": 3, "homepageFeature": false, "leadAlerts": true, "monthlyReport": true, "catalogue": true, "categories": 4, "reviewReply": true, "ratingDisplay": true}'::jsonb where slug = 'premium';
update tiers set caps = '{"photos": 10, "logo": true, "whatsapp": true, "website": true, "descriptionChars": 1200, "services": 12, "projects": 4, "video": false, "preciseMap": true, "badge": true, "sortBoost": 2, "homepageFeature": false, "leadAlerts": true, "monthlyReport": false, "catalogue": true, "categories": 3, "reviewReply": true, "ratingDisplay": false}'::jsonb where slug = 'verified';
update tiers set caps = '{"photos": 4, "logo": true, "whatsapp": true, "website": true, "descriptionChars": 600, "services": 6, "projects": 0, "video": false, "preciseMap": true, "badge": false, "sortBoost": 1, "homepageFeature": false, "leadAlerts": false, "monthlyReport": false, "catalogue": false, "categories": 2, "reviewReply": false, "ratingDisplay": false}'::jsonb where slug = 'starter';
update tiers set caps = '{"photos": 0, "logo": false, "whatsapp": false, "website": false, "descriptionChars": 160, "services": 0, "projects": 0, "video": false, "preciseMap": false, "badge": false, "sortBoost": 0, "homepageFeature": false, "leadAlerts": false, "monthlyReport": false, "catalogue": false, "categories": 1, "reviewReply": false, "ratingDisplay": false}'::jsonb where slug = 'free';


-- Ad creatives remember every width they were generated at, so the
-- public site can serve a phone a small file and a desktop a sharp one.
alter table ads add column if not exists image_set jsonb;

-- Check: two rows, 16 and 10
select parent, count(*) as specialities from subcategories group by parent order by parent;

-- Sponsored stories: the partner shown in the ribbon and the card
alter table articles add column if not exists sponsor text;
alter table articles add column if not exists sponsor_url text;
alter table articles add column if not exists sponsor_slug text;
alter table articles add column if not exists sponsor_logo text;
alter table articles add column if not exists sponsor_blurb text;


-- ── The Starter tier is retired ───────────────────────────────
-- Its firms move UP to Verified, so nobody loses anything they had.
update firms set tier = 'verified' where tier = 'starter';
delete from tiers where slug = 'starter';

-- The four tiers and what each includes
update tiers set caps = '{"photos": 60, "logo": true, "whatsapp": true, "website": true, "descriptionChars": 5000, "services": 50, "projects": 30, "video": true, "preciseMap": true, "badge": true, "sortBoost": 3, "homepageFeature": true, "leadAlerts": true, "monthlyReport": true, "catalogue": true, "categories": 6, "reviewReply": true, "ratingDisplay": true}'::jsonb, price_ugx = 1500000, rank = 0 where slug = 'platinum';
update tiers set caps = '{"photos": 20, "logo": true, "whatsapp": true, "website": true, "descriptionChars": 2000, "services": 25, "projects": 12, "video": true, "preciseMap": true, "badge": true, "sortBoost": 2, "homepageFeature": false, "leadAlerts": true, "monthlyReport": true, "catalogue": true, "categories": 4, "reviewReply": true, "ratingDisplay": true}'::jsonb, price_ugx = 400000, rank = 1 where slug = 'premium';
update tiers set caps = '{"photos": 6, "logo": true, "whatsapp": true, "website": true, "descriptionChars": 800, "services": 10, "projects": 3, "video": false, "preciseMap": true, "badge": true, "sortBoost": 1, "homepageFeature": false, "leadAlerts": true, "monthlyReport": false, "catalogue": false, "categories": 2, "reviewReply": true, "ratingDisplay": false}'::jsonb, price_ugx = 150000, rank = 2 where slug = 'verified';
update tiers set caps = '{"photos": 0, "logo": false, "whatsapp": true, "website": false, "descriptionChars": 200, "services": 3, "projects": 0, "video": false, "preciseMap": false, "badge": false, "sortBoost": 0, "homepageFeature": false, "leadAlerts": false, "monthlyReport": false, "catalogue": false, "categories": 1, "reviewReply": false, "ratingDisplay": false}'::jsonb, price_ugx = 0, rank = 3 where slug = 'free';
