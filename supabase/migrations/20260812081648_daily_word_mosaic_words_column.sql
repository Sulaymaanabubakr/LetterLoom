-- Persist the exact server-generated scramble for each player's daily puzzle.
-- Existing production databases predate this column, so the Edge Function was
-- failing when it attempted to save a new player's generated puzzle.
alter table public.daily_word_mosaic_progress
  add column if not exists words jsonb not null default '[]'::jsonb;
