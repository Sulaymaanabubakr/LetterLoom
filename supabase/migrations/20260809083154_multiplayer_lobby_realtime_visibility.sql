-- Waiting rooms are public lobby metadata. Private racks and active match state
-- remain protected by the participant policies.
create policy "authenticated users can read waiting multiplayer rooms"
on public.multiplayer_games
for select
to authenticated
using (status = 'waiting');

alter table public.multiplayer_games replica identity full;
