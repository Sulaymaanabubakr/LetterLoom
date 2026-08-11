import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { SignJWT, importPKCS8 } from 'npm:jose@5.10.0';
import { corsHeaders } from '../_shared/cors.ts';
import { getAdminClient, getAuthenticatedUser } from '../_shared/supabase.ts';

const PACKAGE_NAME = Deno.env.get('GOOGLE_PLAY_PACKAGE_NAME') ?? 'com.letter.loom';

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

async function googleAccessToken(): Promise<string> {
  const raw = Deno.env.get('GOOGLE_PLAY_SERVICE_ACCOUNT_JSON');
  if (!raw) throw new Error('Google Play verification is not configured.');
  const serviceAccount = JSON.parse(raw) as { client_email: string; private_key: string };
  const key = await importPKCS8(serviceAccount.private_key, 'RS256');
  const assertion = await new SignJWT({ scope: 'https://www.googleapis.com/auth/androidpublisher' })
    .setProtectedHeader({ alg: 'RS256', typ: 'JWT' })
    .setIssuer(serviceAccount.client_email)
    .setSubject(serviceAccount.client_email)
    .setAudience('https://oauth2.googleapis.com/token')
    .setIssuedAt()
    .setExpirationTime('1h')
    .sign(key);
  const tokenResponse = await fetch('https://oauth2.googleapis.com/token', {
    method: 'POST',
    headers: { 'Content-Type': 'application/x-www-form-urlencoded' },
    body: new URLSearchParams({
      grant_type: 'urn:ietf:params:oauth:grant-type:jwt-bearer',
      assertion,
    }),
  });
  if (!tokenResponse.ok) throw new Error('Google access token request failed.');
  const token = await tokenResponse.json() as { access_token?: string };
  if (!token.access_token) throw new Error('Google access token was empty.');
  return token.access_token;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return response({ error: 'POST is required.' }, 405);
  try {
    const user = await getAuthenticatedUser(req);
    const body = await req.json().catch(() => ({}));
    const productId = String(body.product_id ?? '').trim();
    const purchaseToken = String(body.purchase_token ?? '').trim();
    const allowedProducts = new Set([
      'letterloom_hints_move_5',
      'letterloom_hints_letter_5',
      'letterloom_hints_strong_3',
      'letterloom_hints_mixed_bundle',
    ]);
    if (!allowedProducts.has(productId) || purchaseToken.length < 12) {
      return response({ error: 'Invalid purchase.' }, 400);
    }

    const token = await googleAccessToken();
    const url = `https://androidpublisher.googleapis.com/androidpublisher/v3/applications/${PACKAGE_NAME}/purchases/products/${encodeURIComponent(productId)}/tokens/${encodeURIComponent(purchaseToken)}`;
    const purchaseResponse = await fetch(url, {
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!purchaseResponse.ok) return response({ error: 'Purchase could not be verified.' }, 400);
    const purchase = await purchaseResponse.json() as {
      purchaseState?: number;
      consumptionState?: number;
      purchaseTimeMillis?: string;
      orderId?: string;
    };
    if (purchase.purchaseState !== 0 || purchase.consumptionState !== 0) {
      return response({ error: 'Purchase is not eligible for fulfilment.' }, 400);
    }

    const admin = getAdminClient();
    const { data: grant, error: grantError } = await admin.rpc('grant_verified_google_purchase', {
      p_user_id: user.id,
      p_purchase_token: purchaseToken,
      p_product_id: productId,
      p_metadata: {
        order_id: purchase.orderId ?? null,
        purchase_time_millis: purchase.purchaseTimeMillis ?? null,
      },
    });
    if (grantError) throw grantError;

    // Consume only after the idempotent ledger write succeeds. If a retry sees
    // an already-fulfilled token, consuming again is harmless and keeps the
    // Play transaction from being delivered repeatedly.
    const consumeResponse = await fetch(`${url}:consume`, {
      method: 'POST',
      headers: { Authorization: `Bearer ${token}` },
    });
    if (!consumeResponse.ok) throw new Error('Play consumption failed; retry is required.');
    return response({ verified: true, ...(grant ?? {}) });
  } catch (error) {
    console.error('billing-verify error', error);
    return response({ error: error instanceof Error ? error.message : 'Unable to verify purchase.' }, 400);
  }
});
