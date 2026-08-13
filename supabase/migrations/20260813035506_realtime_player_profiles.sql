-- Leaderboards and profile/progression views need to receive authoritative
-- rating/profile changes without requiring a relaunch.
alter publication supabase_realtime add table public.player_profiles;

-- Keep the persisted tier aligned with the client-facing rating bands. The
-- existing settlement function writes only three broad labels; this trigger
-- makes every service-owned rating update use the full ladder.
create or replace function public.letterloom_ranked_tier(p_rating integer)
returns text
language sql
immutable
set search_path = public
as $$
  select case
    when p_rating < 1000 then 'Bronze III'
    when p_rating < 1100 then 'Bronze II'
    when p_rating < 1200 then 'Bronze I'
    when p_rating < 1350 then 'Silver III'
    when p_rating < 1500 then 'Silver II'
    when p_rating < 1650 then 'Silver I'
    when p_rating < 1800 then 'Gold III'
    when p_rating < 1950 then 'Gold II'
    when p_rating < 2100 then 'Gold I'
    when p_rating < 2300 then 'Platinum'
    when p_rating < 2500 then 'Diamond'
    else 'Master'
  end;
$$;

create or replace function public.sync_ranked_tier()
returns trigger
language plpgsql
set search_path = public
as $$
begin
  new.ranked_tier := public.letterloom_ranked_tier(new.ranked_rating);
  return new;
end;
$$;

drop trigger if exists player_profiles_ranked_tier on public.player_profiles;
create trigger player_profiles_ranked_tier
before insert or update of ranked_rating on public.player_profiles
for each row execute function public.sync_ranked_tier();

update public.player_profiles
set ranked_tier = public.letterloom_ranked_tier(ranked_rating)
where ranked_tier <> public.letterloom_ranked_tier(ranked_rating);
