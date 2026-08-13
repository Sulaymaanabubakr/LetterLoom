-- Expand casual rooms without removing the scalar score columns used by older
-- clients. New code reads player_scores; the scalar columns remain a 2-player
-- compatibility projection.
alter table public.multiplayer_games
  add column if not exists max_players smallint not null default 2
    check (max_players between 2 and 4),
  add column if not exists player_scores jsonb not null default '{}'::jsonb,
  add column if not exists winner_ids jsonb not null default '[]'::jsonb;

alter table public.multiplayer_players
  drop constraint if exists multiplayer_players_player_number_check;
alter table public.multiplayer_players
  add constraint multiplayer_players_player_number_check
  check (player_number between 1 and 4);
alter table public.multiplayer_players
  add column if not exists connection_status text not null default 'connected'
    check (connection_status in ('connected', 'disconnected')),
  add column if not exists mic_enabled boolean not null default false;

update public.multiplayer_games g
set player_scores = coalesce(
  (select jsonb_object_agg(p.user_id::text,
      case p.player_number when 1 then g.player_one_score when 2 then g.player_two_score else 0 end)
   from public.multiplayer_players p where p.game_id = g.id),
  '{}'::jsonb
)
where g.player_scores = '{}'::jsonb;

-- A room now starts only when its configured capacity is reached. Existing
-- rooms retain max_players = 2 and therefore behave exactly as before.
create or replace function public.initialize_multiplayer_game(p_game_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game public.multiplayer_games%rowtype;
  v_board jsonb := '[]'::jsonb;
  v_row jsonb;
  v_bag jsonb := '[]'::jsonb;
  v_scores jsonb := '{}'::jsonb;
  v_letter text;
  v_score integer;
  v_count integer;
  v_i integer;
  v_pick integer;
  v_tile jsonb;
  v_id integer := 0;
  v_player record;
  v_rack jsonb;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then raise exception 'service role required'; end if;
  select * into v_game from public.multiplayer_games where id = p_game_id for update;
  if not found or v_game.status <> 'active' then raise exception 'game is not active'; end if;
  if (select count(*) from public.multiplayer_players where game_id = p_game_id) < v_game.max_players then
    raise exception 'room is not full';
  end if;
  if jsonb_array_length(coalesce(v_game.board,'[]'::jsonb)) = 15 then
    return jsonb_build_object('initialized', false, 'game_id', p_game_id);
  end if;

  for v_i in 0..14 loop
    v_row := '[]'::jsonb;
    for v_count in 0..14 loop
      v_row := v_row || jsonb_build_array(jsonb_build_object('row',v_i,'col',v_count,
        'type',public.multiplayer_cell_type(v_i,v_count),'tile',null,'isNewPlacement',false));
    end loop;
    v_board := v_board || jsonb_build_array(v_row);
  end loop;
  for v_letter, v_count in select * from (values
    ('A',9),('B',2),('C',2),('D',4),('E',12),('F',2),('G',3),('H',2),('I',9),
    ('J',1),('K',1),('L',4),('M',2),('N',6),('O',8),('P',2),('Q',1),('R',6),
    ('S',4),('T',6),('U',4),('V',2),('W',2),('X',1),('Y',2),('Z',1),(' ',2)
  ) as distribution(letter,count) loop
    v_score := case v_letter when 'A' then 1 when 'B' then 3 when 'C' then 3 when 'D' then 2 when 'E' then 1 when 'F' then 4 when 'G' then 2 when 'H' then 4 when 'I' then 1 when 'J' then 8 when 'K' then 5 when 'L' then 1 when 'M' then 3 when 'N' then 1 when 'O' then 1 when 'P' then 3 when 'Q' then 10 when 'R' then 1 when 'S' then 1 when 'T' then 1 when 'U' then 1 when 'V' then 4 when 'W' then 4 when 'X' then 8 when 'Y' then 4 when 'Z' then 10 else 0 end;
    for v_i in 1..v_count loop
      v_bag := v_bag || jsonb_build_array(jsonb_build_object('id','server_tile_'||v_id,'letter',v_letter,'scoreValue',v_score,'isBlank',v_letter=' ','blankLetter',null));
      v_id := v_id + 1;
    end loop;
  end loop;
  for v_player in select user_id, player_number from public.multiplayer_players where game_id=p_game_id order by player_number loop
    v_rack := '[]'::jsonb;
    for v_i in 1..7 loop
      v_pick := floor(random()*jsonb_array_length(v_bag));
      v_tile := v_bag->v_pick; v_bag := v_bag-v_pick; v_rack := v_rack || jsonb_build_array(v_tile);
    end loop;
    v_scores := v_scores || jsonb_build_object(v_player.user_id::text, 0);
    insert into public.multiplayer_player_private(game_id,user_id,rack) values(p_game_id,v_player.user_id,v_rack)
      on conflict (game_id,user_id) do update set rack=excluded.rack;
  end loop;
  update public.multiplayer_games set board=v_board, player_one_score=0, player_two_score=0,
    player_scores=v_scores, winner_ids='[]'::jsonb, consecutive_passes=0, move_number=0,
    current_turn_user_id=(select user_id from public.multiplayer_players where game_id=p_game_id order by player_number limit 1),
    turn_started_at=now() where id=p_game_id;
  insert into public.multiplayer_game_private(game_id,tile_bag) values(p_game_id,v_bag)
    on conflict (game_id) do update set tile_bag=excluded.tile_bag;
  return jsonb_build_object('initialized',true,'game_id',p_game_id);
end;
$$;
revoke all on function public.initialize_multiplayer_game(uuid) from public, anon, authenticated;
grant execute on function public.initialize_multiplayer_game(uuid) to service_role;

-- Keep the existing authoritative move validator for 2-player rooms, while
-- making its persisted turn and score projection list-based for 3/4 players.
-- This trigger runs in the same transaction as the move and therefore cannot
-- be observed in a partially advanced state.
create or replace function public.sync_multiplayer_player_list_state()
returns trigger
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game public.multiplayer_games%rowtype;
  v_number smallint;
  v_scores jsonb;
  v_next uuid;
begin
  select * into v_game from public.multiplayer_games where id = new.game_id for update;
  select player_number into v_number from public.multiplayer_players where game_id = new.game_id and user_id = new.user_id;
  v_scores := coalesce(v_game.player_scores, '{}'::jsonb);
  if v_number = 1 then v_scores := jsonb_set(v_scores, array[new.user_id::text], to_jsonb(v_game.player_one_score), true);
  elsif v_number = 2 then v_scores := jsonb_set(v_scores, array[new.user_id::text], to_jsonb(v_game.player_two_score), true);
  else v_scores := jsonb_set(v_scores, array[new.user_id::text], to_jsonb(coalesce((v_scores->>new.user_id::text)::integer, 0) + new.score), true);
  end if;
  select user_id into v_next from public.multiplayer_players where game_id = new.game_id and player_number = (
    case when v_number = (select max(player_number) from public.multiplayer_players where game_id = new.game_id)
      then 1 else v_number + 1 end);
  update public.multiplayer_games set player_scores = v_scores,
    current_turn_user_id = case when status = 'active' then v_next else current_turn_user_id end,
    turn_started_at = case when status = 'active' then now() else turn_started_at end
  where id = new.game_id;
  select * into v_game from public.multiplayer_games where id = new.game_id;
  if v_game.status = 'completed' or (v_game.status = 'active' and v_game.consecutive_passes >= v_game.max_players * 2) then
    update public.multiplayer_games set status = 'completed', current_turn_user_id = null,
      turn_started_at = null,
      winner_ids = coalesce((select jsonb_agg(key order by key) from jsonb_each_text(v_scores) where value::integer = (select max(value::integer) from jsonb_each_text(v_scores))), '[]'::jsonb),
      winner_id = (select key::uuid from jsonb_each_text(v_scores) where value::integer = (select max(value::integer) from jsonb_each_text(v_scores)) limit 1)
    where id = new.game_id;
  end if;
  return new;
end;
$$;
drop trigger if exists multiplayer_move_sync_player_list on public.multiplayer_moves;
create trigger multiplayer_move_sync_player_list after insert on public.multiplayer_moves
for each row execute function public.sync_multiplayer_player_list_state();
