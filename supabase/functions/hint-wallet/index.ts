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
    const action = String(body.action ?? 'get');
    const admin = getAdminClient();
    await admin.from('player_hint_wallets').upsert({ user_id: user.id }, { onConflict: 'user_id', ignoreDuplicates: true });

    if (action === 'consume') {
      const hintType = String(body.hint_type ?? '');
      const { data, error } = await admin.rpc('consume_server_hint', {
        p_user_id: user.id,
        p_hint_type: hintType,
      });
      if (error) return response({ error: error.message }, 400);
      return response({ result: data });
    }

    if (action === 'daily_reward') {
      const { data, error } = await admin.rpc('claim_daily_return_reward', {
        p_user_id: user.id,
      });
      if (error) return response({ error: error.message }, 400);
      return response({ result: data });
    }

    if (action === 'daily_reward_status') {
      const { data, error } = await admin.rpc('daily_return_reward_status', {
        p_user_id: user.id,
      });
      if (error) return response({ error: error.message }, 400);
      return response({ result: data });
    }

    if (action !== 'get') return response({ error: 'Unsupported wallet action.' }, 400);
    const { data, error } = await admin
      .from('player_hint_wallets')
      .select('daily_move_remaining, daily_letter_remaining, daily_strong_remaining, purchased_move, purchased_letter, purchased_strong, ads_claimed_today, reset_date')
      .eq('user_id', user.id)
      .single();
    if (error) throw error;
    return response({ wallet: data });
  } catch (error) {
    console.error('hint-wallet error', error);
    return response({ error: error instanceof Error ? error.message : 'Unable to load hint wallet.' }, 400);
  }
});
