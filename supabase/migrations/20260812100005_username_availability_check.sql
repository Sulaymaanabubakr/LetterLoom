-- Fast, authenticated availability feedback for the profile editor. The
-- unique constraint on player_profiles.lower_username remains the final
-- authority at write time, so simultaneous claims cannot create duplicates.
create or replace function public.is_username_available(candidate text)
returns boolean
language plpgsql
security definer
set search_path = public
as $$
declare
  normalized text := lower(trim(candidate));
  current_user_id uuid := auth.uid();
begin
  if current_user_id is null then
    raise exception 'authentication required';
  end if;

  if normalized !~ '^[a-z0-9_]{3,20}$' then
    return false;
  end if;

  if normalized in ('admin','administrator','moderator','letterloom','support',
                    'official','system','root','superuser','helpdesk',
                    'security','guest','null','undefined')
     or normalized like '%letterloom%'
     or normalized like '%badword%'
     or normalized like '%profanity%'
     or normalized like '%hate%'
     or normalized like '%scam%'
     or normalized like '%abuse%' then
    return false;
  end if;

  return not exists (
    select 1
    from public.player_profiles
    where lower_username = normalized
      and id <> current_user_id
  );
end;
$$;

revoke all on function public.is_username_available(text) from public, anon;
grant execute on function public.is_username_available(text) to authenticated;
