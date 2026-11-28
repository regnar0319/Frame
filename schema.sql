-- =====================================================================
-- CREWLINE: professional network for the Indian entertainment industry
-- "Every craft. Connected."   Supabase / PostgreSQL schema
-- Run in the Supabase SQL editor (or split into /supabase/migrations).
-- =====================================================================

create extension if not exists "pgcrypto";
create extension if not exists "pg_trgm";

-- ---------------------------------------------------------------------
-- ENUMS
-- ---------------------------------------------------------------------
create type availability_status as enum ('available','available_from','busy');
create type project_type        as enum ('feature','short','documentary','series','web_series','ad','music_video','other');
create type project_status      as enum ('development','recruiting','in_production','post_production','released');
create type comp_type           as enum ('paid','stipend','deferred','unpaid');
create type position_status     as enum ('open','invited','confirmed');
create type credit_status       as enum ('pending','verified','disputed');
create type pay_unit            as enum ('project','day','month','hour');
create type work_mode           as enum ('on_set','hybrid','remote');
create type engagement_type     as enum ('contract','full_time','freelance','internship');
create type job_status          as enum ('draft','open','closed','filled');
create type application_status  as enum ('submitted','reviewing','shortlisted','interviewing','offered','rejected','withdrawn');
create type connection_status   as enum ('pending','accepted','declined');
create type post_kind           as enum ('post','photo','video','behind_the_scenes','showreel');
create type like_target         as enum ('post','comment');
create type bookmark_target     as enum ('post','project','job');
create type org_role            as enum ('owner','admin','recruiter');
create type media_kind          as enum ('image','video');
create type credit_txn_type     as enum ('purchase','spend','refund','bonus','adjustment');
create type payment_status      as enum ('created','authorized','paid','failed','refunded');
create type intro_status        as enum ('pending','accepted','declined','expired');
create type verification_kind   as enum ('identity','credit','organization');
create type verification_state  as enum ('pending','approved','rejected');
create type recommendation_state as enum ('pending','visible','hidden');
create type report_status       as enum ('open','reviewing','resolved','dismissed');
create type notif_type          as enum ('connection_request','connection_accepted','message','post_like','post_comment',
                                         'credit_request','credit_verified','recommendation_received',
                                         'application_received','application_status','position_application',
                                         'position_confirmed','introduction','job_match','spotlight_started');

-- ---------------------------------------------------------------------
-- HELPERS
-- ---------------------------------------------------------------------
create or replace function set_updated_at() returns trigger language plpgsql as $$
begin new.updated_at = now(); return new; end $$;

-- ---------------------------------------------------------------------
-- DEPARTMENTS (the core taxonomy: 15 crafts shown on the Departments screen)
-- ---------------------------------------------------------------------
create table departments (
  id           smallint primary key,
  slug         text unique not null,
  name         text not null,
  sample_roles text[] not null default '{}'   -- "Actors · Voice artists · Presenters"
);
insert into departments (id, slug, name, sample_roles) values
 (1,'acting','Acting & performance','{Actors,Voice artists,Presenters}'),
 (2,'direction','Direction','{Directors,ADs,Script supervisors}'),
 (3,'cinematography','Cinematography','{DOPs,Camera operators,Focus pullers}'),
 (4,'writing','Writing','{Screenwriters,Lyricists,Story editors}'),
 (5,'editing','Editing','{Editors,Colourists,Assistant editors}'),
 (6,'lighting-grip','Lighting & grip','{Gaffers,Light technicians,Grips}'),
 (7,'choreography','Choreography','{Choreographers,Dancers,Movement}'),
 (8,'sound-music','Sound & music','{Sound designers,Recordists,Composers}'),
 (9,'vfx-animation','VFX & animation','{Compositors,3D artists,Animators}'),
 (10,'production','Production','{Producers,Line producers,Managers}'),
 (11,'makeup-hair','Makeup & hair','{Makeup artists,Hair stylists,SFX}'),
 (12,'costume-styling','Costume & styling','{Costume designers,Stylists,Dressers}'),
 (13,'art-set-design','Art & set design','{Art directors,Set designers,Props}'),
 (14,'production-crew','Production crew','{Location teams,Runners,Logistics}'),
 (15,'stunts-action','Stunts & action','{Stunt coordinators,Action performers}');

-- ---------------------------------------------------------------------
-- PROFILES
-- ---------------------------------------------------------------------
create table profiles (
  id                    uuid primary key references auth.users(id) on delete cascade,
  username              text unique not null check (username ~ '^[a-z0-9_.]{3,30}$'),
  full_name             text not null,
  headline              text,                          -- "Cinematographer / Visual storyteller"
  primary_role          text,                          -- "Cinematographer"
  bio                   text,
  avatar_url            text,
  cover_url             text,
  phone                 text,
  city                  text,
  state                 text,
  country               text default 'IN',
  languages             text[] default '{}',           -- ISO codes: hi, en, mr, ml, ta, te, bn ...
  ui_language           text default 'en',
  years_experience      int check (years_experience between 0 and 70),
  availability          availability_status default 'available',
  available_from        date,                          -- "Available from 20 Nov"
  intents               text[] default '{}' check (intents <@ array['showcase','discover','hire']),
  is_verified           boolean default false,         -- identity / credits verified check mark
  onboarding_completed  boolean default false,
  profile_completeness  int default 0,                 -- 0-100, "Your profile is 80% complete"
  project_credits_count int default 0,                 -- verified credits only
  connections_count     int default 0,
  collaborators_count   int default 0,
  followers_count       int default 0,
  following_count       int default 0,
  search                tsvector generated always as (
                          to_tsvector('simple', coalesce(full_name,'') || ' ' || coalesce(headline,'') || ' ' ||
                                                coalesce(primary_role,'') || ' ' || coalesce(bio,''))) stored,
  created_at            timestamptz default now(),
  updated_at            timestamptz default now()
);
create index profiles_search_idx on profiles using gin (search);
create index profiles_name_trgm  on profiles using gin (full_name gin_trgm_ops);
create index profiles_city_idx   on profiles (lower(city));
create trigger trg_profiles_upd before update on profiles for each row execute function set_updated_at();

create table profile_departments (
  profile_id    uuid references profiles(id) on delete cascade,
  department_id smallint references departments(id),
  is_primary    boolean default false,
  primary key (profile_id, department_id)
);
create index on profile_departments(department_id);

-- gear / specialties / genres: "ARRI Alexa", "35mm", "Documentary", "Avid", "DaVinci Resolve"
create table profile_tags (
  id         bigserial primary key,
  profile_id uuid not null references profiles(id) on delete cascade,
  tag        text not null,
  kind       text not null default 'specialty' check (kind in ('gear','software','specialty','genre')),
  position   int default 0,
  unique (profile_id, tag)
);

create table experiences (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  title text not null, company text, start_date date, end_date date, description text
);
create index on experiences(profile_id);

-- ---------------------------------------------------------------------
-- MEDIA + PORTFOLIO
-- ---------------------------------------------------------------------
create table media_assets (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  kind media_kind not null,
  storage_path text not null,
  thumbnail_url text,
  duration_seconds int,
  width int, height int,
  created_at timestamptz default now()
);
create index on media_assets(owner_id);

create table portfolio_items (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  media_id uuid references media_assets(id) on delete set null,
  external_url text,                  -- YouTube / Vimeo link alternative
  title text not null,                -- "The Last Local"
  label text,                         -- "SHOWREEL 2024"
  description text,
  is_featured boolean default false,  -- hero item on profile
  position int default 0,
  created_at timestamptz default now()
);
create index on portfolio_items(profile_id, position);

-- ---------------------------------------------------------------------
-- ORGANIZATIONS (production houses; power the Recruiter studio)
-- ---------------------------------------------------------------------
create table organizations (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  slug text unique not null,
  logo_url text, about text, website text, city text, state text,
  is_verified boolean default false,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz default now()
);
create table organization_members (
  organization_id uuid references organizations(id) on delete cascade,
  profile_id uuid references profiles(id) on delete cascade,
  role org_role not null default 'recruiter',
  created_at timestamptz default now(),
  primary key (organization_id, profile_id)
);

create or replace function is_org_member(p_org uuid, p_roles org_role[] default null)
returns boolean language sql stable security definer set search_path = public as $$
  select exists (select 1 from organization_members m
                 where m.organization_id = p_org and m.profile_id = auth.uid()
                   and (p_roles is null or m.role = any(p_roles)));
$$;

-- ---------------------------------------------------------------------
-- COLLECTIVES ("YOUR NETWORK": Mumbai Film Collective, Independent cinema, India)
-- ---------------------------------------------------------------------
create table collectives (
  id uuid primary key default gen_random_uuid(),
  slug text unique not null,
  name text not null,
  focus text,                 -- "Independent cinema"
  region text,                -- "India"
  about text, cover_url text,
  members_count int default 0,
  created_by uuid references profiles(id) on delete set null,
  created_at timestamptz default now()
);
create table collective_members (
  collective_id uuid references collectives(id) on delete cascade,
  profile_id uuid references profiles(id) on delete cascade,
  is_admin boolean default false,
  joined_at timestamptz default now(),
  primary key (collective_id, profile_id)
);
create or replace function bump_collective_members() returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then update collectives set members_count = members_count + 1 where id = new.collective_id;
  else update collectives set members_count = greatest(members_count - 1,0) where id = old.collective_id; end if;
  return null;
end $$;
create trigger trg_collective_members after insert or delete on collective_members
  for each row execute function bump_collective_members();

-- ---------------------------------------------------------------------
-- PROJECTS, POSITIONS, CREDITS
-- ---------------------------------------------------------------------
create table projects (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  organization_id uuid references organizations(id) on delete set null,
  title text not null,
  type project_type default 'short',
  summary text,
  cover_url text,
  city text, state text,
  language text,
  status project_status default 'development',
  compensation comp_type default 'paid',      -- "Paid collaboration"
  start_date date, end_date date,
  release_year int,
  commitments text[] default '{}'
    check (commitments <@ array['fair_pay','safe_sets','inclusive_crews','credit_for_all']),
  is_published boolean default true,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index on projects(status, created_at desc);
create index projects_search_idx on projects using gin (to_tsvector('simple', title || ' ' || coalesce(summary,'')));
create trigger trg_projects_upd before update on projects for each row execute function set_updated_at();

-- one row per crew slot: "Direction: Arjun Sen, Confirmed" / "Editing: 1 open position"
create table project_positions (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  department_id smallint not null references departments(id),
  title text not null,                       -- "Editor"
  description text,
  status position_status default 'open',
  profile_id uuid references profiles(id) on delete set null,   -- confirmed / invited person
  pay_note text,
  created_at timestamptz default now()
);
create index on project_positions(project_id);
create index on project_positions(department_id) where status = 'open';

create table position_applications (
  id uuid primary key default gen_random_uuid(),
  position_id uuid not null references project_positions(id) on delete cascade,
  applicant_id uuid not null references profiles(id) on delete cascade,
  message text,
  status application_status default 'submitted',
  created_at timestamptz default now(),
  unique (position_id, applicant_id)
);

-- Verified credits are what make the 'Verified credits only' filter and the check marks meaningful.
create table project_credits (
  id uuid primary key default gen_random_uuid(),
  project_id uuid not null references projects(id) on delete cascade,
  profile_id uuid not null references profiles(id) on delete cascade,
  department_id smallint references departments(id),
  role_title text not null,                  -- "Director of Photography"
  year int,
  note text,
  status credit_status default 'pending',
  created_by uuid references profiles(id) on delete set null,   -- who added it (claimant or project owner)
  verified_by uuid references profiles(id) on delete set null,
  verified_at timestamptz,
  is_selected boolean default false,         -- "SELECTED CREDIT" on profile
  created_at timestamptz default now(),
  unique (project_id, profile_id, role_title)
);
create index on project_credits(profile_id, status);
create index on project_credits(project_id);

-- ---------------------------------------------------------------------
-- NETWORK: connections, follows, recommendations, blocks
-- ---------------------------------------------------------------------
create table connections (
  id uuid primary key default gen_random_uuid(),
  requester_id uuid not null references profiles(id) on delete cascade,
  addressee_id uuid not null references profiles(id) on delete cascade,
  status connection_status default 'pending',
  note text,
  created_at timestamptz default now(),
  responded_at timestamptz,
  check (requester_id <> addressee_id),
  unique (requester_id, addressee_id)
);
create index on connections(addressee_id, status);

create table follows (
  follower_id uuid references profiles(id) on delete cascade,
  following_id uuid references profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (follower_id, following_id),
  check (follower_id <> following_id)
);
create index on follows(following_id);

create or replace function bump_follow_counts() returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then
    update profiles set followers_count = followers_count + 1 where id = new.following_id;
    update profiles set following_count = following_count + 1 where id = new.follower_id;
  else
    update profiles set followers_count = greatest(followers_count - 1,0) where id = old.following_id;
    update profiles set following_count = greatest(following_count - 1,0) where id = old.follower_id;
  end if;
  return null;
end $$;
create trigger trg_follow_counts after insert or delete on follows for each row execute function bump_follow_counts();

-- Written recommendations (profile tab). Recipient approves before it's shown.
create table recommendations (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles(id) on delete cascade,
  recipient_id uuid not null references profiles(id) on delete cascade,
  project_id uuid references projects(id) on delete set null,
  relationship text,                          -- "Worked together on The Last Local"
  body text not null check (char_length(body) between 20 and 1500),
  status recommendation_state default 'pending',
  created_at timestamptz default now(),
  check (author_id <> recipient_id),
  unique (author_id, recipient_id)
);

create table blocks (
  blocker_id uuid references profiles(id) on delete cascade,
  blocked_id uuid references profiles(id) on delete cascade,
  primary key (blocker_id, blocked_id)
);

-- ---------------------------------------------------------------------
-- FEED: posts, comments, likes, shares, bookmarks
-- ---------------------------------------------------------------------
create table posts (
  id uuid primary key default gen_random_uuid(),
  author_id uuid not null references profiles(id) on delete cascade,
  kind post_kind default 'post',
  body text check (char_length(body) <= 3000),
  label text,                                -- "BEHIND THE SCENES" chip on media
  project_id uuid references projects(id) on delete set null,
  department_id smallint references departments(id),   -- powers 'From your departments'
  collective_id uuid references collectives(id) on delete set null,
  visibility text default 'public' check (visibility in ('public','connections')),
  likes_count int default 0,
  comments_count int default 0,
  shares_count int default 0,
  created_at timestamptz default now(),
  updated_at timestamptz default now()
);
create index on posts(author_id, created_at desc);
create index on posts(created_at desc);
create index on posts(department_id, created_at desc);
create trigger trg_posts_upd before update on posts for each row execute function set_updated_at();

create table post_media (
  post_id uuid references posts(id) on delete cascade,
  media_id uuid references media_assets(id) on delete cascade,
  position int default 0,
  primary key (post_id, media_id)
);

create table comments (
  id uuid primary key default gen_random_uuid(),
  post_id uuid not null references posts(id) on delete cascade,
  author_id uuid not null references profiles(id) on delete cascade,
  parent_id uuid references comments(id) on delete cascade,
  body text not null check (char_length(body) <= 2000),
  likes_count int default 0,
  created_at timestamptz default now()
);
create index on comments(post_id, created_at);

create table likes (
  user_id uuid references profiles(id) on delete cascade,
  target_type like_target not null,
  target_id uuid not null,
  created_at timestamptz default now(),
  primary key (user_id, target_type, target_id)
);
create index on likes(target_type, target_id);

create table post_shares (
  post_id uuid references posts(id) on delete cascade,
  user_id uuid references profiles(id) on delete cascade,
  created_at timestamptz default now(),
  primary key (post_id, user_id)
);

create table bookmarks (
  user_id uuid references profiles(id) on delete cascade,
  target_type bookmark_target not null,
  target_id uuid not null,
  created_at timestamptz default now(),
  primary key (user_id, target_type, target_id)
);

create or replace function bump_like_counts() returns trigger language plpgsql as $$
declare d int; t like_target; i uuid;
begin
  if tg_op = 'INSERT' then d := 1; t := new.target_type; i := new.target_id;
  else d := -1; t := old.target_type; i := old.target_id; end if;
  if t = 'post' then update posts set likes_count = greatest(likes_count + d,0) where id = i;
  else update comments set likes_count = greatest(likes_count + d,0) where id = i; end if;
  return null;
end $$;
create trigger trg_like_counts after insert or delete on likes for each row execute function bump_like_counts();

create or replace function bump_comment_counts() returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then update posts set comments_count = comments_count + 1 where id = new.post_id;
  else update posts set comments_count = greatest(comments_count - 1,0) where id = old.post_id; end if;
  return null;
end $$;
create trigger trg_comment_counts after insert or delete on comments for each row execute function bump_comment_counts();

create or replace function bump_share_counts() returns trigger language plpgsql as $$
begin
  if tg_op = 'INSERT' then update posts set shares_count = shares_count + 1 where id = new.post_id;
  else update posts set shares_count = greatest(shares_count - 1,0) where id = old.post_id; end if;
  return null;
end $$;
create trigger trg_share_counts after insert or delete on post_shares for each row execute function bump_share_counts();

-- "Saved by cinematographers, editors & lighting crews" (top 3 departments of people who saved a post)
create or replace function saved_by_departments(p_post uuid)
returns text[] language sql stable security definer set search_path = public as $$
  select coalesce(array_agg(name order by n desc), '{}') from (
    select d.name, count(distinct b.user_id) n
    from bookmarks b
    join profile_departments pd on pd.profile_id = b.user_id
    join departments d on d.id = pd.department_id
    where b.target_type = 'post' and b.target_id = p_post
    group by d.name order by n desc limit 3) s;
$$;

-- ---------------------------------------------------------------------
-- OPPORTUNITIES (jobs) + APPLICATIONS
-- ---------------------------------------------------------------------
create table jobs (
  id uuid primary key default gen_random_uuid(),
  organization_id uuid not null references organizations(id) on delete cascade,
  project_id uuid references projects(id) on delete set null,
  posted_by uuid not null references profiles(id) on delete cascade,
  title text not null,                        -- "Film editor"
  department_id smallint references departments(id),
  category_label text,                        -- "Independent film"
  tagline text,                               -- "Shape a story worth telling."
  description text not null,
  requirements text[] default '{}',           -- "What you bring"
  compensation comp_type default 'paid',
  pay_min numeric(12,2), pay_max numeric(12,2),
  pay_unit pay_unit default 'project',
  currency text default 'INR',
  engagement engagement_type default 'contract',
  work_mode work_mode default 'on_set',
  city text, state text,
  duration_text text,                         -- "4-6 weeks"
  start_date date,
  min_experience_years int,
  languages text[] default '{}',
  status job_status default 'draft',
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  expires_at timestamptz,
  check (pay_max is null or pay_min is null or pay_max >= pay_min)
);
create index on jobs(status, created_at desc);
create index on jobs(department_id) where status = 'open';
create index jobs_search_idx on jobs using gin (to_tsvector('simple', title || ' ' || description));
create trigger trg_jobs_upd before update on jobs for each row execute function set_updated_at();

create table job_applications (
  id uuid primary key default gen_random_uuid(),
  job_id uuid not null references jobs(id) on delete cascade,
  applicant_id uuid not null references profiles(id) on delete cascade,
  cover_note text,
  status application_status default 'submitted',
  interview_at timestamptz,
  recruiter_note text,                         -- private to org
  created_at timestamptz default now(),
  updated_at timestamptz default now(),
  unique (job_id, applicant_id)
);
create index on job_applications(job_id, status);
create index on job_applications(applicant_id);
create trigger trg_apps_upd before update on job_applications for each row execute function set_updated_at();

-- ---------------------------------------------------------------------
-- SAVED SEARCHES
-- ---------------------------------------------------------------------
create table saved_searches (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references profiles(id) on delete cascade,
  name text,
  query text,
  filters jsonb default '{}',                  -- {department, city, experience, languages, availability, verifiedOnly}
  alerts_enabled boolean default false,
  created_at timestamptz default now()
);

-- ---------------------------------------------------------------------
-- CREDIT WALLET (optional visibility tools; networking and applying are always free)
-- ---------------------------------------------------------------------
create table credit_packs (
  id smallint primary key,
  credits int not null,
  price_paise int not null,                    -- GST-inclusive: 49900 = Rs 499
  tagline text,
  is_active boolean default true
);
insert into credit_packs values
  (1, 100,  49900, 'For your next connection', true),
  (2, 250,  99900, 'A little more possibility', true),
  (3, 600, 199900, 'Built for bigger plans', true);

create table credit_products (                 -- what credits can be spent on
  code text primary key,
  cost int not null,
  description text not null,
  is_active boolean default true
);
insert into credit_products values
  ('priority_introduction', 10, 'Priority introduction to a new collaborator', true),
  ('portfolio_spotlight',   20, '7-day portfolio spotlight in your department', true);

create table wallets (
  profile_id uuid primary key references profiles(id) on delete cascade,
  balance int not null default 0 check (balance >= 0),
  updated_at timestamptz default now()
);

create table payments (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete restrict,
  pack_id smallint not null references credit_packs(id),
  provider text default 'razorpay',
  provider_order_id text unique,
  provider_payment_id text unique,
  method text,                                 -- upi | card | netbanking
  amount_paise int not null,
  gst_paise int not null default 0,
  status payment_status default 'created',
  invoice_no text unique,
  credited_at timestamptz,                     -- set once credits are granted (idempotency)
  created_at timestamptz default now()
);
create index on payments(profile_id, created_at desc);

create table credit_transactions (             -- append-only ledger ("Recent activity")
  id bigserial primary key,
  profile_id uuid not null references profiles(id) on delete cascade,
  amount int not null,                         -- +250 purchase, -20 spend
  type credit_txn_type not null,
  reason text,                                 -- product code or 'pack_purchase'
  reference_id uuid,
  balance_after int not null,
  created_at timestamptz default now()
);
create index on credit_transactions(profile_id, created_at desc);

create table spotlights (
  id uuid primary key default gen_random_uuid(),
  profile_id uuid not null references profiles(id) on delete cascade,
  department_id smallint not null references departments(id),
  starts_at timestamptz default now(),
  ends_at timestamptz not null,
  credits_spent int not null
);
create index on spotlights(department_id, ends_at);

create table introductions (                   -- priority introductions
  id uuid primary key default gen_random_uuid(),
  sender_id uuid not null references profiles(id) on delete cascade,
  recipient_id uuid not null references profiles(id) on delete cascade,
  message text,
  status intro_status default 'pending',
  credits_spent int not null,
  created_at timestamptz default now(),
  responded_at timestamptz
);
create index on introductions(recipient_id, status);

-- ---------------------------------------------------------------------
-- MESSAGING, NOTIFICATIONS, VERIFICATION, REPORTS
-- ---------------------------------------------------------------------
create table conversations (
  id uuid primary key default gen_random_uuid(),
  kind text default 'direct' check (kind in ('direct','group','application')),
  job_application_id uuid references job_applications(id) on delete set null,
  last_message_at timestamptz default now(),
  created_at timestamptz default now()
);
create table conversation_members (
  conversation_id uuid references conversations(id) on delete cascade,
  profile_id uuid references profiles(id) on delete cascade,
  last_read_at timestamptz default now(),
  primary key (conversation_id, profile_id)
);
create table messages (
  id uuid primary key default gen_random_uuid(),
  conversation_id uuid not null references conversations(id) on delete cascade,
  sender_id uuid not null references profiles(id) on delete cascade,
  body text, attachment_url text,
  created_at timestamptz default now()
);
create index on messages(conversation_id, created_at desc);

create table notifications (
  id uuid primary key default gen_random_uuid(),
  recipient_id uuid not null references profiles(id) on delete cascade,
  actor_id uuid references profiles(id) on delete set null,
  type notif_type not null,
  entity_type text, entity_id uuid,
  is_read boolean default false,
  created_at timestamptz default now()
);
create index on notifications(recipient_id, is_read, created_at desc);

create table verification_requests (
  id uuid primary key default gen_random_uuid(),
  kind verification_kind not null,
  profile_id uuid references profiles(id) on delete cascade,
  organization_id uuid references organizations(id) on delete cascade,
  evidence_urls text[] default '{}',
  status verification_state default 'pending',
  reviewed_by uuid references profiles(id),
  created_at timestamptz default now(),
  reviewed_at timestamptz
);

create table reports (
  id uuid primary key default gen_random_uuid(),
  reporter_id uuid not null references profiles(id) on delete cascade,
  target_type text not null check (target_type in ('profile','post','comment','project','job','message')),
  target_id uuid not null,
  reason text not null,
  status report_status default 'open',
  created_at timestamptz default now()
);

-- ---------------------------------------------------------------------
-- PROFILE STATS (credits, collaborators, connections, completeness)
-- ---------------------------------------------------------------------
create or replace function refresh_profile_stats(p uuid) returns void
language plpgsql security definer set search_path = public as $$
begin
  update profiles pr set
    project_credits_count = (select count(*) from project_credits c where c.profile_id = p and c.status = 'verified'),
    collaborators_count = (
      select count(distinct c2.profile_id)
      from project_credits c1
      join project_credits c2 on c2.project_id = c1.project_id and c2.profile_id <> p and c2.status = 'verified'
      where c1.profile_id = p and c1.status = 'verified'),
    connections_count = (select count(*) from connections k
                         where k.status = 'accepted' and p in (k.requester_id, k.addressee_id)),
    profile_completeness =
        (case when pr.avatar_url is not null then 10 else 0 end)
      + (case when pr.headline is not null then 10 else 0 end)
      + (case when length(coalesce(pr.bio,'')) > 20 then 15 else 0 end)
      + (case when exists (select 1 from profile_departments d where d.profile_id = p) then 10 else 0 end)
      + (case when exists (select 1 from profile_tags t where t.profile_id = p) then 10 else 0 end)
      + (case when exists (select 1 from portfolio_items i where i.profile_id = p) then 20 else 0 end)
      + (case when exists (select 1 from project_credits c where c.profile_id = p and c.status = 'verified') then 15 else 0 end)
      + (case when coalesce(cardinality(pr.languages),0) > 0 then 5 else 0 end)
      + (case when pr.years_experience is not null then 5 else 0 end)
  where pr.id = p;
end $$;

create or replace function trg_refresh_stats() returns trigger language plpgsql as $$
declare r jsonb := case when tg_op = 'DELETE' then to_jsonb(old) else to_jsonb(new) end;
begin
  if tg_table_name = 'connections' then
    perform refresh_profile_stats((r->>'requester_id')::uuid);
    perform refresh_profile_stats((r->>'addressee_id')::uuid);
  else
    perform refresh_profile_stats((r->>'profile_id')::uuid);
  end if;
  return null;
end $$;
create trigger trg_stats_credits  after insert or update or delete on project_credits    for each row execute function trg_refresh_stats();
create trigger trg_stats_portfolio after insert or delete          on portfolio_items    for each row execute function trg_refresh_stats();
create trigger trg_stats_depts    after insert or delete           on profile_departments for each row execute function trg_refresh_stats();
create trigger trg_stats_tags     after insert or delete           on profile_tags       for each row execute function trg_refresh_stats();
create trigger trg_stats_conn     after insert or update or delete on connections        for each row execute function trg_refresh_stats();
-- Profile field edits (avatar, bio, ...): API calls `select refresh_profile_stats(auth.uid())` after saving.

-- ---------------------------------------------------------------------
-- SIGNUP: create profile + wallet (supports email, phone OTP and Google)
-- ---------------------------------------------------------------------
create or replace function handle_new_user() returns trigger language plpgsql security definer set search_path = public as $$
begin
  insert into profiles (id, username, full_name, avatar_url, phone)
  values (new.id,
          'user_' || substr(replace(new.id::text,'-',''),1,10),
          coalesce(new.raw_user_meta_data->>'full_name', split_part(new.email,'@',1), 'New member'),
          new.raw_user_meta_data->>'avatar_url',
          new.phone);
  insert into wallets (profile_id) values (new.id);
  return new;
end $$;
create trigger on_auth_user_created after insert on auth.users for each row execute function handle_new_user();

-- ---------------------------------------------------------------------
-- EXPLORE PROFESSIONALS (filters from the Explore screen)
-- 'Available for work' in the UI = availability in ('available','available_from'); handle in the API.
-- ---------------------------------------------------------------------
create or replace function search_professionals(
  p_q text default null,
  p_department smallint default null,
  p_city text default null,
  p_min_experience int default null,
  p_languages text[] default null,
  p_availability availability_status default null,
  p_verified_credits_only boolean default false,
  p_sort text default 'recommended',        -- recommended | experience | recent
  p_limit int default 24,
  p_offset int default 0)
returns table (id uuid, username text, full_name text, headline text, avatar_url text, city text,
               years_experience int, is_verified boolean, availability availability_status,
               available_from date, specialties text[], total_count bigint)
language sql stable security invoker as $$
  select p.id, p.username, p.full_name, p.headline, p.avatar_url, p.city, p.years_experience,
         p.is_verified, p.availability, p.available_from,
         coalesce((select array_agg(t.tag order by t.position) from
                   (select tag, position from profile_tags where profile_id = p.id order by position limit 3) t), '{}'),
         count(*) over()
  from profiles p
  where p.onboarding_completed
    and (p_q is null or p.search @@ plainto_tsquery('simple', p_q) or p.full_name ilike '%' || p_q || '%'
         or exists (select 1 from project_credits c join projects pr on pr.id = c.project_id
                    where c.profile_id = p.id and pr.title ilike '%' || p_q || '%'))
    and (p_department is null or exists (select 1 from profile_departments d where d.profile_id = p.id and d.department_id = p_department))
    and (p_city is null or lower(p.city) = lower(p_city))
    and (p_min_experience is null or p.years_experience >= p_min_experience)
    and (p_languages is null or p.languages && p_languages)
    and (p_availability is null or p.availability = p_availability)
    and (not p_verified_credits_only or p.project_credits_count > 0)
  order by
    case when p_sort = 'experience' then p.years_experience end desc nulls last,
    case when p_sort = 'recent' then extract(epoch from p.created_at) end desc nulls last,
    p.project_credits_count desc, p.created_at desc
  limit p_limit offset p_offset;
$$;

-- ---------------------------------------------------------------------
-- HOME FEED (tabs: foryou | following | departments)
-- MVP ordering = newest first. Add ranking later without changing the API shape.
-- ---------------------------------------------------------------------
create or replace function get_feed(p_tab text default 'foryou', p_limit int default 20, p_before timestamptz default now())
returns setof posts language sql stable security invoker as $$
  select p.* from posts p
  where p.created_at < p_before
    and p.visibility = 'public'
    and p.author_id not in (select blocked_id from blocks where blocker_id = auth.uid())
    and case p_tab
      when 'following' then
           p.author_id = auth.uid()
        or p.author_id in (select following_id from follows where follower_id = auth.uid())
        or p.author_id in (select case when requester_id = auth.uid() then addressee_id else requester_id end
                           from connections where status = 'accepted' and auth.uid() in (requester_id, addressee_id))
      when 'departments' then
           p.department_id in (select department_id from profile_departments where profile_id = auth.uid())
        or p.author_id in (select pd.profile_id from profile_departments pd
                           where pd.department_id in (select department_id from profile_departments where profile_id = auth.uid()))
      else true end
  order by p.created_at desc
  limit p_limit;
$$;

-- ---------------------------------------------------------------------
-- RECRUITER STUDIO
-- ---------------------------------------------------------------------
create or replace function recruiter_stats(p_org uuid)
returns table (active_opportunities int, departments_count int, applications_received int, new_this_week int,
               shortlisted int, interviews_this_week int, interviews_today int)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_org_member(p_org) then raise exception 'not allowed'; end if;
  return query
  select
    (select count(*)::int from jobs j where j.organization_id = p_org and j.status = 'open'),
    (select count(distinct j.department_id)::int from jobs j where j.organization_id = p_org and j.status = 'open'),
    (select count(*)::int from job_applications a join jobs j on j.id = a.job_id where j.organization_id = p_org),
    (select count(*)::int from job_applications a join jobs j on j.id = a.job_id
       where j.organization_id = p_org and a.created_at > now() - interval '7 days'),
    (select count(*)::int from job_applications a join jobs j on j.id = a.job_id
       where j.organization_id = p_org and a.status = 'shortlisted'),
    (select count(*)::int from job_applications a join jobs j on j.id = a.job_id
       where j.organization_id = p_org and a.interview_at >= date_trunc('week', now()) and a.interview_at < date_trunc('week', now()) + interval '7 days'),
    (select count(*)::int from job_applications a join jobs j on j.id = a.job_id
       where j.organization_id = p_org and a.interview_at::date = current_date);
end $$;

create or replace function hiring_pipeline(p_org uuid)
returns table (job_id uuid, job_title text, project_title text, applicants int, shortlisted int, status text)
language plpgsql stable security definer set search_path = public as $$
begin
  if not is_org_member(p_org) then raise exception 'not allowed'; end if;
  return query
  select j.id, j.title, pr.title,
         count(a.id)::int,
         (count(a.id) filter (where a.status = 'shortlisted'))::int,
         case when count(a.id) filter (where a.status = 'interviewing') > 0 then 'Interviewing' else 'Reviewing' end
  from jobs j
  left join projects pr on pr.id = j.project_id
  left join job_applications a on a.job_id = j.id
  where j.organization_id = p_org and j.status = 'open'
  group by j.id, j.title, pr.title, j.created_at
  order by j.created_at desc;
end $$;

-- "Talent matched to your projects": skills, availability and verified credits only.
-- RULE: wallet credits / spotlights NEVER feed into this score ("Credits never influence hiring rankings").
create or replace function match_talent_for_job(p_job uuid, p_limit int default 12)
returns table (profile_id uuid, full_name text, primary_role text, city text, years_experience int,
               availability availability_status, available_from date, score int)
language plpgsql stable security definer set search_path = public as $$
declare j jobs%rowtype;
begin
  select * into j from jobs where id = p_job;
  if j.id is null or not is_org_member(j.organization_id) then raise exception 'not allowed'; end if;
  return query
  select p.id, p.full_name, p.primary_role, p.city, p.years_experience, p.availability, p.available_from,
    ( (case when exists (select 1 from profile_departments d where d.profile_id = p.id and d.department_id = j.department_id) then 40 else 0 end)
    + (case when p.project_credits_count > 0 then 15 + least(p.project_credits_count, 10) else 0 end)
    + (case when p.availability = 'available' then 15 when p.availability = 'available_from' then 8 else 0 end)
    + (case when j.city is not null and lower(p.city) = lower(j.city) then 10 else 0 end)
    + (case when j.languages && p.languages then 5 else 0 end)
    + (case when j.min_experience_years is null or p.years_experience >= j.min_experience_years then 5 else 0 end)
    )::int as score
  from profiles p
  where p.onboarding_completed
    and p.availability <> 'busy'
    and not exists (select 1 from job_applications a where a.job_id = j.id and a.applicant_id = p.id)
  order by score desc, p.project_credits_count desc
  limit p_limit;
end $$;

-- ---------------------------------------------------------------------
-- WALLET FUNCTIONS (all balance changes go through these; no direct table writes)
-- ---------------------------------------------------------------------
create or replace function spend_credits(p_product text, p_target uuid default null, p_message text default null)
returns int language plpgsql security definer set search_path = public as $$
declare v_uid uuid := auth.uid(); v_cost int; v_bal int; v_new int; v_dept smallint;
begin
  if v_uid is null then raise exception 'not authenticated'; end if;
  select cost into v_cost from credit_products where code = p_product and is_active;
  if v_cost is null then raise exception 'unknown product'; end if;
  select balance into v_bal from wallets where profile_id = v_uid for update;
  if v_bal is null or v_bal < v_cost then raise exception 'insufficient credits'; end if;

  if p_product = 'priority_introduction' then
    if p_target is null or p_target = v_uid then raise exception 'recipient required'; end if;
    insert into introductions (sender_id, recipient_id, message, credits_spent) values (v_uid, p_target, p_message, v_cost);
  elsif p_product = 'portfolio_spotlight' then
    select department_id into v_dept from profile_departments where profile_id = v_uid order by is_primary desc limit 1;
    if v_dept is null then raise exception 'choose a department first'; end if;
    insert into spotlights (profile_id, department_id, ends_at, credits_spent) values (v_uid, v_dept, now() + interval '7 days', v_cost);
  end if;

  v_new := v_bal - v_cost;
  update wallets set balance = v_new, updated_at = now() where profile_id = v_uid;
  insert into credit_transactions (profile_id, amount, type, reason, reference_id, balance_after)
  values (v_uid, -v_cost, 'spend', p_product, p_target, v_new);
  return v_new;
end $$;

-- Called ONLY by the payment webhook (service role). Idempotent via payments.credited_at.
create or replace function grant_credits_for_payment(p_payment uuid)
returns int language plpgsql security definer set search_path = public as $$
declare pay payments%rowtype; v_credits int; v_new int;
begin
  select * into pay from payments where id = p_payment for update;
  if pay.id is null or pay.status <> 'paid' then raise exception 'payment not settled'; end if;
  if pay.credited_at is not null then
    select balance into v_new from wallets where profile_id = pay.profile_id; return v_new;
  end if;
  select credits into v_credits from credit_packs where id = pay.pack_id;
  update wallets set balance = balance + v_credits, updated_at = now()
   where profile_id = pay.profile_id returning balance into v_new;
  insert into credit_transactions (profile_id, amount, type, reason, reference_id, balance_after)
  values (pay.profile_id, v_credits, 'purchase', 'pack_purchase', pay.id, v_new);
  update payments set credited_at = now() where id = pay.id;
  return v_new;
end $$;
revoke execute on function grant_credits_for_payment(uuid) from public, anon, authenticated;
grant  execute on function grant_credits_for_payment(uuid) to service_role;

create or replace function unread_conversations_count() returns int language sql stable as $$
  select count(*)::int from conversation_members cm
  join conversations c on c.id = cm.conversation_id
  where cm.profile_id = auth.uid() and c.last_message_at > cm.last_read_at;
$$;

-- =====================================================================
-- ROW LEVEL SECURITY
-- =====================================================================
do $$
declare t text;
begin
  foreach t in array array[
    'profiles','profile_departments','profile_tags','experiences','media_assets','portfolio_items',
    'organizations','organization_members','collectives','collective_members',
    'projects','project_positions','position_applications','project_credits',
    'connections','follows','recommendations','blocks',
    'posts','post_media','comments','likes','post_shares','bookmarks',
    'jobs','job_applications','saved_searches',
    'wallets','payments','credit_transactions','spotlights','introductions',
    'conversations','conversation_members','messages','notifications','verification_requests','reports']
  loop execute format('alter table %I enable row level security', t); end loop;
end $$;

-- reference data is public-read
alter table departments    enable row level security;
alter table credit_packs   enable row level security;
alter table credit_products enable row level security;
create policy "departments read" on departments for select using (true);
create policy "packs read"       on credit_packs for select using (is_active);
create policy "products read"    on credit_products for select using (is_active);

-- profiles and profile content
create policy "profiles read"   on profiles for select using (true);
create policy "profiles update" on profiles for update using (auth.uid() = id);
create policy "pdept read"  on profile_departments for select using (true);
create policy "pdept write" on profile_departments for all using (auth.uid() = profile_id) with check (auth.uid() = profile_id);
create policy "ptags read"  on profile_tags for select using (true);
create policy "ptags write" on profile_tags for all using (auth.uid() = profile_id) with check (auth.uid() = profile_id);
create policy "exp read"    on experiences for select using (true);
create policy "exp write"   on experiences for all using (auth.uid() = profile_id) with check (auth.uid() = profile_id);
create policy "media read"  on media_assets for select using (true);
create policy "media write" on media_assets for all using (auth.uid() = owner_id) with check (auth.uid() = owner_id);
create policy "portfolio read"  on portfolio_items for select using (true);
create policy "portfolio write" on portfolio_items for all using (auth.uid() = profile_id) with check (auth.uid() = profile_id);

-- organizations
create policy "orgs read"   on organizations for select using (true);
create policy "orgs insert" on organizations for insert with check (auth.uid() = created_by);
create policy "orgs update" on organizations for update using (is_org_member(id, array['owner','admin']::org_role[]));
create policy "omembers read"  on organization_members for select using (profile_id = auth.uid() or is_org_member(organization_id));
create policy "omembers write" on organization_members for all
  using (is_org_member(organization_id, array['owner','admin']::org_role[]))
  with check (is_org_member(organization_id, array['owner','admin']::org_role[]) or profile_id = auth.uid());

-- collectives
create policy "collectives read" on collectives for select using (true);
create policy "collectives insert" on collectives for insert with check (auth.uid() = created_by);
create policy "cmembers read"  on collective_members for select using (true);
create policy "cmembers write" on collective_members for all using (auth.uid() = profile_id) with check (auth.uid() = profile_id);

-- projects, positions, credits
create policy "projects read"   on projects for select using (is_published or owner_id = auth.uid());
create policy "projects write"  on projects for all
  using (owner_id = auth.uid() or (organization_id is not null and is_org_member(organization_id)))
  with check (owner_id = auth.uid());
create policy "positions read"  on project_positions for select using (true);
create policy "positions write" on project_positions for all
  using (exists (select 1 from projects p where p.id = project_id and (p.owner_id = auth.uid() or (p.organization_id is not null and is_org_member(p.organization_id)))));
create policy "papps read" on position_applications for select
  using (applicant_id = auth.uid() or exists (select 1 from project_positions pp join projects p on p.id = pp.project_id
                                              where pp.id = position_id and p.owner_id = auth.uid()));
create policy "papps insert" on position_applications for insert with check (applicant_id = auth.uid());
create policy "papps update" on position_applications for update
  using (applicant_id = auth.uid() or exists (select 1 from project_positions pp join projects p on p.id = pp.project_id
                                              where pp.id = position_id and p.owner_id = auth.uid()));
create policy "credits read" on project_credits for select
  using (status = 'verified' or profile_id = auth.uid() or created_by = auth.uid()
         or exists (select 1 from projects p where p.id = project_id and p.owner_id = auth.uid()));
create policy "credits insert" on project_credits for insert
  with check (created_by = auth.uid() and (profile_id = auth.uid()
              or exists (select 1 from projects p where p.id = project_id and p.owner_id = auth.uid())));
-- owner verifies a claimed credit; credited person confirms a credit given to them (API enforces which side)
create policy "credits update" on project_credits for update
  using (profile_id = auth.uid() or exists (select 1 from projects p where p.id = project_id and p.owner_id = auth.uid()));
create policy "credits delete" on project_credits for delete
  using (created_by = auth.uid() or profile_id = auth.uid());

-- network
create policy "conn read"   on connections for select using (auth.uid() in (requester_id, addressee_id));
create policy "conn insert" on connections for insert with check (auth.uid() = requester_id);
create policy "conn update" on connections for update using (auth.uid() = addressee_id);
create policy "conn delete" on connections for delete using (auth.uid() in (requester_id, addressee_id));
create policy "follows read"  on follows for select using (true);
create policy "follows write" on follows for all using (auth.uid() = follower_id) with check (auth.uid() = follower_id);
create policy "recs read" on recommendations for select
  using (status = 'visible' or author_id = auth.uid() or recipient_id = auth.uid());
create policy "recs insert" on recommendations for insert with check (author_id = auth.uid());
create policy "recs update" on recommendations for update using (recipient_id = auth.uid() or author_id = auth.uid());
create policy "recs delete" on recommendations for delete using (author_id = auth.uid() or recipient_id = auth.uid());
create policy "blocks own" on blocks for all using (blocker_id = auth.uid()) with check (blocker_id = auth.uid());

-- feed
create policy "posts read"   on posts for select using (visibility = 'public' or author_id = auth.uid());
create policy "posts insert" on posts for insert with check (author_id = auth.uid());
create policy "posts update" on posts for update using (author_id = auth.uid());
create policy "posts delete" on posts for delete using (author_id = auth.uid());
create policy "pmedia read"  on post_media for select using (true);
create policy "pmedia write" on post_media for all using (exists (select 1 from posts p where p.id = post_id and p.author_id = auth.uid()));
create policy "comments read"   on comments for select using (true);
create policy "comments insert" on comments for insert with check (author_id = auth.uid());
create policy "comments update" on comments for update using (author_id = auth.uid());
create policy "comments delete" on comments for delete using (author_id = auth.uid());
create policy "likes read"  on likes for select using (true);
create policy "likes write" on likes for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "shares read"  on post_shares for select using (true);
create policy "shares write" on post_shares for all using (user_id = auth.uid()) with check (user_id = auth.uid());
create policy "bookmarks own" on bookmarks for all using (user_id = auth.uid()) with check (user_id = auth.uid());

-- jobs
create policy "jobs read"  on jobs for select using (status = 'open' or is_org_member(organization_id));
create policy "jobs write" on jobs for all
  using (is_org_member(organization_id, array['owner','admin','recruiter']::org_role[]))
  with check (is_org_member(organization_id, array['owner','admin','recruiter']::org_role[]) and posted_by = auth.uid());
create policy "apps read" on job_applications for select
  using (applicant_id = auth.uid() or exists (select 1 from jobs j where j.id = job_id and is_org_member(j.organization_id)));
create policy "apps insert" on job_applications for insert with check (applicant_id = auth.uid());
-- applicants may only withdraw; recruiters change status (API restricts columns)
create policy "apps update" on job_applications for update
  using (applicant_id = auth.uid() or exists (select 1 from jobs j where j.id = job_id and is_org_member(j.organization_id)));
create policy "saved searches own" on saved_searches for all using (owner_id = auth.uid()) with check (owner_id = auth.uid());

-- wallet: read-only for the owner. All writes go through SECURITY DEFINER functions / service role.
create policy "wallet read" on wallets for select using (profile_id = auth.uid());
create policy "payments read" on payments for select using (profile_id = auth.uid());
create policy "txn read" on credit_transactions for select using (profile_id = auth.uid());
create policy "spotlights read" on spotlights for select using (ends_at > now() or profile_id = auth.uid());
create policy "intros read" on introductions for select using (sender_id = auth.uid() or recipient_id = auth.uid());
create policy "intros respond" on introductions for update using (recipient_id = auth.uid());

-- messaging
create policy "members read" on conversation_members for select
  using (profile_id = auth.uid() or conversation_id in (select conversation_id from conversation_members where profile_id = auth.uid()));
create policy "convos read" on conversations for select
  using (id in (select conversation_id from conversation_members where profile_id = auth.uid()));
create policy "msgs read" on messages for select
  using (conversation_id in (select conversation_id from conversation_members where profile_id = auth.uid()));
create policy "msgs insert" on messages for insert
  with check (sender_id = auth.uid() and conversation_id in (select conversation_id from conversation_members where profile_id = auth.uid()));

create policy "notifs read"   on notifications for select using (recipient_id = auth.uid());
create policy "notifs update" on notifications for update using (recipient_id = auth.uid());
create policy "verif own"     on verification_requests for select using (profile_id = auth.uid() or (organization_id is not null and is_org_member(organization_id)));
create policy "verif insert"  on verification_requests for insert with check (profile_id = auth.uid() or (organization_id is not null and is_org_member(organization_id, array['owner','admin']::org_role[])));
create policy "reports insert" on reports for insert with check (reporter_id = auth.uid());

-- ---------------------------------------------------------------------
-- STORAGE BUCKETS (create in Dashboard)
--   avatars (public) | covers (public) | portfolio-media (public or signed) | post-media (public)
--   verification-docs (private, admin read only) | message-attachments (private)
-- REALTIME:  alter publication supabase_realtime add table messages, notifications;
-- =====================================================================