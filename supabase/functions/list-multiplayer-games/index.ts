import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getAdminClient, getAuthenticatedUser } from '../_shared/supabase.ts';

const gameFields = 'id, room_code, status, current_turn_user_id, created_by_user_id, board, player_one_score, player_two_score, player_scores, winner_ids, max_players, consecutive_passes, move_number, winner_id, created_at, updated_at';

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function addPlayerCounts(games: Record<string, unknown>[], players: Record<string, unknown>[], userId: string) {
  return games.map((game) => {
    const gamePlayers = players.filter((player) => player.game_id === game.id);
    return {
      ...game,
      player_count: gamePlayers.length,
      is_owner: gamePlayers.some(
        (player) => player.player_number === 1 && player.user_id === userId,
      ),
    };
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return response({ error: 'POST is required.' }, 405);

  try {
    const user = await getAuthenticatedUser(req);
    const admin = getAdminClient();
    const { data: memberships, error: membershipError } = await admin
      .from('multiplayer_players')
      .select('game_id')
      .eq('user_id', user.id);
    if (membershipError) throw membershipError;

    const ownedGameIds = (memberships ?? []).map((row) => row.game_id as string);
    let myGames: Record<string, unknown>[] = [];
    if (ownedGameIds.length > 0) {
      const { data, error } = await admin
        .from('multiplayer_games')
        .select(gameFields)
        .in('id', ownedGameIds)
        .in('status', ['waiting', 'active'])
        .order('updated_at', { ascending: false });
      if (error) throw error;
      myGames = (data ?? []) as Record<string, unknown>[];
    }

    const allIds = myGames.map((game) => game.id as string);
    let players: Record<string, unknown>[] = [];
    if (allIds.length > 0) {
      const { data, error } = await admin
        .from('multiplayer_players')
      .select('game_id, user_id, player_number, display_name, connection_status, mic_enabled')
        .in('game_id', allIds);
      if (error) throw error;
      players = (data ?? []) as Record<string, unknown>[];
    }

    return response({
      my_games: addPlayerCounts(myGames, players, user.id).map((game) => ({
        ...game,
        players: players.filter((player) => player.game_id === game.id),
      })),
      available_games: [],
    });
  } catch (error) {
    console.error('list-multiplayer-games error', error);
    return response({ error: error instanceof Error ? error.message : 'Unable to load rooms.' }, 400);
  }
});
