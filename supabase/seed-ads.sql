-- ═══════════════════════════════════════════════════════════════
-- SEED ADS — launch version: one advertising position
-- The top banner on the directory, above the search bar, is the only
-- advertising position at launch. Every other position is removed,
-- together with anything booked into it. Samples never reach visitors;
-- add ?preview to the address to see them. Safe to run again.
-- ═══════════════════════════════════════════════════════════════

alter table ads add column if not exists weight int not null default 1;
alter table ads add column if not exists link_type text default 'website';
alter table ads add column if not exists firm_slug text;
alter table ads add column if not exists image_set jsonb;
alter table ads alter column link drop not null;

delete from ads where slot <> 'directory-leaderboard';
delete from ad_slots where key <> 'directory-leaderboard';

insert into ad_slots (key, label, size) values
  ('directory-leaderboard', 'Directory top leaderboard', '970x90')
on conflict (key) do update set label = excluded.label, size = excluded.size;

insert into ads (campaign_id, slot, advertiser, image_url, alt, link, link_type,
                 active, starts_on, ends_on, weight)
values
  ('directory-leaderboard-sample-1','directory-leaderboard','Sample Advertiser 1','images/ads/leaderboard-1.png','Placeholder creative 1 for the directory banner','','none',true,current_date,current_date+90,1),
  ('directory-leaderboard-sample-2','directory-leaderboard','Sample Advertiser 2','images/ads/leaderboard-2.png','Placeholder creative 2 for the directory banner','','none',true,current_date,current_date+90,1),
  ('directory-leaderboard-sample-3','directory-leaderboard','Sample Advertiser 3','images/ads/leaderboard-3.png','Placeholder creative 3 for the directory banner','','none',true,current_date,current_date+90,1),
  ('directory-leaderboard-sample-4','directory-leaderboard','Sample Advertiser 4','images/ads/leaderboard-4.png','Placeholder creative 4 for the directory banner','','none',true,current_date,current_date+90,1),
  ('directory-leaderboard-sample-5','directory-leaderboard','Sample Advertiser 5','images/ads/leaderboard-5.png','Placeholder creative 5 for the directory banner','','none',true,current_date,current_date+90,1),
  ('directory-leaderboard-sample-6','directory-leaderboard','Sample Advertiser 6','images/ads/leaderboard-6.png','Placeholder creative 6 for the directory banner','','none',true,current_date,current_date+90,1)
on conflict (campaign_id) do update set active = excluded.active, ends_on = excluded.ends_on;

select key, label from ad_slots;
