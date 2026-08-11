-- A paused multiplayer game is frozen server-side. This prevents either
-- client from consuming turn time or submitting moves while one player is
-- away from the active match.
alter table public.multiplayer_games
  add column if not exists paused_by_user_id uuid references auth.users(id) on delete set null,
  add column if not exists paused_at timestamptz;

create index if not exists multiplayer_games_paused_idx
  on public.multiplayer_games (paused_at)
  where paused_at is not null;

create or replace function public.pause_multiplayer_game(p_game_id uuid, p_user_id uuid)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare g multiplayer_games%rowtype;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then raise exception 'service role required'; end if;
  select * into g from public.multiplayer_games where id = p_game_id for update;
  if not found then raise exception 'game not found'; end if;
  if not exists (select 1 from public.multiplayer_players where game_id = p_game_id and user_id = p_user_id) then
    raise exception 'not a player';
  end if;
  if g.status <> 'active' then raise exception 'game is not active'; end if;
  if g.paused_at is null then
    update public.multiplayer_games
      set paused_by_user_id = p_user_id, paused_at = now()
      where id = p_game_id;
  end if;
  return jsonb_build_object('paused', true, 'paused_at', coalesce(g.paused_at, now()));
end;
$$;

create or replace function public.resume_multiplayer_game(p_game_id uuid, p_user_id uuid)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare g multiplayer_games%rowtype; v_shift interval;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then raise exception 'service role required'; end if;
  select * into g from public.multiplayer_games where id = p_game_id for update;
  if not found then raise exception 'game not found'; end if;
  if not exists (select 1 from public.multiplayer_players where game_id = p_game_id and user_id = p_user_id) then
    raise exception 'not a player';
  end if;
  if g.paused_at is not null then
    v_shift := now() - g.paused_at;
    update public.multiplayer_games
      set turn_started_at = case when turn_started_at is null then null else turn_started_at + v_shift end,
          paused_by_user_id = null, paused_at = null
      where id = p_game_id;
  end if;
  return jsonb_build_object('paused', false);
end;
$$;

create or replace function public.reject_moves_while_multiplayer_paused()
returns trigger language plpgsql set search_path = public as $$
begin
  if exists (select 1 from public.multiplayer_games where id = new.game_id and paused_at is not null) then
    raise exception 'game is paused';
  end if;
  return new;
end;
$$;

drop trigger if exists multiplayer_moves_reject_when_paused on public.multiplayer_moves;
create trigger multiplayer_moves_reject_when_paused
before insert on public.multiplayer_moves
for each row execute function public.reject_moves_while_multiplayer_paused();
