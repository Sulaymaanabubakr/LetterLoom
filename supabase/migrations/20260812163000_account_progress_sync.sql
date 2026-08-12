-- Durable account progress for solo play. Wallets, purchases, daily rewards,
-- ranked outcomes, and multiplayer state remain in their existing server-owned
-- tables. This table stores account-scoped settings, detailed solo statistics,
-- and one resumable solo game so they survive a reinstall or device change.

create table if not exists public.player_game_progress (
  user_id uuid primary key references auth.users(id) on delete cascade,
  statistics jsonb not null default '{}'::jsonb,
  settings jsonb not null default '{}'::jsonb,
  active_game jsonb,
  updated_at timestamptz not null default now()
);

create table if not exists public.letterloom_progress_events (
  user_id uuid not null references auth.users(id) on delete cascade,
  event_key text not null check (char_length(trim(event_key)) between 12 and 180),
  event_type text not null check (event_type in ('solo_game', 'xp')),
  amount integer not null default 0 check (amount >= 0 and amount <= 10000),
  created_at timestamptz not null default now(),
  primary key (user_id, event_key)
);

alter table public.player_achievements
  add column if not exists current_value integer not null default 1 check (current_value >= 0),
  add column if not exists is_unlocked boolean not null default true;

create or replace function public.upsert_player_achievement_progress(
  p_user_id uuid,
  p_achievement_id text,
  p_current_value integer,
  p_is_unlocked boolean,
  p_unlocked_at timestamptz default null
)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not pg_has_role(current_user, 'service_role', 'member') then
    raise exception 'service role required';
  end if;
  if p_achievement_id not in (
    'first_victory','first_bingo','hard_earned','big_move','triple_century',
    'wordsmith','winning_streak','veteran','champion','century_champion',
    'close_call','comeback','seven_day_streak','ranked_debut','moving_up',
    'bingo_master'
  ) then raise exception 'unknown achievement'; end if;
  if p_current_value < 0 or p_current_value > 10000000 then
    raise exception 'invalid achievement value';
  end if;
  insert into public.player_achievements(user_id, achievement_id, current_value, is_unlocked, unlocked_at)
  values(p_user_id, p_achievement_id, p_current_value, p_is_unlocked, case when p_is_unlocked then coalesce(p_unlocked_at, now()) else now() end)
  on conflict (user_id, achievement_id) do update
    set current_value = greatest(player_achievements.current_value, excluded.current_value),
        is_unlocked = player_achievements.is_unlocked or excluded.is_unlocked,
        unlocked_at = case
          when player_achievements.is_unlocked then player_achievements.unlocked_at
          when excluded.is_unlocked then excluded.unlocked_at
          else player_achievements.unlocked_at
        end;
end;
$$;

alter table public.player_game_progress enable row level security;
alter table public.letterloom_progress_events enable row level security;
revoke all on public.player_game_progress from anon, authenticated;
revoke all on public.letterloom_progress_events from anon, authenticated;

create or replace function public.record_account_solo_game_result(
  p_user_id uuid,
  p_event_key text,
  p_result text,
  p_score integer,
  p_xp integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted integer;
  v_profile public.player_profiles%rowtype;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then
    raise exception 'service role required';
  end if;
  if p_result not in ('win', 'loss', 'tie') then raise exception 'invalid game result'; end if;
  if p_score < 0 or p_score > 100000 then raise exception 'invalid game score'; end if;
  if p_xp < 0 or p_xp > 1000 then raise exception 'invalid experience amount'; end if;

  insert into public.letterloom_progress_events(user_id, event_key, event_type, amount)
  values(p_user_id, p_event_key, 'solo_game', p_xp)
  on conflict (user_id, event_key) do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted = 1 then
    update public.player_profiles
      set games_played = games_played + 1,
          wins = wins + case when p_result = 'win' then 1 else 0 end,
          losses = losses + case when p_result = 'loss' then 1 else 0 end,
          draws = draws + case when p_result = 'tie' then 1 else 0 end,
          highest_score = greatest(highest_score, p_score),
          current_streak = case when p_result = 'win' then current_streak + 1 else 0 end,
          best_streak = greatest(best_streak, case when p_result = 'win' then current_streak + 1 else 0 end),
          xp = xp + p_xp,
          level = public.letterloom_level_for_xp(xp + p_xp),
          updated_at = now()
      where id = p_user_id
      returning * into v_profile;
  else
    select * into v_profile from public.player_profiles where id = p_user_id;
  end if;

  if not found then raise exception 'player profile not found'; end if;
  return jsonb_build_object('recorded', v_inserted = 1, 'profile', to_jsonb(v_profile));
end;
$$;

create or replace function public.grant_account_xp(
  p_user_id uuid,
  p_event_key text,
  p_amount integer
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_inserted integer;
  v_profile public.player_profiles%rowtype;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then
    raise exception 'service role required';
  end if;
  if p_amount < 1 or p_amount > 1000 then raise exception 'invalid experience amount'; end if;

  insert into public.letterloom_progress_events(user_id, event_key, event_type, amount)
  values(p_user_id, p_event_key, 'xp', p_amount)
  on conflict (user_id, event_key) do nothing;
  get diagnostics v_inserted = row_count;

  if v_inserted = 1 then
    update public.player_profiles
      set xp = xp + p_amount,
          level = public.letterloom_level_for_xp(xp + p_amount),
          updated_at = now()
      where id = p_user_id
      returning * into v_profile;
  else
    select * into v_profile from public.player_profiles where id = p_user_id;
  end if;
  if not found then raise exception 'player profile not found'; end if;
  return jsonb_build_object('granted', v_inserted = 1, 'profile', to_jsonb(v_profile));
end;
$$;

revoke all on function public.record_account_solo_game_result(uuid, text, text, integer, integer) from public, anon, authenticated;
revoke all on function public.grant_account_xp(uuid, text, integer) from public, anon, authenticated;
revoke all on function public.upsert_player_achievement_progress(uuid, text, integer, boolean, timestamptz) from public, anon, authenticated;
grant execute on function public.record_account_solo_game_result(uuid, text, text, integer, integer) to service_role;
grant execute on function public.grant_account_xp(uuid, text, integer) to service_role;
grant execute on function public.upsert_player_achievement_progress(uuid, text, integer, boolean, timestamptz) to service_role;

create index if not exists letterloom_progress_events_user_created_idx
  on public.letterloom_progress_events(user_id, created_at desc);
