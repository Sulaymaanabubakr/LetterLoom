create table public.push_devices (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  token text not null unique,
  platform text not null check (platform in ('android', 'ios')),
  app_id text not null default 'letterloom',
  last_seen_at timestamptz not null default now(),
  created_at timestamptz not null default now()
);

create index push_devices_user_idx on public.push_devices(user_id, last_seen_at desc);

alter table public.push_devices enable row level security;

create policy "users can read their push devices"
on public.push_devices for select to authenticated
using ((select auth.uid()) = user_id);

create policy "users can register their push devices"
on public.push_devices for insert to authenticated
with check ((select auth.uid()) = user_id);

create policy "users can update their push devices"
on public.push_devices for update to authenticated
using ((select auth.uid()) = user_id)
with check ((select auth.uid()) = user_id);

create policy "users can remove their push devices"
on public.push_devices for delete to authenticated
using ((select auth.uid()) = user_id);
