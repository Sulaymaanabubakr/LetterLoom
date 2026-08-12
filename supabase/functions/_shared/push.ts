import { getAdminClient } from './supabase.ts';

type PushData = Record<string, string>;

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
): Promise<void> {
  try {
    const rawServiceAccount = Deno.env.get('FIREBASE_SERVICE_ACCOUNT_JSON');
    if (!rawServiceAccount || userIds.length === 0) return;

    const serviceAccount = JSON.parse(rawServiceAccount) as Record<string, string>;
    const admin = getAdminClient();
    const { data: devices, error } = await admin
      .from('push_devices')
      .select('user_id, token')
      .in('user_id', userIds);
    if (error) throw error;
    if (!devices || devices.length === 0) return;

    const { data: preferences, error: preferenceError } = await admin
      .from('notification_preferences')
      .select(`user_id, ${preference}`)
      .in('user_id', [...new Set(userIds)]);
    if (preferenceError) throw preferenceError;
    const enabledByUser = new Map(
      (preferences ?? []).map((item) => [item.user_id as string, item[preference] !== false]),
    );
    const eligibleDevices = devices.filter((device) => enabledByUser.get(device.user_id as string) !== false);
    if (eligibleDevices.length === 0) return;

    const token = await accessToken(serviceAccount);
    const endpoint = `https://fcm.googleapis.com/v1/projects/${serviceAccount.project_id}/messages:send`;
    await Promise.all(eligibleDevices.map(async (device) => {
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
          },
        }),
      });
      if (!response.ok) console.error('FCM delivery failed:', response.status);
    }));
  } catch (error) {
    console.error('Push notification failed:', error);
  }
}
