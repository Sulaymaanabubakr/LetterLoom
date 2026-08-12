-- Anonymous Supabase sessions are useful for auth bootstrap, but they must
-- not gain access to account, multiplayer, ranked, or synced challenge data.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.is_real_user()
returns boolean
language sql
security definer
set search_path = auth, pg_temp
as $$
  select exists (
    select 1
    from auth.users
    where id = (select auth.uid())
      and coalesce(is_anonymous, false) = false
  );
$$;

revoke all on function private.is_real_user() from public, anon, authenticated;
grant execute on function private.is_real_user() to authenticated;

create or replace function private.is_multiplayer_participant(target_game_id uuid)
returns boolean
language sql
security definer
set search_path = public, pg_temp
as $$
  select private.is_real_user()
    and exists (
      select 1
      from public.multiplayer_players
      where game_id = target_game_id
        and user_id = (select auth.uid())
    );
$$;
revoke all on function private.is_multiplayer_participant(uuid) from public, anon, authenticated;
grant execute on function private.is_multiplayer_participant(uuid) to authenticated;

-- Apply the real-user guard to all policies identified by the Supabase
-- advisor as reachable by anonymous sessions.
alter policy "profiles are viewable by all authenticated users"
  on public.player_profiles using (private.is_real_user());
alter policy "users can insert their own profile"
  on public.player_profiles with check ((select auth.uid()) = id and private.is_real_user());
alter policy "users can update their own profile"
  on public.player_profiles
  using ((select auth.uid()) = id and private.is_real_user())
  with check ((select auth.uid()) = id and private.is_real_user());
alter policy "daily challenges viewable by all authenticated users"
  on public.daily_challenges using (private.is_real_user());
alter policy "users can view daily challenge results"
  on public.daily_challenge_results using ((select auth.uid()) = user_id and private.is_real_user());
alter policy "users can view their achievements"
  on public.player_achievements using ((select auth.uid()) = user_id and private.is_real_user());
alter policy "players can view their ranked matches"
  on public.ranked_matches using ((select auth.uid()) in (player_one_id, player_two_id) and private.is_real_user());
alter policy "Users can view their daily word progress"
  on public.daily_word_mosaic_progress using ((select auth.uid()) = user_id and private.is_real_user());
alter policy "Users can create their daily word progress"
  on public.daily_word_mosaic_progress with check ((select auth.uid()) = user_id and private.is_real_user());
alter policy "Users can update their daily word progress"
  on public.daily_word_mosaic_progress
  using ((select auth.uid()) = user_id and private.is_real_user())
  with check ((select auth.uid()) = user_id and private.is_real_user());
alter policy "players can view their ranked queue entry"
  on public.ranked_queue using ((select auth.uid()) = user_id and private.is_real_user());
alter policy "users can read their push devices"
  on public.push_devices using ((select auth.uid()) = user_id and private.is_real_user());
alter policy "users can register their push devices"
  on public.push_devices with check ((select auth.uid()) = user_id and private.is_real_user());
alter policy "users can update their push devices"
  on public.push_devices
  using ((select auth.uid()) = user_id and private.is_real_user())
  with check ((select auth.uid()) = user_id and private.is_real_user());
alter policy "users can remove their push devices"
  on public.push_devices using ((select auth.uid()) = user_id and private.is_real_user());
alter policy "participants can read multiplayer games"
  on public.multiplayer_games using (private.is_multiplayer_participant(id));
alter policy "participants can read multiplayer players"
  on public.multiplayer_players using (private.is_multiplayer_participant(game_id));
alter policy "participants can read move history"
  on public.multiplayer_moves using (private.is_multiplayer_participant(game_id));
alter policy "players can read their own rack"
  on public.multiplayer_player_private using ((select auth.uid()) = user_id and private.is_real_user());

-- These functions are invoked only by trusted Edge Functions or triggers.
-- Keeping their EXECUTE privilege off the public API prevents direct RPC use.
revoke all on function public.claim_ranked_opponent(uuid) from public, anon, authenticated;
revoke all on function public.settle_ranked_match(uuid) from public, anon, authenticated;
revoke all on function public.pause_multiplayer_game(uuid, uuid) from public, anon, authenticated;
revoke all on function public.resume_multiplayer_game(uuid, uuid) from public, anon, authenticated;
revoke all on function public.validate_player_profile_write() from public, anon, authenticated;
grant execute on function public.claim_ranked_opponent(uuid) to service_role;
grant execute on function public.settle_ranked_match(uuid) to service_role;
grant execute on function public.pause_multiplayer_game(uuid, uuid) to service_role;
grant execute on function public.resume_multiplayer_game(uuid, uuid) to service_role;

-- This helper is an implementation detail of the existing RLS policy.
revoke all on function public.is_multiplayer_participant(uuid) from public, anon, authenticated;

-- Keep one unique username index; the constraint already provides uniqueness.
drop index if exists public.player_profiles_lower_username_idx;

do $$
begin
  if exists (
    select 1 from pg_proc
    where pronamespace = 'public'::regnamespace
      and proname = 'rls_auto_enable'
  ) then
    revoke all on function public.rls_auto_enable() from public, anon, authenticated;
  end if;
end;
$$;
