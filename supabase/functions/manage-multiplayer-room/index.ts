import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getAdminClient, getAuthenticatedUser } from '../_shared/supabase.ts';

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return response({ error: 'POST is required.' }, 405);

  try {
    const user = await getAuthenticatedUser(req);
    const body = await req.json().catch(() => ({}));
    const gameId = String(body.game_id ?? '');
    const action = String(body.action ?? '');
    if (!gameId || !['stop', 'delete', 'leave'].includes(action)) {
      return response({ error: 'A valid room and action are required.' }, 400);
    }

    const admin = getAdminClient();
    const { data: player, error: playerError } = await admin
      .from('multiplayer_players')
      .select('player_number')
      .eq('game_id', gameId)
      .eq('user_id', user.id)
      .maybeSingle();
    if (playerError) throw playerError;
    if (!player) return response({ error: 'You are not a player in this room.' }, 403);
    if (action !== 'leave' && player.player_number !== 1) {
      return response({ error: 'Only the room owner can manage this room.' }, 403);
    }

    const { data: game, error: gameError } = await admin
      .from('multiplayer_games')
      .select('status')
      .eq('id', gameId)
      .maybeSingle();
    if (gameError) throw gameError;
    if (!game) return response({ error: 'Room not found.' }, 404);

    if (action === 'leave') {
      await admin.from('multiplayer_player_private').delete()
        .eq('game_id', gameId).eq('user_id', user.id);
      const { error: leaveError } = await admin.from('multiplayer_players').delete()
        .eq('game_id', gameId).eq('user_id', user.id);
      if (leaveError) throw leaveError;
      const { data: owner, error: ownerError } = await admin
        .from('multiplayer_players')
        .select('user_id')
        .eq('game_id', gameId)
        .eq('player_number', 1)
        .maybeSingle();
      if (ownerError) throw ownerError;
      const { error: reopenError } = await admin.from('multiplayer_games')
        .update({
          status: 'waiting',
          current_turn_user_id: owner?.user_id ?? null,
        })
        .eq('id', gameId)
        .eq('status', 'active');
      if (reopenError) throw reopenError;
      return response({ left: true });
    }

    if (action === 'delete') {
      if (game.status === 'active') return response({ error: 'Stop the active room before deleting it.' }, 409);
      const { error } = await admin.from('multiplayer_games').delete().eq('id', gameId);
      if (error) throw error;
      return response({ deleted: true });
    }

    const { data: stopped, error: stopError } = await admin
      .from('multiplayer_games')
      .update({ status: 'abandoned' })
      .eq('id', gameId)
      .in('status', ['waiting', 'active'])
      .select('id, room_code, status, current_turn_user_id, created_by_user_id, board, player_one_score, player_two_score, consecutive_passes, move_number, winner_id, created_at, updated_at')
      .single();
    if (stopError) throw stopError;
    return response({ game: stopped });
  } catch (error) {
    console.error('manage-multiplayer-room error', error);
    return response({ error: error instanceof Error ? error.message : 'Unable to manage room.' }, 400);
  }
});
