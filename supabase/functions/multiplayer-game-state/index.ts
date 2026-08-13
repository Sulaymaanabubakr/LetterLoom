import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getAdminClient, getAuthenticatedUser } from '../_shared/supabase.ts';
import { sendPushNotification } from '../_shared/push.ts';
import { addPlayerAvatars } from '../_shared/multiplayer_players.ts';

const gameFields = 'id, room_code, status, current_turn_user_id, turn_started_at, paused_at, paused_by_user_id, created_by_user_id, board, player_one_score, player_two_score, player_scores, winner_ids, max_players, consecutive_passes, move_number, winner_id, created_at, updated_at, mode';

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
    const action = String(body.action ?? 'get');
    if (!gameId || !['get', 'initialize', 'move', 'timeout', 'pause', 'resume'].includes(action)) {
      return response({ error: 'A valid room and action are required.' }, 400);
    }

    const admin = getAdminClient();
    const { data: membership, error: membershipError } = await admin
      .from('multiplayer_players')
      .select('player_number, user_id')
      .eq('game_id', gameId)
      .eq('user_id', user.id)
      .maybeSingle();
    if (membershipError) throw membershipError;
    if (!membership) return response({ error: 'You are not a player in this room.' }, 403);

    if (action === 'initialize') {
      const { error: initializeError } = await admin.rpc('initialize_multiplayer_game', {
        p_game_id: gameId,
      });
      if (initializeError) return response({ error: initializeError.message }, 409);
    }

    if (action === 'pause' || action === 'resume') {
      const { data: pauseState, error: pauseError } = await admin.rpc(
        action === 'pause' ? 'pause_multiplayer_game' : 'resume_multiplayer_game',
        { p_game_id: gameId, p_user_id: user.id },
      );
      if (pauseError) return response({ error: pauseError.message }, 409);
      return response({ pause: pauseState });
    }

    if (action === 'move') {
      const clientActionId = String(body.client_action_id ?? '').trim();
      const moveType = String(body.move_type ?? '');
      const placements = Array.isArray(body.placements) ? body.placements : [];
      const exchangeIds = Array.isArray(body.exchange_ids) ? body.exchange_ids : [];
      if (!clientActionId || !['play', 'pass', 'exchange'].includes(moveType)) {
        return response({ error: 'A move type and idempotency key are required.' }, 400);
      }
      const { data: moveResponse, error: moveError } = await admin.rpc(
        'apply_multiplayer_move',
        {
          p_game_id: gameId,
          p_user_id: user.id,
          p_client_action_id: clientActionId,
          p_move_type: moveType,
          p_placements: placements,
          p_exchange_ids: exchangeIds,
        },
      );
      if (moveError) {
        const status = moveError.message.includes('not your turn') ||
          moveError.message.includes('turn expired') ? 409 : 400;
        return response({ error: moveError.message }, status);
      }
      const status = (moveResponse as Record<string, unknown>).status as string | undefined;
      const { data: turnState } = await admin.from('multiplayer_games').select('current_turn_user_id').eq('id', gameId).maybeSingle();
      const nextTurnUserId = turnState?.current_turn_user_id as string | null | undefined;
      if (status === 'active' && nextTurnUserId && nextTurnUserId !== user.id) {
        await sendPushNotification(
          [nextTurnUserId],
          'Your turn',
          'Your opponent made a move in LetterLoom.',
          { game_id: gameId, event: 'your_turn' },
          'multiplayer_turns',
        );
      }
      return response({ move: moveResponse });
    }

    const { data: game, error: gameError } = await admin
      .from('multiplayer_games')
      .select(gameFields)
      .eq('id', gameId)
      .maybeSingle();
    if (gameError) throw gameError;
    if (!game) return response({ error: 'Room not found.' }, 404);

    if (action === 'timeout') {
      if (game.status !== 'active') return response({ error: 'This room is not active.' }, 409);
      if (game.paused_at) return response({ error: 'The match is paused.' }, 409);
      if (!game.turn_started_at) return response({ error: 'This turn has no countdown.' }, 409);
      if (Date.now() < Date.parse(game.turn_started_at) + 120_000) {
        return response({ error: 'The turn countdown has not expired.' }, 409);
      }
      const timedOutUserId = game.current_turn_user_id as string;
      const timeoutActionId = `timeout_${gameId}_${game.turn_started_at}`;
      const { error: timeoutError } = await admin.rpc('apply_multiplayer_move', {
        p_game_id: gameId,
        p_user_id: timedOutUserId,
        p_client_action_id: timeoutActionId,
        p_move_type: 'timeout',
        p_placements: [],
        p_exchange_ids: [],
      });
      if (timeoutError) {
        return response({ error: timeoutError.message }, 409);
      }
    }

    const { data: currentGame, error: currentGameError } = await admin
      .from('multiplayer_games')
      .select(gameFields)
      .eq('id', gameId)
      .single();
    if (currentGameError) throw currentGameError;
    const { data: privateRack, error: rackError } = await admin
      .from('multiplayer_player_private')
      .select('rack')
      .eq('game_id', gameId)
      .eq('user_id', user.id)
      .maybeSingle();
    if (rackError) throw rackError;
    const { data: privateGame, error: bagError } = await admin
      .from('multiplayer_game_private')
      .select('tile_bag')
      .eq('game_id', gameId)
      .maybeSingle();
    if (bagError) throw bagError;
    const { data: roomPlayers, error: roomPlayersError } = await admin
      .from('multiplayer_players')
      .select('user_id, player_number, display_name, connection_status, mic_enabled')
      .eq('game_id', gameId)
      .order('player_number');
    if (roomPlayersError) throw roomPlayersError;

    if (action === 'timeout' && currentGame.current_turn_user_id) {
      await sendPushNotification(
        [currentGame.current_turn_user_id],
        'Your turn',
        'Your opponent ran out of time in LetterLoom.',
        { game_id: gameId, event: 'turn_timeout' },
      );
    }

    const players = await addPlayerAvatars(admin, (roomPlayers ?? []) as Array<Record<string, unknown>>);
    return response({
      game: currentGame,
      rack: privateRack?.rack ?? [],
      // The bag belongs to the server. Clients need the remaining count for
      // UI affordances, never the identities or ordering of undistributed
      // tiles.
      tile_count: Array.isArray(privateGame?.tile_bag)
        ? privateGame.tile_bag.length
        : 0,
      players,
    });
  } catch (error) {
    console.error('multiplayer-game-state error', error);
    return response({ error: error instanceof Error ? error.message : 'Unable to load multiplayer state.' }, 400);
  }
});
