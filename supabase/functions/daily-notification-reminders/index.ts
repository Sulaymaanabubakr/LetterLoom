import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { sendPushNotification } from '../_shared/push.ts';
import { getAdminClient } from '../_shared/supabase.ts';

const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), {
  status,
  headers: { ...corsHeaders, 'Content-Type': 'application/json' },
});

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return response({ error: 'POST is required.' }, 405);

  const expected = Deno.env.get('LETTERLOOM_DAILY_REMINDER_SECRET');
  if (!expected || req.headers.get('x-letterloom-cron-secret') !== expected) {
    return response({ error: 'Unauthorized.' }, 401);
  }

  try {
    const admin = getAdminClient();
    const { data: devices, error } = await admin
      .from('push_devices')
      .select('user_id');
    if (error) throw error;
    const recipients = [...new Set((devices ?? []).map((device) => device.user_id as string))];
    await sendPushNotification(
      recipients,
      'Daily Challenge is ready',
      'A new Word Mosaic is waiting for you in LetterLoom.',
      { event: 'daily_challenge' },
      'daily_reminders',
    );
    return response({ delivered_to: recipients.length });
  } catch (error) {
    console.error('daily-notification-reminders error', error);
    return response({ error: 'Unable to send daily reminders.' }, 500);
  }
});
