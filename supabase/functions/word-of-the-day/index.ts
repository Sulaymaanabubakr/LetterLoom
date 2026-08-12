import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getAdminClient } from '../_shared/supabase.ts';

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'GET' && req.method !== 'POST') {
    return response({ error: 'GET or POST is required.' }, 405);
  }
  try {
    const { data, error } = await getAdminClient().rpc('current_word_of_the_day');
    if (error) throw error;
    const word = Array.isArray(data) ? data[0] : null;
    if (!word) throw new Error('Word of the Day is unavailable.');
    return response({ word });
  } catch (error) {
    console.error('word-of-the-day error', error);
    return response({ error: error instanceof Error ? error.message : 'Unable to load Word of the Day.' }, 503);
  }
});
