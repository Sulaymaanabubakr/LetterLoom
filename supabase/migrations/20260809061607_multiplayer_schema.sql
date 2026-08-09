-- Multiplayer foundation for LetterLoom.
-- Authoritative game mutations will be added through a protected Edge Function.

create table public.multiplayer_games (
  id uuid primary key default gen_random_uuid(),
  room_code text not null unique,
  status text not null default 'waiting'
    check (status in ('waiting', 'active', 'completed', 'abandoned')),
  current_turn_user_id uuid references auth.users(id) on delete set null,
  board jsonb not null default '[]'::jsonb,
  player_one_score integer not null default 0 check (player_one_score >= 0),
  player_two_score integer not null default 0 check (player_two_score >= 0),
  consecutive_passes integer not null default 0 check (consecutive_passes >= 0),
  move_number integer not null default 0 check (move_number >= 0),
  winner_id uuid references auth.users(id) on delete set null,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  expires_at timestamptz
);

create table public.multiplayer_players (
  game_id uuid not null references public.multiplayer_games(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  player_number smallint not null check (player_number in (1, 2)),
  display_name text not null check (char_length(trim(display_name)) between 1 and 40),
  joined_at timestamptz not null default now(),
  last_seen_at timestamptz not null default now(),
  primary key (game_id, user_id),
  unique (game_id, player_number)
);

-- Private data is kept separate so an opponent's rack and the tile bag cannot
-- be exposed by a realtime subscription to the public game state.
create table public.multiplayer_game_private (
  game_id uuid primary key references public.multiplayer_games(id) on delete cascade,
  tile_bag jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now()
);

create table public.multiplayer_player_private (
  game_id uuid not null references public.multiplayer_games(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  rack jsonb not null default '[]'::jsonb,
  updated_at timestamptz not null default now(),
  primary key (game_id, user_id)
);

create table public.multiplayer_moves (
  id uuid primary key default gen_random_uuid(),
  game_id uuid not null references public.multiplayer_games(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  move_number integer not null check (move_number > 0),
  move_type text not null check (move_type in ('play', 'pass', 'exchange')),
  placements jsonb not null default '[]'::jsonb,
  tiles_used jsonb not null default '[]'::jsonb,
  score integer not null default 0 check (score >= 0),
  created_at timestamptz not null default now(),
  unique (game_id, move_number)
);

create index multiplayer_games_status_created_idx
  on public.multiplayer_games (status, created_at desc);
create index multiplayer_players_user_idx
  on public.multiplayer_players (user_id, last_seen_at desc);
create index multiplayer_moves_game_idx
  on public.multiplayer_moves (game_id, move_number);

create or replace function public.set_multiplayer_updated_at()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger multiplayer_games_updated_at
before update on public.multiplayer_games
for each row execute function public.set_multiplayer_updated_at();

create trigger multiplayer_game_private_updated_at
before update on public.multiplayer_game_private
for each row execute function public.set_multiplayer_updated_at();

create trigger multiplayer_player_private_updated_at
before update on public.multiplayer_player_private
for each row execute function public.set_multiplayer_updated_at();

alter table public.multiplayer_games enable row level security;
alter table public.multiplayer_players enable row level security;
alter table public.multiplayer_game_private enable row level security;
alter table public.multiplayer_player_private enable row level security;
alter table public.multiplayer_moves enable row level security;

-- Public game state is readable only by authenticated participants.
create policy "participants can read multiplayer games"
on public.multiplayer_games
for select
to authenticated
using (
  exists (
    select 1
    from public.multiplayer_players p
    where p.game_id = multiplayer_games.id
      and p.user_id = (select auth.uid())
  )
);

create policy "participants can read multiplayer players"
on public.multiplayer_players
for select
to authenticated
using (
  exists (
    select 1
    from public.multiplayer_players participant
    where participant.game_id = multiplayer_players.game_id
      and participant.user_id = (select auth.uid())
  )
);

create policy "players can read their own rack"
on public.multiplayer_player_private
for select
to authenticated
using ((select auth.uid()) = user_id);

create policy "participants can read move history"
on public.multiplayer_moves
for select
to authenticated
using (
  exists (
    select 1
    from public.multiplayer_players p
    where p.game_id = multiplayer_moves.game_id
      and p.user_id = (select auth.uid())
  )
);

-- No client INSERT/UPDATE/DELETE policies are granted for authoritative game
-- data. The protected Edge Function will perform validated mutations with the
-- server role after checking the caller's authenticated user ID.

alter publication supabase_realtime add table
  public.multiplayer_games,
  public.multiplayer_players,
  public.multiplayer_moves;
