create table public.notification_preferences (
  user_id uuid primary key references auth.users(id) on delete cascade,
  multiplayer_turns boolean not null default true,
  ranked_matches boolean not null default true,
  daily_reminders boolean not null default true,
  updated_at timestamptz not null default now()
);

alter table public.notification_preferences enable row level security;

create policy "users manage their notification preferences"
on public.notification_preferences for all to authenticated
using ((select auth.uid()) = user_id and private.is_real_user())
with check ((select auth.uid()) = user_id and private.is_real_user());

create or replace function public.touch_notification_preferences()
returns trigger language plpgsql set search_path = public as $$
begin
  new.updated_at = now();
  return new;
end;
$$;

create trigger notification_preferences_updated_at
before update on public.notification_preferences
for each row execute function public.touch_notification_preferences();
