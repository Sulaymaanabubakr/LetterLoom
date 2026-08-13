type AdminClient = {
  from: (table: string) => any;
};

/// Adds the account avatar to the room-player projection without trusting the
/// client-supplied display name. Edge Functions use the service-role client so
/// this remains available even when the caller cannot read other profiles.
export async function addPlayerAvatars(
  admin: AdminClient,
  players: Array<Record<string, unknown>>,
): Promise<Array<Record<string, unknown>>> {
  const ids = players
    .map((player) => String(player.user_id ?? ''))
    .filter(Boolean);
  if (ids.length === 0) return players;

  const { data, error } = await admin
    .from('player_profiles')
    .select('id, avatar_id')
    .in('id', ids);
  if (error) throw error;

  const avatars = new Map(
    (data ?? []).map((profile: Record<string, unknown>) => [
      String(profile.id),
      String(profile.avatar_id ?? 'avatar_owl'),
    ]),
  );
  return players.map((player) => ({
    ...player,
    avatar_id: avatars.get(String(player.user_id ?? '')) ?? 'avatar_owl',
  }));
}
