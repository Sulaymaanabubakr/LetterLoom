create or replace function public.is_multiplayer_participant(target_game_id uuid)
returns boolean
language sql
security definer
set search_path = public
as $$
  select exists (
    select 1
    from public.multiplayer_players
    where game_id = target_game_id
      and user_id = (select auth.uid())
  );
$$;

revoke all on function public.is_multiplayer_participant(uuid) from public;
grant execute on function public.is_multiplayer_participant(uuid) to authenticated;

drop policy if exists "participants can read multiplayer games" on public.multiplayer_games;
create policy "participants can read multiplayer games"
on public.multiplayer_games
for select
to authenticated
using (public.is_multiplayer_participant(id));

drop policy if exists "participants can read multiplayer players" on public.multiplayer_players;
create policy "participants can read multiplayer players"
on public.multiplayer_players
for select
to authenticated
using (public.is_multiplayer_participant(game_id));

drop policy if exists "participants can read move history" on public.multiplayer_moves;
create policy "participants can read move history"
on public.multiplayer_moves
for select
to authenticated
using (public.is_multiplayer_participant(game_id));
