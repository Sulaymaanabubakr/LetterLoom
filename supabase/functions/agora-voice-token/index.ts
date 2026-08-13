import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { RtcTokenBuilder, RtcRole } from 'npm:agora-access-token@2.0.0';
import { corsHeaders } from '../_shared/cors.ts';
import { getAdminClient, getAuthenticatedUser } from '../_shared/supabase.ts';

const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return response({ error: 'POST is required.' }, 405);
  try {
    const user = await getAuthenticatedUser(req);
    const { game_id: gameId } = await req.json().catch(() => ({}));
    if (typeof gameId !== 'string' || !gameId) return response({ error: 'A match is required.' }, 400);
    const admin = getAdminClient();
    const { data: participant, error: participantError } = await admin.from('multiplayer_players')
      .select('user_id').eq('game_id', gameId).eq('user_id', user.id).maybeSingle();
    if (participantError) throw participantError;
    if (!participant) return response({ error: 'You are not a participant in this match.' }, 403);
    const { data: game, error: gameError } = await admin.from('multiplayer_games')
      .select('id, room_code, status').eq('id', gameId).maybeSingle();
    if (gameError) throw gameError;
    if (!game || !['waiting', 'active'].includes(game.status)) return response({ error: 'This match is no longer available.' }, 409);
    const cleanSecret = (value: string | undefined) =>
      value
        ?.trim()
        .replaceAll('\\', '')
        .replace(/^['"]+|['"]+$/g, '')
        .trim();
    const appId = cleanSecret(Deno.env.get('AGORA_APP_ID'));
    const certificate = cleanSecret(Deno.env.get('AGORA_APP_CERTIFICATE'));
    if (!appId || !certificate) return response({ error: 'Voice chat is not configured.' }, 503);
    const numericUid = Number.parseInt(user.id.replaceAll('-', '').slice(0, 8), 16) || 1;
    const channel = `letterloom_${game.room_code}_${game.id.replaceAll('-', '')}`;
    const expiresAt = Math.floor(Date.now() / 1000) + 3600;
    const token = RtcTokenBuilder.buildTokenWithUid(appId, certificate, channel, numericUid, RtcRole.PUBLISHER, expiresAt);
    return response({ app_id: appId, channel, token, uid: numericUid, expires_at: new Date(expiresAt * 1000).toISOString() });
  } catch (error) {
    console.error('agora-voice-token error', error);
    return response({ error: error instanceof Error ? error.message : 'Unable to create voice token.' }, 400);
  }
});
