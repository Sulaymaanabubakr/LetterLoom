alter table public.multiplayer_games
  add column created_by_user_id uuid references auth.users(id) on delete set null;

update public.multiplayer_games g
set created_by_user_id = p.user_id
from public.multiplayer_players p
where p.game_id = g.id
  and p.player_number = 1
  and g.created_by_user_id is null;

create index multiplayer_games_created_by_idx
  on public.multiplayer_games (created_by_user_id, updated_at desc);
