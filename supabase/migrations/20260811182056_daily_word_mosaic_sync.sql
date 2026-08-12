create table if not exists public.daily_word_mosaic_progress (
  user_id uuid not null references auth.users(id) on delete cascade,
  puzzle_date date not null,
  puzzle_id text not null,
  difficulty_tier smallint not null default 0 check (difficulty_tier between 0 and 3),
  solved_word_indexes integer[] not null default '{}',
  score integer not null default 0 check (score >= 0),
  completed boolean not null default false,
  streak_days integer not null default 0 check (streak_days >= 0),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  primary key (user_id, puzzle_date)
);

alter table public.daily_word_mosaic_progress enable row level security;

drop policy if exists "Users can view their daily word progress" on public.daily_word_mosaic_progress;
create policy "Users can view their daily word progress"
  on public.daily_word_mosaic_progress for select
  to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Users can create their daily word progress" on public.daily_word_mosaic_progress;
create policy "Users can create their daily word progress"
  on public.daily_word_mosaic_progress for insert
  to authenticated
  with check ((select auth.uid()) = user_id);

drop policy if exists "Users can update their daily word progress" on public.daily_word_mosaic_progress;
create policy "Users can update their daily word progress"
  on public.daily_word_mosaic_progress for update
  to authenticated
  using ((select auth.uid()) = user_id)
  with check ((select auth.uid()) = user_id);

create index if not exists daily_word_mosaic_progress_history_idx
  on public.daily_word_mosaic_progress (user_id, puzzle_id, puzzle_date desc);

alter table public.daily_word_mosaic_progress
  add column if not exists words jsonb not null default '[]'::jsonb;
