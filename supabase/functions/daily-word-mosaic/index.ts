import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getAdminClient, getAuthenticatedUser } from '../_shared/supabase.ts';

type Word = { clue: string; answer: string };
type Template = { id: string; tier: number; words: Word[] };

const catalog: Template[] = [
  { id: 'garden-01', tier: 0, words: [
    { clue: 'A bright object in the sky', answer: 'SUN' }, { clue: 'A hot morning drink', answer: 'TEA' },
    { clue: 'A place you live', answer: 'HOME' }, { clue: 'A shining night shape', answer: 'STAR' },
    { clue: 'Something you read', answer: 'BOOK' }, { clue: 'Have fun with a game', answer: 'PLAY' },
  ] },
  { id: 'garden-02', tier: 0, words: [
    { clue: 'A small flying insect', answer: 'BEE' }, { clue: 'Frozen water', answer: 'ICE' },
    { clue: 'A young dog', answer: 'PUPPY' }, { clue: 'A colorful sky arc', answer: 'RAINBOW' },
    { clue: 'A soft sound', answer: 'WHISPER' }, { clue: 'A place with many trees', answer: 'FOREST' },
  ] },
  { id: 'garden-03', tier: 0, words: [
    { clue: 'A fast land animal', answer: 'HORSE' }, { clue: 'A meal eaten at midday', answer: 'LUNCH' },
    { clue: 'A sweet baked treat', answer: 'CAKE' }, { clue: 'A body of flowing water', answer: 'RIVER' },
    { clue: 'A bright flash in a storm', answer: 'LIGHTNING' }, { clue: 'A place full of flowers', answer: 'GARDEN' },
  ] },
  { id: 'grove-01', tier: 1, words: [
    { clue: 'A path through a place', answer: 'JOURNEY' }, { clue: 'A clear open area', answer: 'BRIGHT' },
    { clue: 'A written message', answer: 'LETTER' }, { clue: 'A cold winter crystal', answer: 'FROST' },
    { clue: 'A problem to solve', answer: 'PUZZLE' }, { clue: 'A peaceful outdoor space', answer: 'MEADOW' },
  ] },
  { id: 'grove-02', tier: 1, words: [
    { clue: 'A strong desire to know', answer: 'CURIOSITY' }, { clue: 'A careful plan', answer: 'STRATEGY' },
    { clue: 'A sudden bright idea', answer: 'INSIGHT' }, { clue: 'A place where books live', answer: 'LIBRARY' },
    { clue: 'A long period of time', answer: 'MOMENT' }, { clue: 'A gentle movement of air', answer: 'BREEZE' },
  ] },
  { id: 'summit-01', tier: 2, words: [
    { clue: 'A soft evening light', answer: 'TWILIGHT' }, { clue: 'A remarkable wonder', answer: 'MARVEL' },
    { clue: 'A difficult puzzle', answer: 'ENIGMA' }, { clue: 'A quiet secret', answer: 'WHISPER' },
    { clue: 'A long expedition', answer: 'ADVENTURE' }, { clue: 'A clever solution', answer: 'INGENUITY' },
  ] },
  { id: 'summit-02', tier: 2, words: [
    { clue: 'A language expert', answer: 'LINGUIST' }, { clue: 'A strong contrast', answer: 'PARADOX' },
    { clue: 'A thoughtful pause', answer: 'REFLECTION' }, { clue: 'A graceful movement', answer: 'ELEGANCE' },
    { clue: 'A hidden route', answer: 'PASSAGE' }, { clue: 'A bold undertaking', answer: 'VENTURE' },
  ] },
  { id: 'master-01', tier: 3, words: [
    { clue: 'Unusually difficult to understand', answer: 'OBSCURE' }, { clue: 'A fortunate coincidence', answer: 'SERENDIPITY' },
    { clue: 'A person who studies stars', answer: 'ASTRONOMER' }, { clue: 'The art of beautiful writing', answer: 'CALLIGRAPHY' },
    { clue: 'A subtle distinction', answer: 'NUANCE' }, { clue: 'A powerful expression', answer: 'RHETORIC' },
  ] },
  { id: 'master-02', tier: 3, words: [
    { clue: 'A complicated explanation', answer: 'ELABORATION' }, { clue: 'A person who loves books', answer: 'BIBLIOPHILE' },
    { clue: 'A lack of certainty', answer: 'AMBIGUITY' }, { clue: 'A deep, restful calm', answer: 'TRANQUILITY' },
    { clue: 'A clever word trick', answer: 'PUNCTUATION' }, { clue: 'A meaningful conversation', answer: 'DIALOGUE' },
  ] },
];

const response = (body: unknown, status = 200) => new Response(JSON.stringify(body), { status, headers: { ...corsHeaders, 'Content-Type': 'application/json' } });
const stableHash = (value: string) => { let hash = 2166136261; for (const char of value) hash = ((hash ^ char.charCodeAt(0)) * 16777619) & 0x7fffffff; return hash; };
const tierForStreak = (streak: number) => streak >= 10 ? 3 : streak >= 5 ? 2 : streak >= 2 ? 1 : 0;
const puzzleFor = (template: Template, seed: number) => {
  const random = (max: number) => { seed = (seed * 1664525 + 1013904223) & 0x7fffffff; return seed % max; };
  return template.words.map((word) => {
    const letters = [...word.answer, 'AEIOULMNRST'[random(11)]];
    for (let index = letters.length - 1; index > 0; index--) {
      const swapIndex = random(index + 1);
      [letters[index], letters[swapIndex]] = [letters[swapIndex], letters[index]];
    }
    // A decoy makes the complete array differ from the answer, so checking
    // the full string is insufficient: R I V E R O still looks solved.
    if (letters.slice(0, word.answer.length).join('') === word.answer) {
      [letters[0], letters[1]] = [letters[1], letters[0]];
    }
    return { clue: word.clue, answer: word.answer, letters };
  });
};
const publicWords = (
  words: Array<{ clue: string; answer: string; letters: string[] }>,
  solvedIndexes: number[] = [],
  revealAll = false,
) => words.map((word, index) => ({
    clue: word.clue,
    answer_length: word.answer.length,
    letters: word.letters,
    ...(revealAll || solvedIndexes.includes(index)
      ? { solved_answer: word.answer }
      : {}),
  }));

const timerState = (progress: Record<string, unknown>) => {
  const started = typeof progress.timer_started_at === 'string'
    ? Date.parse(progress.timer_started_at) : NaN;
  const stored = Number(progress.remaining_seconds ?? 180);
  const remaining = Number.isNaN(started)
    ? stored : Math.max(0, stored - Math.floor((Date.now() - started) / 1000));
  return { remaining, expired: remaining === 0 && progress.completed !== true };
};

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return response({ error: 'POST is required.' }, 405);
  try {
    const user = await getAuthenticatedUser(req);
    if (user.is_anonymous) {
      return response({ error: 'Sign in to sync your Daily Challenge.' }, 401);
    }
    const body = await req.json().catch(() => ({}));
    const action = String(body.action ?? 'get');
    const admin = getAdminClient();
    const today = new Date().toISOString().slice(0, 10);
    const releaseAt = new Date(`${today}T08:00:00.000Z`);
    const serverNow = new Date();
    if (serverNow < releaseAt) {
      return response({
        available: false,
        date: today,
        release_at: releaseAt.toISOString(),
        server_now: serverNow.toISOString(),
      });
    }
    const { data: current } = await admin.from('daily_word_mosaic_progress').select('*').eq('user_id', user.id).eq('puzzle_date', today).maybeSingle();
    const { data: previous } = await admin.from('daily_word_mosaic_progress').select('puzzle_date, streak_days, puzzle_id').eq('user_id', user.id).order('puzzle_date', { ascending: false }).limit(30);
    const yesterday = new Date(Date.now() - 86400000).toISOString().slice(0, 10);
    const prior = previous?.find((row) => row.puzzle_date === yesterday);
    const streak = prior?.streak_days ?? 0;
    const tier = current?.difficulty_tier ?? tierForStreak(streak);
    let template = catalog.find((item) => item.id === current?.puzzle_id);
    if (!template) {
      const used = new Set((previous ?? []).map((row) => row.puzzle_id));
      const eligible = catalog.filter((item) => item.tier <= tier && !used.has(item.id));
      const pool = eligible.length ? eligible : catalog.filter((item) => item.tier <= tier);
      template = pool[stableHash(`${today}:${user.id}`) % pool.length];
      const { error } = await admin.from('daily_word_mosaic_progress').upsert({ user_id: user.id, puzzle_date: today, release_at: releaseAt.toISOString(), puzzle_id: template.id, difficulty_tier: tier, streak_days: streak, solved_word_indexes: [], score: 0, completed: false, remaining_seconds: 180, failed: false }, { onConflict: 'user_id,puzzle_date' });
      if (error) throw error;
    }
    const generatedWords = puzzleFor(template, stableHash(`${today}:${user.id}:${template.id}`));
    let words = Array.isArray(current?.words) && current.words.length > 0
      ? current.words as Array<{ clue: string; answer: string; letters: string[] }>
      : generatedWords;
    const storedWordsAreUnshuffled = words.some((word) =>
      word.letters.slice(0, word.answer.length).join('') === word.answer
    );
    if (!current || !Array.isArray(current.words) || current.words.length === 0 || storedWordsAreUnshuffled) {
      words = generatedWords;
      const { error } = await admin.from('daily_word_mosaic_progress')
        .update({ words, updated_at: new Date().toISOString() })
        .eq('user_id', user.id)
        .eq('puzzle_date', today);
      if (error) throw error;
    }
    const currentTimer = current ? timerState(current) : { remaining: 180, expired: false };
    if (currentTimer.expired || current?.failed === true) {
      const { data: failedProgress, error } = await admin
        .from('daily_word_mosaic_progress')
        .update({
          remaining_seconds: 0,
          timer_started_at: null,
          failed: true,
          updated_at: new Date().toISOString(),
        })
        .eq('user_id', user.id)
        .eq('puzzle_date', today)
        .select('*')
        .single();
      if (error) throw error;

      // An expired challenge is a valid, viewable state—not a transport or
      // sign-in failure. Returning the normal snapshot lets the app show the
      // failed challenge instead of incorrectly calling it unavailable.
      return response({
        available: true,
        release_at: releaseAt.toISOString(),
        server_now: new Date().toISOString(),
        accepted: false,
        puzzle: {
          date: today,
          puzzle_id: template.id,
          difficulty_tier: tier,
          words: publicWords(
            words,
            Array.isArray(failedProgress.solved_word_indexes)
              ? failedProgress.solved_word_indexes.map((value: unknown) => Number(value))
              : [],
            true,
          ),
          target_score: words.reduce((sum, word) => sum + word.answer.length, 0),
        },
        progress: { ...failedProgress, remaining_seconds: 0 },
      });
    }
    if (action === 'expire') {
      const { error } = await admin.from('daily_word_mosaic_progress').update({ remaining_seconds: 0, timer_started_at: null, failed: true, updated_at: new Date().toISOString() }).eq('user_id', user.id).eq('puzzle_date', today);
      if (error) throw error;
    } else if (action === 'pause') {
      const { error } = await admin.from('daily_word_mosaic_progress').update({ remaining_seconds: currentTimer.remaining, timer_started_at: null, updated_at: new Date().toISOString() }).eq('user_id', user.id).eq('puzzle_date', today);
      if (error) throw error;
    } else if (action === 'resume') {
      const { error } = await admin.from('daily_word_mosaic_progress').update({ timer_started_at: new Date().toISOString(), updated_at: new Date().toISOString() }).eq('user_id', user.id).eq('puzzle_date', today);
      if (error) throw error;
    } else if (action === 'submit') {
      const wordIndex = Number(body.word_index);
      const submittedLetters = Array.isArray(body.letters)
        ? body.letters.map((value: unknown) => String(value).toUpperCase())
        : [];
      // Persisted letters keep a player's scramble stable. Answers, however,
      // must always come from the immutable catalog rather than mutable JSON
      // stored on a progress row.
      const selected = Number.isInteger(wordIndex) && wordIndex >= 0 && wordIndex < template.words.length
        ? template.words[wordIndex]
        : null;
      const accepted = selected !== null
        && submittedLetters.length === selected.answer.length
        && submittedLetters.join('') === selected.answer;
      if (!accepted) {
        return response({
          accepted: false,
          error: 'The submitted letters do not solve this clue.',
        });
      }

      const currentSolved = Array.isArray(current?.solved_word_indexes)
        ? current.solved_word_indexes.map((value: unknown) => Number(value))
        : [];
      const indexes = [...new Set([...currentSolved, wordIndex])]
        .filter((value) => Number.isInteger(value) && value >= 0 && value < words.length)
        .sort((a, b) => a - b);
      const score = indexes.reduce((sum, index) => sum + words[index].answer.length, 0);
      const completed = indexes.length === words.length;
      const nextStreak = completed ? streak + 1 : streak;
      const { error } = await admin.from('daily_word_mosaic_progress').update({
        solved_word_indexes: indexes,
        score,
        completed,
        streak_days: nextStreak,
        updated_at: new Date().toISOString(),
      }).eq('user_id', user.id).eq('puzzle_date', today);
      if (error) throw error;
    } else if (action !== 'get') {
      return response({ error: 'Word submissions must be validated individually.' }, 400);
    }
    const { data: progress } = await admin.from('daily_word_mosaic_progress').select('*').eq('user_id', user.id).eq('puzzle_date', today).single();
    const finalTimer = timerState(progress);
    if (finalTimer.expired && progress.completed !== true) {
      await admin.from('daily_word_mosaic_progress').update({ remaining_seconds: 0, timer_started_at: null, failed: true, updated_at: new Date().toISOString() }).eq('user_id', user.id).eq('puzzle_date', today);
      progress.remaining_seconds = 0;
      progress.timer_started_at = null;
      progress.failed = true;
    }
    return response({
      available: true,
      release_at: releaseAt.toISOString(),
      server_now: new Date().toISOString(),
      accepted: action === 'submit',
      puzzle: {
        date: today,
        puzzle_id: template.id,
        difficulty_tier: tier,
        words: publicWords(
          words,
          Array.isArray(progress.solved_word_indexes)
            ? progress.solved_word_indexes.map((value: unknown) => Number(value))
            : [],
          progress.failed === true,
        ),
        target_score: words.reduce((sum, word) => sum + word.answer.length, 0),
      },
      progress: { ...progress, remaining_seconds: finalTimer.remaining },
    });
  } catch (error) {
    console.error('daily-word-mosaic error', error);
    return response({ error: error instanceof Error ? error.message : 'Unable to load the Daily Challenge.' }, 400);
  }
});
