-- Run after the existing profile validation trigger so both normal writes and
-- service-owned rating settlements persist the tier derived from the final
-- validated rating.
drop trigger if exists player_profiles_ranked_tier on public.player_profiles;
drop trigger if exists player_profiles_zz_ranked_tier on public.player_profiles;
create trigger player_profiles_zz_ranked_tier
before insert or update of ranked_rating on public.player_profiles
for each row execute function public.sync_ranked_tier();

update public.player_profiles
set ranked_tier = public.letterloom_ranked_tier(ranked_rating);
