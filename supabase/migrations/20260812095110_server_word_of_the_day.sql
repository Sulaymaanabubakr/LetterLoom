-- A global server-owned Word of the Day. A catalog word may be published once
-- only; the unique constraint on `word_id` is the permanent no-repeat rule.

create table if not exists public.word_of_the_day_catalog (
  id text primary key check (char_length(id) between 2 and 80),
  word text not null unique check (word = upper(word) and word ~ '^[A-Z]+$'),
  definition text not null check (char_length(trim(definition)) between 12 and 600),
  tile_score integer not null check (tile_score between 1 and 100),
  created_at timestamptz not null default now()
);

create table if not exists public.word_of_the_day_publications (
  word_date date primary key,
  word_id text not null unique references public.word_of_the_day_catalog(id),
  published_at timestamptz not null default now()
);

alter table public.word_of_the_day_catalog enable row level security;
alter table public.word_of_the_day_publications enable row level security;
revoke all on public.word_of_the_day_catalog from anon, authenticated;
revoke all on public.word_of_the_day_publications from anon, authenticated;

insert into public.word_of_the_day_catalog (id, word, definition, tile_score) values
  ('jazz','JAZZ','A genre of music known for improvisation, syncopation, and expressive rhythm.',29),
  ('loom','LOOM','A machine or frame used to weave threads into cloth.',6),
  ('quartz','QUARTZ','A hard crystalline mineral made of silicon dioxide.',24),
  ('zephyr','ZEPHYR','A soft and gentle breeze.',20),
  ('kinetic','KINETIC','Relating to motion or the force produced by movement.',13),
  ('valiant','VALIANT','Possessing courage and determination in the face of danger.',10),
  ('emerald','EMERALD','A vivid green gemstone and a precious variety of beryl.',12),
  ('nexus','NEXUS','A connection or central link between people, ideas, or things.',12),
  ('amber','AMBER','Fossilized tree resin valued for its warm golden color.',9),
  ('anthem','ANTHEM','A rousing song that represents a group, cause, or nation.',11),
  ('arcade','ARCADE','A covered passage or a venue filled with coin-operated games.',9),
  ('beacon','BEACON','A signal light or guide that marks a location or direction.',10),
  ('blossom','BLOSSOM','The flower of a plant, especially one on a tree.',11),
  ('brisk','BRISK','Quick, energetic, and pleasantly stimulating.',11),
  ('candle','CANDLE','A wax cylinder with a wick that produces light when burned.',9),
  ('canvas','CANVAS','A strong woven cloth used for painting or making sails.',11),
  ('cipher','CIPHER','A secret code or a method of transforming a message.',16),
  ('cobalt','COBALT','A hard metallic element often used to create deep blue color.',10),
  ('comet','COMET','A celestial body of ice and dust that forms a glowing tail.',9),
  ('crystal','CRYSTAL','A solid whose atoms are arranged in a repeating pattern.',12),
  ('dawn','DAWN','The first light of day before the sun rises.',8),
  ('dynamo','DYNAMO','A powerful source of energy or a highly energetic person.',12),
  ('ember','EMBER','A small glowing piece of wood or coal in a dying fire.',9),
  ('fable','FABLE','A short story that teaches a moral lesson.',10),
  ('fluent','FLUENT','Able to express oneself easily and accurately in a language.',9),
  ('galaxy','GALAXY','A vast system of stars, gas, dust, and dark matter.',17),
  ('harbor','HARBOR','A sheltered body of water where ships can anchor safely.',11),
  ('horizon','HORIZON','The line where the earth or sea appears to meet the sky.',17),
  ('ignite','IGNITE','To set something on fire or cause a strong feeling to begin.',7),
  ('jovial','JOVIAL','Cheerful, friendly, and full of good humor.',16),
  ('legend','LEGEND','A traditional story or a person admired for great achievement.',8),
  ('lilac','LILAC','A flowering shrub with fragrant purple or white blossoms.',7),
  ('lunar','LUNAR','Relating to the moon.',5),
  ('marble','MARBLE','A hard stone used for sculpture, buildings, and decoration.',10),
  ('meadow','MEADOW','A field of grass and wildflowers.',12),
  ('mirage','MIRAGE','An optical illusion caused by atmospheric conditions.',9),
  ('mosaic','MOSAIC','An image made from small pieces of colored material.',10),
  ('nectar','NECTAR','A sweet liquid produced by flowers.',8),
  ('novel','NOVEL','A long fictional narrative written in prose.',8),
  ('oasis','OASIS','A fertile place in a desert where water is found.',5),
  ('orbit','ORBIT','The curved path of an object around a planet or star.',7),
  ('pebble','PEBBLE','A small smooth stone, often found near water.',10),
  ('phoenix','PHOENIX','A mythical bird reborn from its own ashes.',19),
  ('puzzle','PUZZLE','A problem designed to test ingenuity or knowledge.',26),
  ('ripple','RIPPLE','A small wave or a spreading effect from a single event.',10),
  ('rune','RUNE','A letter from an ancient alphabet with symbolic meaning.',4),
  ('saffron','SAFFRON','A fragrant golden spice made from crocus flower stigmas.',13),
  ('sapphire','SAPPHIRE','A precious gemstone, usually blue, made of corundum.',15),
  ('scarlet','SCARLET','A bright, vivid red color.',9),
  ('serene','SERENE','Calm, peaceful, and untroubled.',6),
  ('signal','SIGNAL','A gesture, sound, or sign used to communicate information.',7),
  ('solace','SOLACE','Comfort or relief during sadness or difficulty.',8),
  ('sonnet','SONNET','A poem of fourteen lines with a formal rhyme scheme.',6),
  ('summit','SUMMIT','The highest point of a hill or mountain.',8),
  ('thrive','THRIVE','To grow or develop vigorously and successfully.',12),
  ('timber','TIMBER','Wood prepared for building and other uses.',10),
  ('velvet','VELVET','A soft woven fabric with a dense, smooth pile.',12),
  ('vivid','VIVID','Producing strong, clear, and powerful impressions.',12),
  ('voyage','VOYAGE','A long journey, especially by sea or through space.',13),
  ('willow','WILLOW','A tree with long flexible branches and narrow leaves.',12),
  ('wonder','WONDER','A feeling of amazement caused by something beautiful or unexpected.',10),
  ('zenith','ZENITH','The highest point or peak of achievement.',18)
on conflict (id) do update set
  word = excluded.word,
  definition = excluded.definition,
  tile_score = excluded.tile_score;

create or replace function public.current_word_of_the_day()
returns table(word_date date, word text, definition text, tile_score integer)
language plpgsql
security definer
set search_path = public, pg_temp
as $$
declare
  v_today date := (timezone('UTC', now()))::date;
begin
  -- Serialise day creation so concurrent first reads cannot select two words.
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

  if not exists (select 1 from public.word_of_the_day_publications where word_date = v_today) then
    raise exception 'Word of the Day catalog is exhausted; add new unique catalog words.';
  end if;

  return query
  select p.word_date, c.word, c.definition, c.tile_score
  from public.word_of_the_day_publications p
  join public.word_of_the_day_catalog c on c.id = p.word_id
  where p.word_date = v_today;
end;
$$;

revoke all on function public.current_word_of_the_day() from public, anon, authenticated;
grant execute on function public.current_word_of_the_day() to service_role;
