import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getAdminClient, getAuthenticatedUser } from '../_shared/supabase.ts';
import { sendPushNotification } from '../_shared/push.ts';

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
    const roomCode = String(body.room_code ?? '').trim().toUpperCase();
    const displayName = String(body.display_name ?? '').trim().slice(0, 40);
    if (!/^[A-Z2-9]{6}$/.test(roomCode)) return response({ error: 'Enter the six-character room code.' }, 400);
    if (displayName.length < 1) return response({ error: 'Enter a display name.' }, 400);

    const admin = getAdminClient();
    const { data: game, error: gameError } = await admin
      .from('multiplayer_games')
      .select('id, room_code, status, current_turn_user_id, created_by_user_id, board, player_one_score, player_two_score, consecutive_passes, move_number, winner_id, created_at, updated_at')
      .eq('room_code', roomCode)
      .eq('status', 'waiting')
      .maybeSingle();

    if (gameError) throw gameError;
    if (!game) return response({ error: 'That room is unavailable or already full.' }, 404);

    const { data: existingPlayer, error: existingPlayerError } = await admin
      .from('multiplayer_players')
      .select('user_id')
      .eq('game_id', game.id)
      .eq('user_id', user.id)
      .maybeSingle();
    if (existingPlayerError) throw existingPlayerError;
    if (existingPlayer) return response({ error: 'You are already in this room.' }, 409);

    const playerInsert = await admin.from('multiplayer_players').insert({
      game_id: game.id,
      user_id: user.id,
      player_number: 2,
      display_name: displayName,
    });
    if (playerInsert.error) {
      if (playerInsert.error.code === '23505') return response({ error: 'That room is already full.' }, 409);
      throw playerInsert.error;
    }

    const privateInsert = await admin.from('multiplayer_player_private').insert({
      game_id: game.id,
      user_id: user.id,
      rack: [],
    });
    if (privateInsert.error) throw privateInsert.error;

    const { data: activeGame, error: updateError } = await admin
      .from('multiplayer_games')
      .update({ status: 'active' })
      .eq('id', game.id)
      .eq('status', 'waiting')
      .select('id, room_code, status, current_turn_user_id, created_by_user_id, board, player_one_score, player_two_score, consecutive_passes, move_number, winner_id, created_at, updated_at')
      .single();

    if (updateError) throw updateError;
    const { error: initializeError } = await admin.rpc('initialize_multiplayer_game', {
      p_game_id: game.id,
    });
    if (initializeError) throw initializeError;
    await sendPushNotification(
      [game.created_by_user_id as string],
      'Opponent joined',
      'Your LetterLoom room is ready to play.',
      { game_id: game.id as string, event: 'opponent_joined' },
    );
    return response({ game: { ...activeGame, is_owner: false } });
  } catch (error) {
    console.error('join-multiplayer-game error', error);
    return response({ error: error instanceof Error ? error.message : 'Unable to join game.' }, 400);
  }
});
