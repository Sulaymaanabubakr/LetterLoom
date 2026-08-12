-- Multiplayer racks are dealt by the server. Ensure both players can make a
-- meaningful first-turn attempt instead of receiving a rack of consonants.
create or replace function public.initialize_multiplayer_game(p_game_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game public.multiplayer_games%rowtype;
  v_player_one uuid;
  v_player_two uuid;
  v_board jsonb := '[]'::jsonb;
  v_row jsonb;
  v_bag jsonb := '[]'::jsonb;
  v_p1 jsonb := '[]'::jsonb;
  v_p2 jsonb := '[]'::jsonb;
  v_letter text;
  v_score integer;
  v_count integer;
  v_i integer;
  v_pick integer;
  v_tile jsonb;
  v_id integer := 0;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then
    raise exception 'service role required';
  end if;

  select * into v_game from public.multiplayer_games where id = p_game_id for update;
  if not found or v_game.status <> 'active' then raise exception 'game is not active'; end if;
  select user_id into v_player_one from public.multiplayer_players where game_id = p_game_id and player_number = 1;
  select user_id into v_player_two from public.multiplayer_players where game_id = p_game_id and player_number = 2;
  if v_player_one is null or v_player_two is null then raise exception 'two players required'; end if;
  if jsonb_array_length(coalesce(v_game.board,'[]'::jsonb)) = 15 then
    return jsonb_build_object('initialized', false, 'game_id', p_game_id);
  end if;

  for v_i in 0..14 loop
    v_row := '[]'::jsonb;
    for v_count in 0..14 loop
      v_row := v_row || jsonb_build_array(jsonb_build_object(
        'row', v_i, 'col', v_count, 'type', public.multiplayer_cell_type(v_i, v_count),
        'tile', null, 'isNewPlacement', false));
    end loop;
    v_board := v_board || jsonb_build_array(v_row);
  end loop;

  for v_letter, v_count in select * from (values
    ('A',9),('B',2),('C',2),('D',4),('E',12),('F',2),('G',3),('H',2),('I',9),
    ('J',1),('K',1),('L',4),('M',2),('N',6),('O',8),('P',2),('Q',1),('R',6),
    ('S',4),('T',6),('U',4),('V',2),('W',2),('X',1),('Y',2),('Z',1),(' ',2)
  ) as distribution(letter, count) loop
    v_score := case v_letter when 'A' then 1 when 'B' then 3 when 'C' then 3 when 'D' then 2 when 'E' then 1 when 'F' then 4 when 'G' then 2 when 'H' then 4 when 'I' then 1 when 'J' then 8 when 'K' then 5 when 'L' then 1 when 'M' then 3 when 'N' then 1 when 'O' then 1 when 'P' then 3 when 'Q' then 10 when 'R' then 1 when 'S' then 1 when 'T' then 1 when 'U' then 1 when 'V' then 4 when 'W' then 4 when 'X' then 8 when 'Y' then 4 when 'Z' then 10 else 0 end;
    for v_i in 1..v_count loop
      v_bag := v_bag || jsonb_build_array(jsonb_build_object(
        'id', 'server_tile_' || v_id, 'letter', v_letter, 'scoreValue', v_score,
        'isBlank', v_letter = ' ', 'blankLetter', null));
      v_id := v_id + 1;
    end loop;
  end loop;

  -- Shuffle once, then take alternating tiles so neither rack is favoured.
  for v_i in 1..7 loop
    v_pick := floor(random() * jsonb_array_length(v_bag)); v_tile := v_bag->v_pick; v_bag := v_bag-v_pick; v_p1 := v_p1 || jsonb_build_array(v_tile);
    v_pick := floor(random() * jsonb_array_length(v_bag)); v_tile := v_bag->v_pick; v_bag := v_bag-v_pick; v_p2 := v_p2 || jsonb_build_array(v_tile);
  end loop;

  -- Guarantee at least one playable vowel or blank for both opening racks.
  -- Only non-vowels are exchanged, so rack size and the global tile pool stay exact.
  while not exists (select 1 from jsonb_array_elements(v_p1) x where x->>'letter' in ('A','E','I','O','U',' ')) loop
    v_pick := floor(random() * jsonb_array_length(v_p1)); v_tile := v_p1->v_pick; v_p1 := v_p1-v_pick; v_bag := v_bag || jsonb_build_array(v_tile);
    select ordinality - 1, value into v_pick, v_tile from jsonb_array_elements(v_bag) with ordinality where value->>'letter' in ('A','E','I','O','U',' ') order by random() limit 1;
    v_bag := v_bag-v_pick; v_p1 := v_p1 || jsonb_build_array(v_tile);
  end loop;
  while not exists (select 1 from jsonb_array_elements(v_p2) x where x->>'letter' in ('A','E','I','O','U',' ')) loop
    v_pick := floor(random() * jsonb_array_length(v_p2)); v_tile := v_p2->v_pick; v_p2 := v_p2-v_pick; v_bag := v_bag || jsonb_build_array(v_tile);
    select ordinality - 1, value into v_pick, v_tile from jsonb_array_elements(v_bag) with ordinality where value->>'letter' in ('A','E','I','O','U',' ') order by random() limit 1;
    v_bag := v_bag-v_pick; v_p2 := v_p2 || jsonb_build_array(v_tile);
  end loop;

  update public.multiplayer_games set board=v_board, player_one_score=0, player_two_score=0,
    consecutive_passes=0, move_number=0, current_turn_user_id=v_player_one, turn_started_at=now()
  where id=p_game_id;
  insert into public.multiplayer_game_private(game_id,tile_bag) values(p_game_id,v_bag)
    on conflict(game_id) do update set tile_bag=excluded.tile_bag;
  insert into public.multiplayer_player_private(game_id,user_id,rack)
  values(p_game_id,v_player_one,v_p1),(p_game_id,v_player_two,v_p2)
    on conflict(game_id,user_id) do update set rack=excluded.rack;
  return jsonb_build_object('initialized',true,'game_id',p_game_id);
end;
$$;
