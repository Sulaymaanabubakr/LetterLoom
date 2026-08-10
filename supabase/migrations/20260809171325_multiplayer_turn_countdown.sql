alter table public.multiplayer_games
  add column if not exists turn_started_at timestamptz;

create index if not exists multiplayer_games_turn_started_idx
  on public.multiplayer_games (turn_started_at)
  where status = 'active';
