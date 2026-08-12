alter table public.daily_word_mosaic_progress
  add column if not exists remaining_seconds integer not null default 180
    check (remaining_seconds between 0 and 180),
  add column if not exists timer_started_at timestamptz,
  add column if not exists failed boolean not null default false;
