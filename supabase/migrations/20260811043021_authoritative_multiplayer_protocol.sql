-- Authoritative multiplayer protocol.
-- The client submits an action and placements only.  The server owns the
-- board, racks, bag, scores, turn, timer and result.  The dictionary table is
-- intentionally empty here and must be seeded from the shipped dictionary
-- before multiplayer moves are enabled.

alter table public.multiplayer_moves
  drop constraint if exists multiplayer_moves_move_type_check;
alter table public.multiplayer_moves
  add constraint multiplayer_moves_move_type_check
  check (move_type in ('play', 'pass', 'exchange', 'timeout'));

create table if not exists public.letterloom_dictionary (
  word text primary key check (word = upper(word) and word ~ '^[A-Z]+$')
);

alter table public.letterloom_dictionary enable row level security;
revoke all on public.letterloom_dictionary from anon, authenticated;

create table if not exists public.multiplayer_move_requests (
  game_id uuid not null references public.multiplayer_games(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  client_action_id text not null check (char_length(trim(client_action_id)) between 8 and 120),
  move_number integer not null check (move_number > 0),
  response jsonb not null,
  created_at timestamptz not null default now(),
  primary key (game_id, user_id, client_action_id)
);

alter table public.multiplayer_move_requests enable row level security;
revoke all on public.multiplayer_move_requests from anon, authenticated;

create or replace function public.multiplayer_cell_type(p_row integer, p_col integer)
returns text
language sql immutable
set search_path = public
as $$
  select case
    when p_row = 7 and p_col = 7 then 'centre'
    when (p_row,p_col) in ((0,0),(0,7),(0,14),(7,0),(7,14),(14,0),(14,7),(14,14)) then 'tripleWord'
    when (p_row,p_col) in ((1,1),(2,2),(3,3),(4,4),(10,10),(11,11),(12,12),(13,13),(1,13),(2,12),(3,11),(4,10),(10,4),(11,3),(12,2),(13,1)) then 'doubleWord'
    when (p_row,p_col) in ((1,5),(1,9),(5,1),(5,5),(5,9),(5,13),(9,1),(9,5),(9,9),(9,13),(13,5),(13,9)) then 'tripleLetter'
    when (p_row,p_col) in ((0,3),(0,11),(2,6),(2,8),(3,0),(3,7),(3,14),(6,2),(6,6),(6,8),(6,12),(7,3),(7,11),(8,2),(8,6),(8,8),(8,12),(11,0),(11,7),(11,14),(12,6),(12,8),(14,3),(14,11)) then 'doubleLetter'
    else 'normal'
  end;
$$;

create or replace function public.multiplayer_tile_letter(p_tile jsonb)
returns text
language sql immutable
set search_path = public
as $$
  select upper(coalesce(nullif(p_tile->>'blankLetter',''), p_tile->>'letter', ''));
$$;

create or replace function public.multiplayer_board_letter(p_board jsonb, p_row integer, p_col integer)
returns text
language sql immutable
set search_path = public
as $$
  select public.multiplayer_tile_letter(
    coalesce(p_board->p_row->p_col->'tile', '{}'::jsonb)
  );
$$;

create or replace function public.multiplayer_word_exists(p_word text)
returns boolean
language sql stable
set search_path = public
as $$
  select exists(select 1 from public.letterloom_dictionary where word = upper(p_word));
$$;

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
  if not found or v_game.status <> 'active' then
    raise exception 'game is not active';
  end if;

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
        'row', v_i, 'col', v_count,
        'type', public.multiplayer_cell_type(v_i, v_count),
        'tile', null, 'isNewPlacement', false));
    end loop;
    v_board := v_board || jsonb_build_array(v_row);
  end loop;

  for v_letter, v_count in
    select * from (values
      ('A',9),('B',2),('C',2),('D',4),('E',12),('F',2),('G',3),('H',2),('I',9),
      ('J',1),('K',1),('L',4),('M',2),('N',6),('O',8),('P',2),('Q',1),('R',6),
      ('S',4),('T',6),('U',4),('V',2),('W',2),('X',1),('Y',2),('Z',1),(' ',2)
    ) as distribution(letter, count)
  loop
    v_score := case v_letter when 'A' then 1 when 'B' then 3 when 'C' then 3 when 'D' then 2 when 'E' then 1 when 'F' then 4 when 'G' then 2 when 'H' then 4 when 'I' then 1 when 'J' then 8 when 'K' then 5 when 'L' then 1 when 'M' then 3 when 'N' then 1 when 'O' then 1 when 'P' then 3 when 'Q' then 10 when 'R' then 1 when 'S' then 1 when 'T' then 1 when 'U' then 1 when 'V' then 4 when 'W' then 4 when 'X' then 8 when 'Y' then 4 when 'Z' then 10 else 0 end;
    for v_i in 1..v_count loop
      v_bag := v_bag || jsonb_build_array(jsonb_build_object(
        'id', 'server_tile_' || v_id, 'letter', v_letter,
        'scoreValue', v_score, 'isBlank', v_letter = ' ', 'blankLetter', null));
      v_id := v_id + 1;
    end loop;
  end loop;

  for v_i in 1..7 loop
    v_pick := floor(random() * jsonb_array_length(v_bag));
    v_tile := v_bag->v_pick;
    v_bag := v_bag - v_pick;
    v_p1 := v_p1 || jsonb_build_array(v_tile);
    v_pick := floor(random() * jsonb_array_length(v_bag));
    v_tile := v_bag->v_pick;
    v_bag := v_bag - v_pick;
    v_p2 := v_p2 || jsonb_build_array(v_tile);
  end loop;

  update public.multiplayer_games
  set board = v_board, player_one_score = 0, player_two_score = 0,
      consecutive_passes = 0, move_number = 0,
      current_turn_user_id = v_player_one, turn_started_at = now()
  where id = p_game_id;
  insert into public.multiplayer_game_private(game_id, tile_bag)
  values (p_game_id, v_bag)
  on conflict (game_id) do update set tile_bag = excluded.tile_bag;
  insert into public.multiplayer_player_private(game_id, user_id, rack)
  values (p_game_id, v_player_one, v_p1), (p_game_id, v_player_two, v_p2)
  on conflict (game_id, user_id) do update set rack = excluded.rack;
  return jsonb_build_object('initialized', true, 'game_id', p_game_id);
end;
$$;

create or replace function public.apply_multiplayer_move(
  p_game_id uuid,
  p_user_id uuid,
  p_client_action_id text,
  p_move_type text,
  p_placements jsonb default '[]'::jsonb,
  p_exchange_ids jsonb default '[]'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_game public.multiplayer_games%rowtype;
  v_player smallint;
  v_rack jsonb;
  v_bag jsonb;
  v_exchange_tiles jsonb := '[]'::jsonb;
  v_board jsonb;
  v_response jsonb;
  v_move_number integer;
  v_next_user uuid;
  v_row integer;
  v_col integer;
  v_min_row integer := 99;
  v_max_row integer := -1;
  v_min_col integer := 99;
  v_max_col integer := -1;
  v_item jsonb;
  v_tile jsonb;
  v_id text;
  v_word text;
  v_score integer := 0;
  v_word_score integer := 0;
  v_word_multiplier integer := 1;
  v_cross_score integer := 0;
  v_cross_multiplier integer := 1;
  v_cross_start integer;
  v_cross_end integer;
  v_cross_word text;
  v_opponent_rack jsonb;
  v_p1_score integer;
  v_p2_score integer;
  v_next_passes integer;
  v_p1_rack_value integer := 0;
  v_p2_rack_value integer := 0;
  v_status text := 'active';
  v_winner uuid;
  v_new_count integer;
  v_has_locked boolean := false;
  v_connects boolean := false;
  v_horizontal boolean;
  v_i integer;
  v_j integer;
  v_cell jsonb;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then raise exception 'service role required'; end if;
  if p_move_type not in ('play','pass','exchange','timeout') then raise exception 'invalid move type'; end if;
  if p_client_action_id is null or length(trim(p_client_action_id)) not between 8 and 120 then raise exception 'invalid action id'; end if;

  select response into v_response from public.multiplayer_move_requests
  where game_id = p_game_id and user_id = p_user_id and client_action_id = p_client_action_id;
  if found then return v_response; end if;

  select * into v_game from public.multiplayer_games where id = p_game_id for update;
  if not found or v_game.status <> 'active' then raise exception 'game is not active'; end if;
  select response into v_response from public.multiplayer_move_requests
  where game_id = p_game_id and user_id = p_user_id and client_action_id = p_client_action_id;
  if found then return v_response; end if;
  select player_number into v_player from public.multiplayer_players where game_id = p_game_id and user_id = p_user_id;
  if v_player is null then raise exception 'not a player'; end if;
  if v_game.current_turn_user_id <> p_user_id then raise exception 'not your turn'; end if;
  if p_move_type <> 'timeout' and v_game.turn_started_at is not null and now() > v_game.turn_started_at + interval '120 seconds' then raise exception 'turn expired'; end if;
  select rack into v_rack from public.multiplayer_player_private where game_id = p_game_id and user_id = p_user_id for update;
  select tile_bag into v_bag from public.multiplayer_game_private where game_id = p_game_id for update;
  v_board := v_game.board;

  if p_move_type = 'play' then
    v_new_count := jsonb_array_length(p_placements);
    if v_new_count < 1 or v_new_count > 7 then raise exception 'invalid placement count'; end if;
    for v_item in select value from jsonb_array_elements(p_placements) loop
      v_id := v_item->>'id'; v_row := (v_item->>'row')::integer; v_col := (v_item->>'col')::integer;
      if (select count(*) from jsonb_array_elements(p_placements) p where p->>'id' = v_id) <> 1
         or (select count(*) from jsonb_array_elements(p_placements) p where (p->>'row')::integer = v_row and (p->>'col')::integer = v_col) <> 1 then
        raise exception 'duplicate tile or coordinate';
      end if;
      if v_row not between 0 and 14 or v_col not between 0 and 14 then raise exception 'invalid coordinate'; end if;
      if coalesce(v_board->v_row->v_col->'tile', 'null'::jsonb) <> 'null'::jsonb then raise exception 'occupied square'; end if;
      select x into v_tile from jsonb_array_elements(v_rack) x where x->>'id' = v_id;
      if v_tile is null then raise exception 'tile is not in rack'; end if;
      if upper(coalesce(v_item->>'letter',' ')) <> upper(coalesce(v_tile->>'letter',' '))
        or coalesce((v_item->>'isBlank')::boolean,false) <> coalesce((v_tile->>'isBlank')::boolean,false)
        or (coalesce((v_tile->>'isBlank')::boolean,false) and upper(coalesce(v_item->>'blankLetter','')) !~ '^[A-Z]$') then
        raise exception 'tile attributes do not match rack';
      end if;
      v_min_row := least(v_min_row, v_row); v_max_row := greatest(v_max_row, v_row);
      v_min_col := least(v_min_col, v_col); v_max_col := greatest(v_max_col, v_col);
      v_board := jsonb_set(v_board, array[v_row::text,v_col::text,'tile'], jsonb_build_object(
        'id', v_id, 'letter', upper(coalesce(v_item->>'letter',' ')),
        'scoreValue', case when coalesce((v_item->>'isBlank')::boolean,false) then 0 else coalesce((v_rack->(select i from generate_series(0,jsonb_array_length(v_rack)-1) i where v_rack->i->>'id'=v_id limit 1)->>'scoreValue')::integer,0) end,
        'isBlank', coalesce((v_item->>'isBlank')::boolean,false),
        'blankLetter', nullif(upper(v_item->>'blankLetter'),'')
      ));
    end loop;
    v_horizontal := v_min_row = v_max_row;
    if v_new_count > 1 and not v_horizontal and v_min_col <> v_max_col then raise exception 'tiles must align'; end if;
    if v_new_count > 1 then
      if v_horizontal then
        for v_i in v_min_col..v_max_col loop if public.multiplayer_board_letter(v_board,v_min_row,v_i) = '' then raise exception 'gap in move'; end if; end loop;
      else
        for v_i in v_min_row..v_max_row loop if public.multiplayer_board_letter(v_board,v_i,v_min_col) = '' then raise exception 'gap in move'; end if; end loop;
      end if;
    end if;
    if v_new_count = 1 then
      v_i := v_min_col;
      while v_i > 0 and public.multiplayer_board_letter(v_board,v_min_row,v_i-1) <> '' loop v_i := v_i-1; end loop;
      v_j := v_min_col;
      while v_j < 15 and public.multiplayer_board_letter(v_board,v_min_row,v_j) <> '' loop v_j := v_j+1; end loop;
      if v_j - v_i < 2 then v_horizontal := false; end if;
    end if;
    for v_i in 0..14 loop for v_j in 0..14 loop
        if coalesce(v_game.board->v_i->v_j->'tile', 'null'::jsonb) <> 'null'::jsonb then v_has_locked := true; end if;
    end loop; end loop;
    if not v_has_locked then
      if public.multiplayer_board_letter(v_board,7,7) = '' then raise exception 'first move must cover centre'; end if;
    else
      for v_item in select value from jsonb_array_elements(p_placements) loop
        v_row := (v_item->>'row')::integer; v_col := (v_item->>'col')::integer;
        if (v_row > 0 and coalesce(v_game.board->(v_row-1)->v_col->'tile', 'null'::jsonb) <> 'null'::jsonb)
          or (v_row < 14 and coalesce(v_game.board->(v_row+1)->v_col->'tile', 'null'::jsonb) <> 'null'::jsonb)
          or (v_col > 0 and coalesce(v_game.board->v_row->(v_col-1)->'tile', 'null'::jsonb) <> 'null'::jsonb)
          or (v_col < 14 and coalesce(v_game.board->v_row->(v_col+1)->'tile', 'null'::jsonb) <> 'null'::jsonb) then v_connects := true; end if;
      end loop;
      if not v_connects then raise exception 'move must connect'; end if;
    end if;
    -- Trace the main word from the server board and require dictionary proof.
    if v_horizontal then
      v_i := v_min_col; while v_i > 0 and public.multiplayer_board_letter(v_board,v_min_row,v_i-1) <> '' loop v_i := v_i-1; end loop;
      v_word := ''; v_j := v_i; while v_j < 15 and public.multiplayer_board_letter(v_board,v_min_row,v_j) <> '' loop v_word := v_word || public.multiplayer_board_letter(v_board,v_min_row,v_j); v_j := v_j+1; end loop;
    else
      v_i := v_min_row; while v_i > 0 and public.multiplayer_board_letter(v_board,v_i-1,v_min_col) <> '' loop v_i := v_i-1; end loop;
      v_word := ''; v_j := v_i; while v_j < 15 and public.multiplayer_board_letter(v_board,v_j,v_min_col) <> '' loop v_word := v_word || public.multiplayer_board_letter(v_board,v_j,v_min_col); v_j := v_j+1; end loop;
    end if;
    if length(v_word) < 2 or not public.multiplayer_word_exists(v_word) then raise exception 'word is not in server dictionary'; end if;
    -- Score the complete main word, applying premiums only to newly placed
    -- tiles. Then validate and score every perpendicular cross-word.
    v_word_score := 0; v_word_multiplier := 1;
    for v_count in v_i..v_j-1 loop
      if v_horizontal then v_row := v_min_row; v_col := v_count;
      else v_row := v_count; v_col := v_min_col; end if;
      v_tile := v_board->v_row->v_col->'tile';
      if exists (select 1 from jsonb_array_elements(p_placements) p where (p->>'row')::integer=v_row and (p->>'col')::integer=v_col) then
        v_word_score := v_word_score + coalesce((v_tile->>'scoreValue')::integer,0) * case public.multiplayer_cell_type(v_row,v_col) when 'doubleLetter' then 2 when 'tripleLetter' then 3 else 1 end;
        v_word_multiplier := v_word_multiplier * case public.multiplayer_cell_type(v_row,v_col) when 'doubleWord' then 2 when 'centre' then 2 when 'tripleWord' then 3 else 1 end;
      else
        v_word_score := v_word_score + coalesce((v_tile->>'scoreValue')::integer,0);
      end if;
    end loop;
    v_score := v_word_score * v_word_multiplier;
    for v_item in select value from jsonb_array_elements(p_placements) loop
      v_row := (v_item->>'row')::integer; v_col := (v_item->>'col')::integer;
      if v_horizontal then
        v_cross_start := v_row; while v_cross_start > 0 and public.multiplayer_board_letter(v_board,v_cross_start-1,v_col) <> '' loop v_cross_start := v_cross_start-1; end loop;
        v_cross_end := v_row; while v_cross_end < 14 and public.multiplayer_board_letter(v_board,v_cross_end+1,v_col) <> '' loop v_cross_end := v_cross_end+1; end loop;
      else
        v_cross_start := v_col; while v_cross_start > 0 and public.multiplayer_board_letter(v_board,v_row,v_cross_start-1) <> '' loop v_cross_start := v_cross_start-1; end loop;
        v_cross_end := v_col; while v_cross_end < 14 and public.multiplayer_board_letter(v_board,v_row,v_cross_end+1) <> '' loop v_cross_end := v_cross_end+1; end loop;
      end if;
      if v_cross_end - v_cross_start >= 1 then
        v_cross_word := '';
        for v_count in v_cross_start..v_cross_end loop
          if v_horizontal then v_cross_word := v_cross_word || public.multiplayer_board_letter(v_board,v_count,v_col);
          else v_cross_word := v_cross_word || public.multiplayer_board_letter(v_board,v_row,v_count); end if;
        end loop;
        if not public.multiplayer_word_exists(v_cross_word) then raise exception 'cross word is not in server dictionary'; end if;
        v_cross_score := 0; v_cross_multiplier := 1;
        for v_count in v_cross_start..v_cross_end loop
          if v_horizontal then v_row := v_count; -- column stays fixed
          else v_col := v_count; end if;
          v_tile := v_board->v_row->v_col->'tile';
          v_cross_score := v_cross_score + coalesce((v_tile->>'scoreValue')::integer,0) * case when exists (select 1 from jsonb_array_elements(p_placements) p where (p->>'row')::integer=v_row and (p->>'col')::integer=v_col) then case public.multiplayer_cell_type(v_row,v_col) when 'doubleLetter' then 2 when 'tripleLetter' then 3 else 1 end else 1 end;
          if exists (select 1 from jsonb_array_elements(p_placements) p where (p->>'row')::integer=v_row and (p->>'col')::integer=v_col) then v_cross_multiplier := v_cross_multiplier * case public.multiplayer_cell_type(v_row,v_col) when 'doubleWord' then 2 when 'centre' then 2 when 'tripleWord' then 3 else 1 end; end if;
        end loop;
        v_score := v_score + v_cross_score * v_cross_multiplier;
      end if;
    end loop;
    if v_new_count = 7 then v_score := v_score + 50; end if;
    v_rack := (select coalesce(jsonb_agg(x), '[]'::jsonb) from jsonb_array_elements(v_rack) x where not exists (select 1 from jsonb_array_elements(p_placements) p where p->>'id'=x->>'id'));
    for v_i in 1..least(v_new_count, jsonb_array_length(v_bag)) loop
      v_j := floor(random()*jsonb_array_length(v_bag)); v_tile := v_bag->v_j; v_bag := v_bag-v_j; v_rack := v_rack || jsonb_build_array(v_tile);
    end loop;
  elsif p_move_type = 'exchange' then
    if jsonb_array_length(p_exchange_ids) < 1 or jsonb_array_length(p_exchange_ids) > 7 then raise exception 'exchange requires 1 to 7 tiles'; end if;
    if jsonb_array_length(v_bag) < jsonb_array_length(p_exchange_ids) then raise exception 'not enough tiles to exchange'; end if;
    for v_item in select value from jsonb_array_elements(p_exchange_ids) loop
      if (select count(*) from jsonb_array_elements(p_exchange_ids) p where p #>> '{}' = v_item #>> '{}') <> 1 then raise exception 'duplicate exchange tile'; end if;
      if not exists(select 1 from jsonb_array_elements(v_rack) x where x->>'id'=v_item #>> '{}') then raise exception 'tile is not in rack'; end if;
      v_tile := (select x from jsonb_array_elements(v_rack) x where x->>'id'=v_item #>> '{}');
      v_exchange_tiles := v_exchange_tiles || jsonb_build_array(v_tile);
    end loop;
    v_rack := (select coalesce(jsonb_agg(x), '[]'::jsonb) from jsonb_array_elements(v_rack) x where not exists (select 1 from jsonb_array_elements(p_exchange_ids) p where p #>> '{}' = x->>'id'));
    v_bag := v_bag || v_exchange_tiles;
    for v_i in 1..jsonb_array_length(p_exchange_ids) loop
      v_j := floor(random()*jsonb_array_length(v_bag)); v_tile := v_bag->v_j; v_bag := v_bag-v_j; v_rack := v_rack || jsonb_build_array(v_tile);
    end loop;
  end if;

  v_move_number := v_game.move_number + 1;
  select user_id into v_next_user from public.multiplayer_players where game_id=p_game_id and user_id<>p_user_id limit 1;
  select rack into v_opponent_rack from public.multiplayer_player_private where game_id=p_game_id and user_id=v_next_user;
  v_next_passes := case when p_move_type in ('pass','timeout') then v_game.consecutive_passes+1 else 0 end;
  v_p1_score := case when v_player=1 then v_game.player_one_score+v_score else v_game.player_one_score end;
  v_p2_score := case when v_player=2 then v_game.player_two_score+v_score else v_game.player_two_score end;
  select coalesce(sum((x->>'scoreValue')::integer),0) into v_p1_rack_value
    from jsonb_array_elements(case when v_player=1 then v_rack else v_opponent_rack end) x;
  select coalesce(sum((x->>'scoreValue')::integer),0) into v_p2_rack_value
    from jsonb_array_elements(case when v_player=2 then v_rack else v_opponent_rack end) x;
  if v_next_passes >= 6 or (jsonb_array_length(v_bag)=0 and (jsonb_array_length(v_rack)=0 or jsonb_array_length(v_opponent_rack)=0)) then
    v_status := 'completed';
    if v_next_passes >= 6 then
      v_p1_score := greatest(0, v_p1_score-v_p1_rack_value);
      v_p2_score := greatest(0, v_p2_score-v_p2_rack_value);
    elsif jsonb_array_length(v_rack)=0 then
      if v_player=1 then v_p1_score := v_p1_score+v_p2_rack_value; v_p2_score := greatest(0,v_p2_score-v_p2_rack_value);
      else v_p2_score := v_p2_score+v_p1_rack_value; v_p1_score := greatest(0,v_p1_score-v_p1_rack_value); end if;
    else
      if v_player=2 then v_p2_score := v_p2_score+v_p1_rack_value; v_p1_score := greatest(0,v_p1_score-v_p1_rack_value);
      else v_p1_score := v_p1_score+v_p2_rack_value; v_p2_score := greatest(0,v_p2_score-v_p2_rack_value); end if;
    end if;
    v_winner := case when v_p1_score > v_p2_score then (select user_id from public.multiplayer_players where game_id=p_game_id and player_number=1)
                     when v_p2_score > v_p1_score then (select user_id from public.multiplayer_players where game_id=p_game_id and player_number=2)
                     else null end;
  end if;
  update public.multiplayer_games set board=v_board,
    player_one_score=v_p1_score, player_two_score=v_p2_score,
    consecutive_passes=v_next_passes, move_number=v_move_number,
    current_turn_user_id=case when v_status='active' then v_next_user else null end,
    turn_started_at=case when v_status='active' then now() else null end,
    status=v_status, winner_id=v_winner
  where id=p_game_id;
  update public.multiplayer_player_private set rack=v_rack where game_id=p_game_id and user_id=p_user_id;
  update public.multiplayer_game_private set tile_bag=v_bag where game_id=p_game_id;
  insert into public.multiplayer_moves(game_id,user_id,move_number,move_type,placements,tiles_used,score)
  values(p_game_id,p_user_id,v_move_number,p_move_type,p_placements,coalesce(p_exchange_ids,'[]'::jsonb),v_score);
  v_response := jsonb_build_object('game_id',p_game_id,'move_number',v_move_number,'score',v_score,'status',v_status,'winner_id',v_winner,'next_turn_user_id',case when v_status='active' then v_next_user else null end);
  insert into public.multiplayer_move_requests(game_id,user_id,client_action_id,move_number,response)
  values(p_game_id,p_user_id,p_client_action_id,v_move_number,v_response);
  return v_response;
end;
$$;

revoke all on function public.initialize_multiplayer_game(uuid) from public, anon, authenticated;
revoke all on function public.apply_multiplayer_move(uuid,uuid,text,text,jsonb,jsonb) from public, anon, authenticated;
grant execute on function public.initialize_multiplayer_game(uuid) to service_role;
grant execute on function public.apply_multiplayer_move(uuid,uuid,text,text,jsonb,jsonb) to service_role;

create index if not exists multiplayer_move_requests_created_idx
  on public.multiplayer_move_requests (game_id, created_at desc);
