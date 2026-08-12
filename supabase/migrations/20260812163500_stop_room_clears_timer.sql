-- Stopping a casual room is terminal. Remove its active countdown so neither
-- participant can time out a match that the owner has already stopped.
create or replace function public.stop_multiplayer_room_timer(p_game_id uuid)
returns void
language plpgsql
security definer
set search_path = public
as $$
begin
  if not pg_has_role(current_user, 'service_role', 'member') then
    raise exception 'service role required';
  end if;
  update public.multiplayer_games
     set status = 'abandoned', turn_started_at = null, paused_at = now()
   where id = p_game_id and status in ('waiting', 'active');
end;
$$;

revoke all on function public.stop_multiplayer_room_timer(uuid) from public, anon, authenticated;
grant execute on function public.stop_multiplayer_room_timer(uuid) to service_role;
