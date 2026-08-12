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
    const body = await req.json().catch(() => ({}));
    const testUserId = typeof body.test_user_id === 'string'
      ? body.test_user_id.trim()
      : '';
    const admin = getAdminClient();
    let devicesQuery = admin
      .from('push_devices')
      .select('user_id');
    if (testUserId) devicesQuery = devicesQuery.eq('user_id', testUserId);
    const { data: devices, error } = await devicesQuery;
    if (error) throw error;
    const recipients = [...new Set((devices ?? []).map((device) => device.user_id as string))];
    await sendPushNotification(
      recipients,
      testUserId ? 'LetterLoom notification test' : 'Daily Challenge is ready',
      testUserId
          ? 'Push notifications are working on this device.'
          : 'A new Word Mosaic is waiting for you in LetterLoom.',
      { event: testUserId ? 'notification_test' : 'daily_challenge' },
      'daily_reminders',
    );
    return response({ delivered_to: recipients.length });
  } catch (error) {
    console.error('daily-notification-reminders error', error);
    return response({ error: 'Unable to send daily reminders.' }, 500);
  }
});
