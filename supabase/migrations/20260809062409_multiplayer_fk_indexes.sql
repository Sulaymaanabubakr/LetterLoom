create index multiplayer_games_current_turn_user_idx
  on public.multiplayer_games (current_turn_user_id)
  where current_turn_user_id is not null;

create index multiplayer_games_winner_idx
  on public.multiplayer_games (winner_id)
  where winner_id is not null;

create index multiplayer_moves_user_idx
  on public.multiplayer_moves (user_id);

create index multiplayer_player_private_user_idx
  on public.multiplayer_player_private (user_id);
