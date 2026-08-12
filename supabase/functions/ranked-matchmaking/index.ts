import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getAdminClient, getAuthenticatedUser } from '../_shared/supabase.ts';
import { sendPushNotification } from '../_shared/push.ts';

const fields = 'id, room_code, status, current_turn_user_id, created_by_user_id, board, player_one_score, player_two_score, consecutive_passes, move_number, winner_id, created_at, updated_at, mode';
const alphabet = 'ABCDEFGHJKLMNPQRSTUVWXYZ23456789';
const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
const roomCode = () => Array.from({ length: 6 }, () => alphabet[Math.floor(Math.random() * alphabet.length)]).join('');

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return response({ error: 'POST is required.' }, 405);
  try {
    const user = await getAuthenticatedUser(req);
    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? 'status');
    if (!['join', 'cancel', 'status'].includes(action)) return response({ error: 'Invalid ranked action.' }, 400);
    const admin = getAdminClient();
    await admin.from('ranked_queue').update({ status: 'cancelled', updated_at: new Date().toISOString() })
      .eq('user_id', user.id).in('status', ['waiting', 'matching'])
      .lt('expires_at', new Date().toISOString());
    if (action === 'cancel') {
      await admin.from('ranked_queue').update({ status: 'cancelled', updated_at: new Date().toISOString() }).eq('user_id', user.id).in('status', ['waiting', 'matching']);
      return response({ status: 'cancelled' });
    }
    if (action === 'join') {
      const name = String(body.display_name ?? 'Player').trim().slice(0, 40) || 'Player';
      const { data: profile, error: profileError } = await admin.from('player_profiles').select('ranked_rating').eq('id', user.id).maybeSingle();
      if (profileError) throw profileError;
      const expiresAt = new Date(Date.now() + 90_000).toISOString();
      const { error: queueError } = await admin.from('ranked_queue').upsert({ user_id: user.id, rating: profile?.ranked_rating ?? 1200, display_name: name, status: 'waiting', game_id: null, expires_at: expiresAt, updated_at: new Date().toISOString() }, { onConflict: 'user_id' });
      if (queueError) throw queueError;
      const { data: opponent, error: claimError } = await admin.rpc('claim_ranked_opponent', { p_user_id: user.id });
      if (claimError) throw claimError;
      if (Array.isArray(opponent) && opponent.length > 0) {
        const other = opponent[0];
        let game: Record<string, unknown> | null = null;
        for (let attempt = 0; attempt < 5 && !game; attempt++) {
          const { data, error } = await admin.from('multiplayer_games').insert({ room_code: roomCode(), created_by_user_id: user.id, current_turn_user_id: user.id, status: 'active', mode: 'ranked' }).select(fields).single();
          if (!error) game = data;
          else if (!error.message.toLowerCase().includes('duplicate')) throw error;
        }
        if (!game) return response({ error: 'Could not create the ranked match.' }, 503);
        const players = [
          { game_id: game.id, user_id: user.id, player_number: 1, display_name: name },
          { game_id: game.id, user_id: other.opponent_user_id, player_number: 2, display_name: other.opponent_display_name },
        ];
        const { error: playersError } = await admin.from('multiplayer_players').insert(players);
        if (playersError) throw playersError;
        const { error: privateError } = await admin.from('multiplayer_player_private').insert(players.map((p) => ({ game_id: p.game_id, user_id: p.user_id, rack: [] })));
        if (privateError) throw privateError;
        const { error: bagError } = await admin.from('multiplayer_game_private').insert({ game_id: game.id, tile_bag: [] });
        if (bagError) throw bagError;
        const { error: initError } = await admin.rpc('initialize_multiplayer_game', { p_game_id: game.id });
        if (initError) throw initError;
        await admin.from('ranked_queue').update({ status: 'matched', game_id: game.id, updated_at: new Date().toISOString() }).in('user_id', [user.id, other.opponent_user_id]);
        await sendPushNotification(
          [other.opponent_user_id],
          'Competitive Duel ready',
          'Your ranked LetterLoom match is ready to play.',
          { game_id: game.id as string, event: 'ranked_match_ready' },
          'ranked_matches',
        );
        return response({ status: 'matched', game });
      }
    }
    const { data: entry, error: entryError } = await admin.from('ranked_queue').select('status, game_id, expires_at').eq('user_id', user.id).maybeSingle();
    if (entryError) throw entryError;
    if (entry?.status === 'cancelled' && entry?.expires_at && Date.parse(entry.expires_at) <= Date.now()) {
      return response({ status: 'expired' });
    }
    if (entry?.game_id) {
      const { data: game, error: gameError } = await admin.from('multiplayer_games').select(fields).eq('id', entry.game_id).single();
      if (gameError) throw gameError;
      return response({ status: 'matched', game });
    }
    return response({ status: entry?.status ?? 'waiting' });
  } catch (error) {
    console.error('ranked-matchmaking error', error);
    return response({ error: error instanceof Error ? error.message : 'Unable to start ranked matchmaking.' }, 400);
  }
});
