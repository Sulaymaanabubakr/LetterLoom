import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getAdminClient, getAuthenticatedUser } from '../_shared/supabase.ts';
import { addPlayerAvatars } from '../_shared/multiplayer_players.ts';

const roomAlphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';

function createRoomCode(): string {
  return Array.from({ length: 6 }, () =>
    roomAlphabet[Math.floor(Math.random() * roomAlphabet.length)]
  ).join('');
}

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
    const displayName = String(body.display_name ?? '').trim().slice(0, 40);
    const requestedMaxPlayers = Number(body.max_players ?? 2);
    const maxPlayers = Number.isFinite(requestedMaxPlayers) ? Math.min(4, Math.max(2, Math.floor(requestedMaxPlayers))) : 2;
    if (displayName.length < 1) return response({ error: 'Enter a display name.' }, 400);

    const admin = getAdminClient();
    let game: Record<string, unknown> | null = null;

    for (let attempt = 0; attempt < 5 && !game; attempt += 1) {
      const roomCode = createRoomCode();
      const { data, error } = await admin
        .from('multiplayer_games')
        .insert({
          room_code: roomCode,
          created_by_user_id: user.id,
          current_turn_user_id: user.id,
          max_players: maxPlayers,
          status: 'waiting',
        })
        .select('id, room_code, status, current_turn_user_id, board, player_one_score, player_two_score, player_scores, winner_ids, max_players, consecutive_passes, move_number, winner_id, created_at, updated_at')
        .single();

      if (!error) {
        game = data;
      } else if (!error.message.toLowerCase().includes('duplicate')) {
        throw error;
      }
    }

    if (!game) return response({ error: 'Could not create a room. Try again.' }, 503);

    const playerInsert = await admin.from('multiplayer_players').insert({
      game_id: game.id,
      user_id: user.id,
      player_number: 1,
      display_name: displayName,
    });
    if (playerInsert.error) throw playerInsert.error;

    const privateInsert = await admin.from('multiplayer_player_private').insert({
      game_id: game.id,
      user_id: user.id,
      rack: [],
    });
    if (privateInsert.error) throw privateInsert.error;

    const bagInsert = await admin.from('multiplayer_game_private').insert({
      game_id: game.id,
      tile_bag: [],
    });
    if (bagInsert.error) throw bagInsert.error;

    const players = await addPlayerAvatars(admin, [{ user_id: user.id, player_number: 1, display_name: displayName, connection_status: 'connected', mic_enabled: false }]);
    return response({ game: { ...game, is_owner: true, player_count: 1, players } });
  } catch (error) {
    console.error('create-multiplayer-game error', error);
    return response({ error: error instanceof Error ? error.message : 'Unable to create game.' }, 400);
  }
});
