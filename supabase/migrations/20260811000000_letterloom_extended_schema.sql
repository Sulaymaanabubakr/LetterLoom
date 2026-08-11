-- Extended Schema Migration for LetterLoom: Profiles, XP, Achievements, Daily Challenges, Ranked Ratings, Leaderboards

create table if not exists public.player_profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  username text not null,
  lower_username text not null unique check (char_length(trim(lower_username)) between 3 and 20),
  display_name text not null,
  avatar_id text not null default 'avatar_owl',
  country_code text not null default 'US',
  is_guest boolean not null default false,
  level integer not null default 1 check (level >= 1),
  xp integer not null default 0 check (xp >= 0),
  ranked_tier text not null default 'Bronze III',
  ranked_rating integer not null default 1200 check (ranked_rating >= 100),
  games_played integer not null default 0 check (games_played >= 0),
  wins integer not null default 0 check (wins >= 0),
  losses integer not null default 0 check (losses >= 0),
  draws integer not null default 0 check (draws >= 0),
  highest_score integer not null default 0 check (highest_score >= 0),
  current_streak integer not null default 0 check (current_streak >= 0),
  best_streak integer not null default 0 check (best_streak >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create unique index if not exists player_profiles_lower_username_idx
  on public.player_profiles (lower_username);

create index if not exists player_profiles_ranked_rating_idx
  on public.player_profiles (ranked_rating desc);

create index if not exists player_profiles_wins_idx
  on public.player_profiles (wins desc);

create table if not exists public.daily_challenges (
  date_str text primary key,
  puzzle_data jsonb not null default '{}'::jsonb,
  best_score integer not null default 0,
  created_at timestamptz not null default now()
);

create table if not exists public.daily_challenge_results (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  date_str text not null references public.daily_challenges(date_str) on delete cascade,
  score integer not null check (score >= 0),
  stars integer not null check (stars between 1 and 3),
  created_at timestamptz not null default now(),
  unique (user_id, date_str)
);

create table if not exists public.player_achievements (
  user_id uuid not null references auth.users(id) on delete cascade,
  achievement_id text not null,
  unlocked_at timestamptz not null default now(),
  primary key (user_id, achievement_id)
);

create table if not exists public.ranked_matches (
  id uuid primary key default gen_random_uuid(),
  player_one_id uuid not null references auth.users(id) on delete cascade,
  player_two_id uuid not null references auth.users(id) on delete cascade,
  winner_id uuid references auth.users(id) on delete set null,
  rating_delta_p1 integer not null default 0,
  rating_delta_p2 integer not null default 0,
  completed_at timestamptz not null default now()
);

-- All competitive/progression fields are server-owned.  The public profile
-- endpoint may edit presentation fields only; this trigger prevents a
-- modified client from changing XP, ratings, statistics, or guest status.
create or replace function public.validate_player_profile_write()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized text;
  role_name text := coalesce(auth.role(), 'anon');
begin
  if new.id <> auth.uid() and role_name <> 'service_role' then
    raise exception 'profile owner mismatch';
  end if;

  normalized := lower(trim(new.username));
  if normalized !~ '^[a-z0-9_]{3,20}$' then
    raise exception 'invalid username';
  end if;
  if normalized in ('admin','administrator','moderator','letterloom','support',
                    'official','system','root','superuser','helpdesk',
                    'security','guest','null','undefined')
     or normalized like '%letterloom%'
     or normalized like '%badword%'
     or normalized like '%profanity%'
     or normalized like '%hate%'
     or normalized like '%scam%'
     or normalized like '%abuse%' then
    raise exception 'reserved or unavailable username';
  end if;
  new.username := trim(new.username);
  new.lower_username := normalized;
  if length(trim(new.display_name)) not between 1 and 40 then
    raise exception 'invalid display name';
  end if;
  if new.avatar_id not in ('avatar_owl','avatar_knight','avatar_crown',
                           'avatar_falcon','avatar_dragon','avatar_wizard',
                           'avatar_lion','avatar_panther') then
    raise exception 'invalid avatar';
  end if;
  if new.country_code !~ '^[A-Z]{2}$' then
    raise exception 'invalid country';
  end if;

  if tg_op = 'UPDATE' and role_name <> 'service_role' then
    new.is_guest := old.is_guest;
    new.level := old.level;
    new.xp := old.xp;
    new.ranked_tier := old.ranked_tier;
    new.ranked_rating := old.ranked_rating;
    new.games_played := old.games_played;
    new.wins := old.wins;
    new.losses := old.losses;
    new.draws := old.draws;
    new.highest_score := old.highest_score;
    new.current_streak := old.current_streak;
    new.best_streak := old.best_streak;
    new.created_at := old.created_at;
  elsif tg_op = 'INSERT' and role_name <> 'service_role' then
    new.is_guest := false;
    new.level := 1;
    new.xp := 0;
    new.ranked_tier := 'Bronze III';
    new.ranked_rating := 1200;
    new.games_played := 0;
    new.wins := 0;
    new.losses := 0;
    new.draws := 0;
    new.highest_score := 0;
    new.current_streak := 0;
    new.best_streak := 0;
    new.created_at := now();
  end if;
  new.updated_at := now();
  return new;
end;
$$;

drop trigger if exists player_profiles_validate_write on public.player_profiles;
create trigger player_profiles_validate_write
before insert or update on public.player_profiles
for each row execute function public.validate_player_profile_write();

alter table public.player_profiles enable row level security;
alter table public.daily_challenges enable row level security;
alter table public.daily_challenge_results enable row level security;
alter table public.player_achievements enable row level security;
alter table public.ranked_matches enable row level security;

-- RLS Policies
create policy "profiles are viewable by all authenticated users"
  on public.player_profiles for select to authenticated using (true);

create policy "users can insert their own profile"
  on public.player_profiles for insert to authenticated with check ((select auth.uid()) = id);

create policy "users can update their own profile"
  on public.player_profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

create policy "daily challenges viewable by all authenticated users"
  on public.daily_challenges for select to authenticated using (true);

-- Results are written only by a future server-side challenge verifier.  A
-- client-provided score/stars pair is not an authoritative submission.

create policy "users can view daily challenge results"
  on public.daily_challenge_results for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "users can view their achievements"
  on public.player_achievements for select to authenticated
  using ((select auth.uid()) = user_id);

create policy "players can view their ranked matches"
  on public.ranked_matches for select to authenticated
  using ((select auth.uid()) in (player_one_id, player_two_id));

create index if not exists daily_challenge_results_date_idx
  on public.daily_challenge_results (date_str, score desc);
create index if not exists player_achievements_user_idx
  on public.player_achievements (user_id, unlocked_at desc);
create index if not exists ranked_matches_players_completed_idx
  on public.ranked_matches (player_one_id, player_two_id, completed_at desc);
