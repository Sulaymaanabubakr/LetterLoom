import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getAdminClient, getAuthenticatedUser } from '../_shared/supabase.ts';
import { sendPushNotification } from '../_shared/push.ts';

const gameFields = 'id, room_code, status, current_turn_user_id, created_by_user_id, board, player_one_score, player_two_score, consecutive_passes, move_number, winner_id, created_at, updated_at';

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
    if (!gameId || !['get', 'initialize', 'restart', 'sync'].includes(action)) {
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

    const { data: game, error: gameError } = await admin
      .from('multiplayer_games')
      .select(gameFields)
      .eq('id', gameId)
      .maybeSingle();
    if (gameError) throw gameError;
    if (!game) return response({ error: 'Room not found.' }, 404);

    if (action === 'initialize' || action === 'restart') {
      if (membership.player_number !== 1) return response({ error: 'Only the room owner can initialize the board.' }, 403);
      if (game.status !== 'active') return response({ error: 'Both players must join before starting the board.' }, 409);
      if (action === 'initialize' && Array.isArray(game.board) && game.board.length > 0) return response({ game }, 200);

      const state = body.state;
      if (!state || !Array.isArray(state.board) || !Array.isArray(state.tileBag)) {
        return response({ error: 'Initial board state is required.' }, 400);
      }
      const { data: players, error: playersError } = await admin
        .from('multiplayer_players')
        .select('user_id, player_number')
        .eq('game_id', gameId);
      if (playersError) throw playersError;
      const playerTwo = (players ?? []).find((player) => player.player_number === 2);
      if (!playerTwo) return response({ error: 'The second player has not joined.' }, 409);

      const { error: updateError } = await admin.from('multiplayer_games').update({
        board: state.board,
        player_one_score: state.playerScore ?? 0,
        player_two_score: state.computerScore ?? 0,
        consecutive_passes: state.consecutivePasses ?? 0,
        move_number: 0,
        current_turn_user_id: user.id,
      }).eq('id', gameId);
      if (updateError) throw updateError;
      const { error: bagError } = await admin.from('multiplayer_game_private').upsert({
        game_id: gameId,
        tile_bag: state.tileBag,
      });
      if (bagError) throw bagError;
      const { error: ownerRackError } = await admin.from('multiplayer_player_private').upsert({
        game_id: gameId,
        user_id: user.id,
        rack: state.playerRack ?? [],
      });
      if (ownerRackError) throw ownerRackError;
      const { error: playerTwoRackError } = await admin.from('multiplayer_player_private').upsert({
        game_id: gameId,
        user_id: playerTwo.user_id,
        rack: state.computerRack ?? [],
      });
      if (playerTwoRackError) throw playerTwoRackError;
    }

    if (action === 'sync') {
      if (game.status !== 'active') return response({ error: 'This room is not active.' }, 409);
      if (game.current_turn_user_id !== user.id) return response({ error: 'It is not your turn.' }, 409);
      const state = body.state;
      const nextTurnUserId = String(body.next_turn_user_id ?? '');
      if (!state || !Array.isArray(state.board) || !nextTurnUserId) {
        return response({ error: 'A complete move state is required.' }, 400);
      }
      const playerOneScore = membership.player_number === 1
        ? (state.playerScore ?? game.player_one_score)
        : (state.computerScore ?? game.player_one_score);
      const playerTwoScore = membership.player_number === 1
        ? (state.computerScore ?? game.player_two_score)
        : (state.playerScore ?? game.player_two_score);
      const { error: updateError } = await admin.from('multiplayer_games').update({
        board: state.board,
        player_one_score: playerOneScore,
        player_two_score: playerTwoScore,
        consecutive_passes: state.consecutivePasses ?? game.consecutive_passes,
        move_number: state.moveNumber ?? game.move_number + 1,
        current_turn_user_id: nextTurnUserId,
      }).eq('id', gameId).eq('current_turn_user_id', user.id);
      if (updateError) throw updateError;
      const { error: rackUpdateError } = await admin.from('multiplayer_player_private').upsert({
        game_id: gameId,
        user_id: user.id,
        rack: state.playerRack ?? [],
      });
      if (rackUpdateError) throw rackUpdateError;
      const { error: bagUpdateError } = await admin.from('multiplayer_game_private').upsert({
        game_id: gameId,
        tile_bag: state.tileBag ?? [],
      });
      if (bagUpdateError) throw bagUpdateError;
      await sendPushNotification(
        [nextTurnUserId],
        'Your turn',
        'Your opponent made a move in LetterLoom.',
        { game_id: gameId, event: 'turn' },
      );
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
      .select('user_id, player_number, display_name')
      .eq('game_id', gameId)
      .order('player_number');
    if (roomPlayersError) throw roomPlayersError;

    return response({
      game: currentGame,
      rack: privateRack?.rack ?? [],
      tile_bag: privateGame?.tile_bag ?? [],
      players: roomPlayers ?? [],
    });
  } catch (error) {
    console.error('multiplayer-game-state error', error);
    return response({ error: error instanceof Error ? error.message : 'Unable to load multiplayer state.' }, 400);
  }
});
