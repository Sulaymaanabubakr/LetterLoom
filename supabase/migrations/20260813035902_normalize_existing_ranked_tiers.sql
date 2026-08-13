-- Existing rows were written before the full tier trigger existed. The
-- validation trigger intentionally protects competitive fields, so bypass
-- user triggers for this one controlled normalization only.
alter table public.player_profiles disable trigger user;
update public.player_profiles
set ranked_tier = public.letterloom_ranked_tier(ranked_rating);
alter table public.player_profiles enable trigger user;
