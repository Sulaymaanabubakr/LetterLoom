-- Ranked matchmaking is server-owned. Clients may ask to join/cancel/status;
-- they cannot create queue rows, games, or rating results directly.

alter table public.multiplayer_games
  add column if not exists mode text not null default 'casual'
    check (mode in ('casual', 'ranked'));

alter table public.ranked_matches
  add column if not exists game_id uuid unique references public.multiplayer_games(id) on delete cascade;

create table public.ranked_queue (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null unique references auth.users(id) on delete cascade,
  rating integer not null check (rating >= 100),
  display_name text not null check (char_length(trim(display_name)) between 1 and 40),
  status text not null default 'waiting' check (status in ('waiting', 'matching', 'matched', 'cancelled')),
  game_id uuid references public.multiplayer_games(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create index ranked_queue_waiting_idx on public.ranked_queue(status, rating, created_at);
alter table public.ranked_queue enable row level security;
create policy "players can view their ranked queue entry"
  on public.ranked_queue for select to authenticated
  using ((select auth.uid()) = user_id);
revoke insert, update, delete on public.ranked_queue from anon, authenticated;

create or replace function public.claim_ranked_opponent(p_user_id uuid)
returns table(opponent_user_id uuid, opponent_rating integer, opponent_display_name text)
language plpgsql security definer set search_path = public
as $$
declare
  v_rating integer;
  v_opponent ranked_queue%rowtype;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then
    raise exception 'service role required';
  end if;
  select rating into v_rating from ranked_queue
    where user_id = p_user_id and status = 'waiting' for update;
  if v_rating is null then return; end if;

  select * into v_opponent from ranked_queue q
    where q.status = 'waiting' and q.user_id <> p_user_id
      and abs(q.rating - v_rating) <= 200
    order by abs(q.rating - v_rating), q.created_at
    limit 1 for update skip locked;
  if not found then return; end if;

  update ranked_queue set status = 'matching', updated_at = now()
    where user_id in (p_user_id, v_opponent.user_id);
  return query select v_opponent.user_id, v_opponent.rating, v_opponent.display_name;
end;
$$;

create or replace function public.settle_ranked_match(p_game_id uuid)
returns jsonb
language plpgsql security definer set search_path = public
as $$
declare
  g multiplayer_games%rowtype;
  p1 uuid; p2 uuid; r1 integer; r2 integer; d1 integer; d2 integer;
  score1 numeric; expected1 numeric; new1 integer; new2 integer;
  winner uuid;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then raise exception 'service role required'; end if;
  select * into g from multiplayer_games where id = p_game_id for update;
  if not found or g.mode <> 'ranked' or g.status <> 'completed' then
    raise exception 'ranked game is not completed';
  end if;
  if exists (select 1 from ranked_matches where game_id = p_game_id) then
    return jsonb_build_object('settled', false, 'game_id', p_game_id);
  end if;
  select user_id into p1 from multiplayer_players where game_id = p_game_id and player_number = 1;
  select user_id into p2 from multiplayer_players where game_id = p_game_id and player_number = 2;
  select ranked_rating into r1 from player_profiles where id = p1 for update;
  select ranked_rating into r2 from player_profiles where id = p2 for update;
  score1 := case when g.winner_id = p1 then 1 when g.winner_id = p2 then 0 else 0.5 end;
  expected1 := 1.0 / (1.0 + power(10.0, (r2-r1)/400.0));
  d1 := round(32 * (score1 - expected1));
  d2 := -d1;
  new1 := greatest(100, r1 + d1); new2 := greatest(100, r2 + d2);
  winner := g.winner_id;
  update player_profiles set ranked_rating = new1, ranked_tier = case when new1 >= 1800 then 'Gold I' when new1 >= 1500 then 'Silver I' else 'Bronze III' end,
    games_played = games_played + 1, wins = wins + case when winner = p1 then 1 else 0 end,
    losses = losses + case when winner = p2 then 1 else 0 end, draws = draws + case when winner is null then 1 else 0 end
    where id = p1;
  update player_profiles set ranked_rating = new2, ranked_tier = case when new2 >= 1800 then 'Gold I' when new2 >= 1500 then 'Silver I' else 'Bronze III' end,
    games_played = games_played + 1, wins = wins + case when winner = p2 then 1 else 0 end,
    losses = losses + case when winner = p1 then 1 else 0 end, draws = draws + case when winner is null then 1 else 0 end
    where id = p2;
  insert into ranked_matches(game_id, player_one_id, player_two_id, winner_id, rating_delta_p1, rating_delta_p2)
    values (p_game_id, p1, p2, winner, d1, d2);
  update ranked_queue set status = 'matched', game_id = p_game_id, updated_at = now() where user_id in (p1,p2);
  return jsonb_build_object('settled', true, 'game_id', p_game_id, 'winner_id', winner, 'delta_p1', d1, 'delta_p2', d2);
end;
$$;
