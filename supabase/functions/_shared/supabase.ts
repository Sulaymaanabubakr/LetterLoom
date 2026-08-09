import { createClient, type User } from 'npm:@supabase/supabase-js@2';

function getPublicKey(): string {
  const keys = Deno.env.get('SUPABASE_PUBLISHABLE_KEYS');
  if (keys) {
    return JSON.parse(keys).default ?? '';
  }
  return Deno.env.get('SUPABASE_ANON_KEY') ?? '';
}

function getSecretKey(): string {
  const keys = Deno.env.get('SUPABASE_SECRET_KEYS');
  if (keys) {
    return JSON.parse(keys).default ?? '';
  }
  return Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? '';
}

export async function getAuthenticatedUser(req: Request): Promise<User> {
  const authorization = req.headers.get('Authorization');
  if (!authorization?.startsWith('Bearer ')) {
    throw new Error('Authentication is required.');
  }

  const client = createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    getPublicKey(),
    { global: { headers: { Authorization: authorization } } },
  );

  const token = authorization.slice('Bearer '.length);
  const { data, error } = await client.auth.getUser(token);
  if (error || !data.user) {
    throw new Error('Your session is no longer valid.');
  }
  return data.user;
}

export function getAdminClient() {
  return createClient(
    Deno.env.get('SUPABASE_URL') ?? '',
    getSecretKey(),
    { auth: { autoRefreshToken: false, persistSession: false } },
  );
}
