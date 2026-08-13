import { getAdminClient } from './supabase.ts';

type PushData = Record<string, string>;

export type PushDeliveryResult = {
  eligible: number;
  sent: number;
  failed: number;
  error?: string;
};

function base64Url(value: Uint8Array | string): string {
  const bytes = typeof value === 'string' ? new TextEncoder().encode(value) : value;
  let binary = '';
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, '-').replace(/\//g, '_').replace(/=+$/g, '');
}

function privateKeyBytes(pem: string): ArrayBuffer {
  const encoded = pem.replace(/-----BEGIN PRIVATE KEY-----|-----END PRIVATE KEY-----|\s/g, '');
  const binary = atob(encoded);
  return Uint8Array.from(binary, (character) => character.charCodeAt(0)).buffer;
}

async function accessToken(serviceAccount: Record<string, string>): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  const header = base64Url(JSON.stringify({ alg: 'RS256', typ: 'JWT' }));
  const claims = base64Url(JSON.stringify({
    iss: serviceAccount.client_email,
    scope: 'https://www.googleapis.com/auth/firebase.messaging',
    aud: 'https://oauth2.googleapis.com/token',
    iat: now,
    exp: now + 3600,
  }));
  const unsigned = `${header}.${claims}`;
  const key = await crypto.subtle.importKey(
    'pkcs8',
    privateKeyBytes(serviceAccount.private_key),
    { name: 'RSASSA-PKCS1-v1_5', hash: 'SHA-256' },
    false,
    ['sign'],
  );
  const signature = await crypto.subtle.sign(
    'RSASSA-PKCS1-v1_5',
    key,
    new TextEncoder().encode(unsigned),
  );
  const response = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion: `${unsigned}.${base64Url(new Uint8Array(signature))}`,
    }),
  });
  const body = await response.json();
  if (!response.ok || !body.access_token) throw new Error('Firebase access token was not issued.');
  return body.access_token as string;
}

export async function sendPushNotification(
  userIds: string[],
  title: string,
  body: string,
  data: PushData = {},
  preference: 'multiplayer_turns' | 'ranked_matches' | 'daily_reminders' = 'multiplayer_turns',
): Promise<PushDeliveryResult> {
  try {
    const rawServiceAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!rawServiceAccount) {
      const error = 'Firebase service account is not configured.';
      console.error(error);
      return { eligible: 0, sent: 0, failed: userIds.length, error };
    }
    if (userIds.length === 0) return { eligible: 0, sent: 0, failed: 0 };

    const serviceAccount = JSON.parse(rawServiceAccount) as Record<string, string>;
    const admin = getAdminClient();
    const { data: devices, error } = await admin
      .from('push_devices')
      .select('user_id, token')
      .in('user_id', userIds);
    if (error) throw error;
    if (!devices || devices.length === 0) return { eligible: 0, sent: 0, failed: 0 };

    const { data: preferences, error: preferenceError } = await admin
      .from('notification_preferences')
      .select(`user_id, ${preference}`)
      .in('user_id', [...new Set(userIds)]);
    if (preferenceError) throw preferenceError;
    const enabledByUser = new Map(
      (preferences ?? []).map((item) => [item.user_id as string, item[preference] !== false]),
    );
    const eligibleDevices = devices.filter((device) => enabledByUser.get(device.user_id as string) !== false);
    if (eligibleDevices.length === 0) return { eligible: 0, sent: 0, failed: 0 };

    const token = await accessToken(serviceAccount);
    const endpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
    let sent = 0;
    let failed = 0;
    await Promise.all(eligibleDevices.map(async (device) => {
      try {
        const response = await fetch(endpoint, {
          method: 'POST',
          headers: {
            Authorization: `Bearer ${token}`,
            'Content-Type': 'application/json',
          },
          body: JSON.stringify({
            message: {
              token: device.token,
              notification: { title, body },
              data,
              android: {
                priority: 'HIGH',
                notification: {
                  channel_id: 'letterloom_gameplay',
                  sound: 'default',
                },
              },
              apns: {
                payload: { aps: { sound: 'default' } },
              },
            },
          }),
        });
        if (response.ok) {
          sent += 1;
          return;
        }
        failed += 1;
        const failure = await response.json().catch(() => ({}));
        const status = String(failure?.error?.status ?? '');
        // FCM reports these for an uninstalled app or a rotated token. Prune
        // only the exact stale token; delivery failures must not disable a
        // player's preferences or affect another device.
        if (status === 'UNREGISTERED' || status === 'INVALID_ARGUMENT') {
          await admin.from('push_devices').delete().eq('token', device.token);
        }
        console.error('FCM delivery failed:', response.status, status);
      } catch (error) {
        failed += 1;
        console.error('FCM request failed:', error);
      }
    }));
    return { eligible: eligibleDevices.length, sent, failed };
  } catch (error) {
    console.error('Push notification failed:', error);
    return {
      eligible: userIds.length,
      sent: 0,
      failed: userIds.length,
      error: error instanceof Error ? error.message : 'Unknown push error',
    };
  }
}
