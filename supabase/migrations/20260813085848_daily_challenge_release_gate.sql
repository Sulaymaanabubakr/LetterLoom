-- Daily Challenge release is authoritative in UTC. The existing scheduled
-- reminder runs at 08:00 UTC, so clients cannot unlock the puzzle early by
-- changing their device clock or bypassing the push notification.
create or replace function public.daily_challenge_release_at(p_date date)
returns timestamptz
language sql
immutable
as $$
  select (p_date::timestamp + time '08:00') at time zone 'UTC';
$$;

alter table public.daily_word_mosaic_progress
  add column if not exists release_at timestamptz;

update public.daily_word_mosaic_progress
set release_at = public.daily_challenge_release_at(puzzle_date)
where release_at is null;

alter table public.daily_word_mosaic_progress
  alter column release_at set not null;

create index if not exists daily_word_mosaic_release_idx
  on public.daily_word_mosaic_progress (puzzle_date, release_at);
