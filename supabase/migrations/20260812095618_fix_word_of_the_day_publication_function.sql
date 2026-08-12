-- Correct the first function version's PL/pgSQL output-column ambiguity.
create or replace function public.current_word_of_the_day()
returns table(word_date date, word text, definition text, tile_score integer)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_today date := (timezone('UTC', now()))::date;
begin
  perform pg_advisory_xact_lock(hashtext('letterloom-word-of-the-day'));

  insert into public.word_of_the_day_publications(word_date, word_id)
  select v_today, c.id
  from public.word_of_the_day_catalog c
  where not exists (
    select 1 from public.word_of_the_day_publications p where p.word_id = c.id
  )
  order by md5(v_today::text || ':' || c.id)
  limit 1
  on conflict on constraint word_of_the_day_publications_pkey do nothing;

  if not exists (
    select 1 from public.word_of_the_day_publications p where p.word_date = v_today
  ) then
    raise exception 'Word of the Day catalog is exhausted; add new unique catalog words.';
  end if;

  return query
  select p.word_date, c.word, c.definition, c.tile_score
  from public.word_of_the_day_publications p
  join public.word_of_the_day_catalog c on c.id = p.word_id
  where p.word_date = v_today;
end;
$$;
