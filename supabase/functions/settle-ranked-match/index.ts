import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getAdminClient, getAuthenticatedUser } from '../_shared/supabase.ts';
import { sendPushNotification } from '../_shared/push.ts';

const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  try {
    const user = await getAuthenticatedUser(req);
    const { game_id: gameId } = await req.json().catch(() => ({}));
    if (!gameId) return response({ error: 'game_id is required.' }, 400);
    const admin = getAdminClient();
    const { data: member, error: memberError } = await admin.from('multiplayer_players').select('user_id').eq('game_id', gameId).eq('user_id', user.id).maybeSingle();
    if (memberError) throw memberError;
    if (!member) return response({ error: 'You are not a player in this match.' }, 403);
    const { data, error } = await admin.rpc('settle_ranked_match', { p_game_id: gameId });
    if (error) throw error;
    const { data: game, error: gameError } = await admin
      .from('multiplayer_games')
      .select('winner_id, player_one_score, player_two_score')
      .eq('id', gameId)
      .single();
    if (gameError) throw gameError;
    const { data: players, error: playersError } = await admin
      .from('multiplayer_players')
      .select('user_id')
      .eq('game_id', gameId);
    if (playersError) throw playersError;
    await Promise.all((players ?? []).map((player) => {
      const won = game.winner_id === player.user_id;
      const draw = game.winner_id == null;
      return sendPushNotification(
        [player.user_id],
        'Competitive Duel complete',
        draw ? 'Your ranked match ended in a draw.' : won ? 'You won your ranked LetterLoom match.' : 'Your ranked match has ended.',
        { game_id: gameId, event: 'ranked_match_complete' },
        'ranked_matches',
      );
    }));
    return response(data);
  } catch (error) {
    console.error('settle-ranked-match error', error);
    return response({ error: error instanceof Error ? error.message : 'Unable to settle ranked match.' }, 400);
  }
});
