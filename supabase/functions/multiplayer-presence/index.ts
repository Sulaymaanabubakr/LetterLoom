import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getAdminClient, getAuthenticatedUser } from '../_shared/supabase.ts';

const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return response({ error: 'POST is required.' }, 405);
  try {
    const user = await getAuthenticatedUser(req);
    const body = await req.json().catch(() => ({}));
    const gameId = String(body.game_id ?? '');
    const connected = Boolean(body.connected);
    const micEnabled = connected && Boolean(body.mic_enabled);
    const admin = getAdminClient();
    const { data: member, error: memberError } = await admin.from('multiplayer_players').select('user_id').eq('game_id', gameId).eq('user_id', user.id).maybeSingle();
    if (memberError) throw memberError;
    if (!member) return response({ error: 'You are not a player in this room.' }, 403);
    const { error } = await admin.from('multiplayer_players').update({ connection_status: connected ? 'connected' : 'disconnected', mic_enabled: micEnabled, last_seen_at: new Date().toISOString() }).eq('game_id', gameId).eq('user_id', user.id);
    if (error) throw error;
    return response({ ok: true });
  } catch (error) {
    return response({ error: error instanceof Error ? error.message : 'Unable to update presence.' }, 400);
  }
});
