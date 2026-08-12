import 'jsr:@supabase/functions-js/edge-runtime.d.ts';
import { corsHeaders } from '../_shared/cors.ts';
import { getAdminClient, getAuthenticatedUser } from '../_shared/supabase.ts';

const achievementIds = new Set([
  'first_victory', 'first_bingo', 'hard_earned', 'big_move', 'triple_century',
  'wordsmith', 'winning_streak', 'veteran', 'champion', 'century_champion',
  'close_call', 'comeback', 'seven_day_streak', 'ranked_debut', 'moving_up',
  'bingo_master',
]);

function response(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...corsHeaders, 'Content-Type': 'application/json' },
  });
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === 'object' && value !== null && !Array.isArray(value);
}

function cleanStatistics(value: unknown): Record<string, unknown> {
  if (!isObject(value)) throw new Error('Invalid statistics payload.');
  const numericKeys = [
    'totalGames', 'wins', 'losses', 'ties', 'highestGameScore',
    'highestSingleTurnScore', 'totalWordsPlayed', 'sevenTileBonuses',
    'winsEasy', 'winsMedium', 'winsHard',
  ];
  const output: Record<string, unknown> = {};
  for (const key of numericKeys) {
    const raw = value[key];
    const number = typeof raw === 'number' ? raw : 0;
    if (!Number.isInteger(number) || number < 0 || number > 10000000) {
      throw new Error('Invalid statistics value.');
    }
    output[key] = number;
  }
  const longestWord = typeof value.longestWord === 'string' ? value.longestWord.slice(0, 32) : '';
  output.longestWord = longestWord;
  return output;
}

function cleanSettings(value: unknown): Record<string, unknown> {
  if (!isObject(value)) return {};
  return {
    soundEnabled: value.soundEnabled === true,
    hapticEnabled: value.hapticEnabled === true,
    musicEnabled: value.musicEnabled === true,
    animationSpeed: typeof value.animationSpeed === 'number' && value.animationSpeed >= 0.25 && value.animationSpeed <= 3
      ? value.animationSpeed : 1,
  };
}

function cleanAchievements(value: unknown) {
  if (!Array.isArray(value) || value.length > achievementIds.size) {
    throw new Error('Invalid achievements payload.');
  }
  return value.flatMap((item) => {
    if (!isObject(item)) return [];
    const id = typeof item.id === 'string' ? item.id : '';
    const currentValue = typeof item.currentValue === 'number' ? item.currentValue : 0;
    if (!achievementIds.has(id) || !Number.isInteger(currentValue) || currentValue < 0 || currentValue > 10000000) return [];
    const unlocked = item.isUnlocked === true;
    return [{ achievement_id: id, current_value: currentValue, unlocked, unlocked_at: unlocked ? new Date().toISOString() : null }];
  });
}

async function snapshot(admin: ReturnType<typeof getAdminClient>, userId: string) {
  const [{ data: progress, error: progressError }, { data: achievements, error: achievementsError }] = await Promise.all([
    admin.from('player_game_progress').select('statistics, settings, active_game, updated_at').eq('user_id', userId).maybeSingle(),
    admin.from('player_achievements').select('achievement_id, current_value, is_unlocked, unlocked_at').eq('user_id', userId),
  ]);
  if (progressError) throw progressError;
  if (achievementsError) throw achievementsError;
  return { progress: progress ?? null, achievements: achievements ?? [] };
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: corsHeaders });
  if (req.method !== 'POST') return response({ error: 'POST is required.' }, 405);
  try {
    const user = await getAuthenticatedUser(req);
    const body = await req.json().catch(() => ({}));
    const action = isObject(body) && typeof body.action === 'string' ? body.action : 'get';
    const admin = getAdminClient();

    if (action === 'get') return response(await snapshot(admin, user.id));

    if (action === 'save') {
      if (!isObject(body)) throw new Error('Invalid progress request.');
      const statistics = cleanStatistics(body.statistics);
      const settings = cleanSettings(body.settings);
      const activeGame = body.active_game === null ? null : body.active_game;
      if (activeGame !== null && (!isObject(activeGame) || JSON.stringify(activeGame).length > 180000)) {
        throw new Error('Invalid saved match.');
      }
      const { error } = await admin.from('player_game_progress').upsert({
        user_id: user.id,
        statistics,
        settings,
        active_game: activeGame,
        updated_at: new Date().toISOString(),
      }, { onConflict: 'user_id' });
      if (error) throw error;

      return response(await snapshot(admin, user.id));
    }

    if (action === 'save_achievements') {
      if (!isObject(body)) throw new Error('Invalid achievements request.');
      const achievements = cleanAchievements(body.achievements);
      for (const achievement of achievements) {
        const { error: achievementError } = await admin.rpc('upsert_player_achievement_progress', {
          p_user_id: user.id,
          p_achievement_id: achievement.achievement_id,
          p_current_value: achievement.current_value,
          p_is_unlocked: achievement.unlocked,
          p_unlocked_at: achievement.unlocked ? achievement.unlocked_at : null,
        });
        if (achievementError) throw achievementError;
      }
      return response(await snapshot(admin, user.id));
    }

    if (action === 'solo_result') {
      if (!isObject(body)) throw new Error('Invalid result request.');
      const eventKey = typeof body.event_key === 'string' ? body.event_key : '';
      const result = typeof body.result === 'string' ? body.result : '';
      const score = typeof body.score === 'number' ? body.score : -1;
      const xp = typeof body.xp === 'number' ? body.xp : -1;
      const { data, error } = await admin.rpc('record_account_solo_game_result', {
        p_user_id: user.id, p_event_key: eventKey, p_result: result, p_score: score, p_xp: xp,
      });
      if (error) throw error;
      return response({ result: data });
    }

    if (action === 'grant_xp') {
      if (!isObject(body)) throw new Error('Invalid experience request.');
      const eventKey = typeof body.event_key === 'string' ? body.event_key : '';
      const amount = typeof body.amount === 'number' ? body.amount : -1;
      const { data, error } = await admin.rpc('grant_account_xp', {
        p_user_id: user.id, p_event_key: eventKey, p_amount: amount,
      });
      if (error) throw error;
      return response({ result: data });
    }

    return response({ error: 'Unsupported progress action.' }, 400);
  } catch (error) {
    console.error('player-progress error', error);
    return response({ error: error instanceof Error ? error.message : 'Unable to sync account progress.' }, 400);
  }
});
