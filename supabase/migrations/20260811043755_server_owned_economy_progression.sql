-- Server-owned balances and idempotent reward/purchase ledgers.

create table if not exists public.player_hint_wallets (
  user_id uuid primary key references auth.users(id) on delete cascade,
  daily_move_remaining integer not null default 3 check (daily_move_remaining between 0 and 3),
  daily_letter_remaining integer not null default 3 check (daily_letter_remaining between 0 and 3),
  daily_strong_remaining integer not null default 1 check (daily_strong_remaining between 0 and 1),
  purchased_move integer not null default 0 check (purchased_move >= 0),
  purchased_letter integer not null default 0 check (purchased_letter >= 0),
  purchased_strong integer not null default 0 check (purchased_strong >= 0),
  ads_claimed_today integer not null default 0 check (ads_claimed_today between 0 and 3),
  reset_date date not null default (timezone('UTC', now()))::date,
  updated_at timestamptz not null default now()
);

create table if not exists public.letterloom_reward_events (
  user_id uuid not null references auth.users(id) on delete cascade,
  event_key text not null check (char_length(trim(event_key)) between 8 and 160),
  reward_type text not null,
  amount integer not null check (amount > 0),
  metadata jsonb not null default '{}'::jsonb,
  created_at timestamptz not null default now(),
  primary key (user_id, event_key)
);

create table if not exists public.letterloom_purchase_transactions (
  user_id uuid not null references auth.users(id) on delete cascade,
  provider text not null check (provider in ('google_play')),
  purchase_token text not null,
  product_id text not null,
  status text not null default 'fulfilled' check (status in ('fulfilled','revoked')),
  fulfilled_at timestamptz not null default now(),
  metadata jsonb not null default '{}'::jsonb,
  primary key (provider, purchase_token)
);

create table if not exists public.player_daily_return_claims (
  user_id uuid primary key references auth.users(id) on delete cascade,
  last_claim_date date,
  streak_days integer not null default 0 check (streak_days >= 0),
  updated_at timestamptz not null default now()
);

alter table public.player_daily_return_claims enable row level security;
revoke all on public.player_daily_return_claims from anon, authenticated;

alter table public.player_hint_wallets enable row level security;
alter table public.letterloom_reward_events enable row level security;
alter table public.letterloom_purchase_transactions enable row level security;
revoke all on public.player_hint_wallets from anon, authenticated;
revoke all on public.letterloom_reward_events from anon, authenticated;
revoke all on public.letterloom_purchase_transactions from anon, authenticated;

create or replace function public.letterloom_level_for_xp(p_xp integer)
returns integer
language plpgsql immutable
set search_path = public
as $$
declare v_level integer := 1;
begin
  while p_xp >= round(100 * v_level * v_level * 1.5) loop v_level := v_level + 1; end loop;
  return v_level;
end;
$$;

create or replace function public.consume_server_hint(p_user_id uuid, p_hint_type text)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_wallet public.player_hint_wallets%rowtype;
  v_source text;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then raise exception 'service role required'; end if;
  if p_hint_type not in ('move','letter','strong') then raise exception 'invalid hint type'; end if;
  insert into public.player_hint_wallets(user_id) values(p_user_id) on conflict do nothing;
  select * into v_wallet from public.player_hint_wallets where user_id=p_user_id for update;
  if v_wallet.reset_date <> (timezone('UTC', now()))::date then
    update public.player_hint_wallets set daily_move_remaining=3,daily_letter_remaining=3,daily_strong_remaining=1,ads_claimed_today=0,reset_date=(timezone('UTC',now()))::date,updated_at=now() where user_id=p_user_id returning * into v_wallet;
  end if;
  if p_hint_type='move' and v_wallet.daily_move_remaining>0 then update public.player_hint_wallets set daily_move_remaining=daily_move_remaining-1,updated_at=now() where user_id=p_user_id; v_source='daily';
  elsif p_hint_type='letter' and v_wallet.daily_letter_remaining>0 then update public.player_hint_wallets set daily_letter_remaining=daily_letter_remaining-1,updated_at=now() where user_id=p_user_id; v_source='daily';
  elsif p_hint_type='strong' and v_wallet.daily_strong_remaining>0 then update public.player_hint_wallets set daily_strong_remaining=daily_strong_remaining-1,updated_at=now() where user_id=p_user_id; v_source='daily';
  elsif p_hint_type='move' and v_wallet.purchased_move>0 then update public.player_hint_wallets set purchased_move=purchased_move-1,updated_at=now() where user_id=p_user_id; v_source='purchased';
  elsif p_hint_type='letter' and v_wallet.purchased_letter>0 then update public.player_hint_wallets set purchased_letter=purchased_letter-1,updated_at=now() where user_id=p_user_id; v_source='purchased';
  elsif p_hint_type='strong' and v_wallet.purchased_strong>0 then update public.player_hint_wallets set purchased_strong=purchased_strong-1,updated_at=now() where user_id=p_user_id; v_source='purchased';
  else return jsonb_build_object('granted',false,'reason','no_hints_available'); end if;
  return jsonb_build_object('granted',true,'source',v_source);
end;
$$;

create or replace function public.grant_verified_google_purchase(
  p_user_id uuid, p_purchase_token text, p_product_id text, p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_inserted integer; v_move integer := 0; v_letter integer := 0; v_strong integer := 0;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then raise exception 'service role required'; end if;
  if p_purchase_token is null or length(trim(p_purchase_token)) < 12 then raise exception 'invalid purchase token'; end if;
  if p_product_id='letterloom_hints_move_5' then v_move:=5;
  elsif p_product_id='letterloom_hints_letter_5' then v_letter:=5;
  elsif p_product_id='letterloom_hints_strong_3' then v_strong:=3;
  elsif p_product_id='letterloom_hints_mixed_bundle' then v_move:=5; v_letter:=5; v_strong:=2;
  else raise exception 'unknown product'; end if;
  insert into public.letterloom_purchase_transactions(user_id,provider,purchase_token,product_id,metadata)
  values(p_user_id,'google_play',p_purchase_token,p_product_id,p_metadata)
  on conflict (provider,purchase_token) do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted=0 then return jsonb_build_object('fulfilled',false,'reason','already_fulfilled'); end if;
  insert into public.player_hint_wallets(user_id) values(p_user_id) on conflict do nothing;
  update public.player_hint_wallets set purchased_move=purchased_move+v_move,purchased_letter=purchased_letter+v_letter,purchased_strong=purchased_strong+v_strong,updated_at=now() where user_id=p_user_id;
  return jsonb_build_object('fulfilled',true,'move',v_move,'letter',v_letter,'strong',v_strong);
end;
$$;

create or replace function public.grant_server_reward(
  p_user_id uuid, p_event_key text, p_reward_type text, p_amount integer, p_metadata jsonb default '{}'::jsonb
)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare v_inserted integer; v_xp integer; v_level integer;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then raise exception 'service role required'; end if;
  if p_amount < 1 or p_amount > 10000 then raise exception 'invalid reward amount'; end if;
  if p_reward_type not in ('move_hint','letter_hint','strong_hint','xp') then raise exception 'invalid reward type'; end if;
  insert into public.letterloom_reward_events(user_id,event_key,reward_type,amount,metadata)
  values(p_user_id,p_event_key,p_reward_type,p_amount,p_metadata)
  on conflict (user_id,event_key) do nothing;
  get diagnostics v_inserted = row_count;
  if v_inserted=0 then return jsonb_build_object('granted',false,'reason','already_granted'); end if;
  insert into public.player_hint_wallets(user_id) values(p_user_id) on conflict do nothing;
  if p_reward_type='move_hint' then update public.player_hint_wallets set purchased_move=purchased_move+p_amount,updated_at=now() where user_id=p_user_id;
  elsif p_reward_type='letter_hint' then update public.player_hint_wallets set purchased_letter=purchased_letter+p_amount,updated_at=now() where user_id=p_user_id;
  elsif p_reward_type='strong_hint' then update public.player_hint_wallets set purchased_strong=purchased_strong+p_amount,updated_at=now() where user_id=p_user_id;
  else
    update public.player_profiles set xp=xp+p_amount, level=public.letterloom_level_for_xp(xp+p_amount), updated_at=now() where id=p_user_id returning xp,level into v_xp,v_level;
  end if;
  return jsonb_build_object('granted',true,'reward_type',p_reward_type,'amount',p_amount,'xp',v_xp,'level',v_level);
end;
$$;

create or replace function public.claim_daily_return_reward(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_claim public.player_daily_return_claims%rowtype;
  v_today date := (timezone('UTC', now()))::date;
  v_streak integer;
  v_day integer;
  v_reward jsonb;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then raise exception 'service role required'; end if;
  insert into public.player_daily_return_claims(user_id) values(p_user_id) on conflict do nothing;
  select * into v_claim from public.player_daily_return_claims where user_id=p_user_id for update;
  if v_claim.last_claim_date = v_today then
    return jsonb_build_object('claimed',false,'streak_days',v_claim.streak_days);
  end if;
  v_streak := case when v_claim.last_claim_date = v_today-1 then v_claim.streak_days+1 else 1 end;
  v_day := ((v_streak - 1) % 7) + 1;
  update public.player_daily_return_claims set last_claim_date=v_today,streak_days=v_streak,updated_at=now() where user_id=p_user_id;
  if v_day in (1, 5) then
    v_reward := public.grant_server_reward(p_user_id,'daily_move:'||v_today::text,'move_hint',case when v_day=5 then 2 else 1 end,jsonb_build_object('source','daily_return','day',v_day));
  elsif v_day in (2, 6) then
    v_reward := public.grant_server_reward(p_user_id,'daily_letter:'||v_today::text,'letter_hint',case when v_day=6 then 2 else 1 end,jsonb_build_object('source','daily_return','day',v_day));
  elsif v_day = 3 then
    v_reward := public.grant_server_reward(p_user_id,'daily_strong:'||v_today::text,'strong_hint',1,jsonb_build_object('source','daily_return','day',v_day));
  else
    v_reward := public.grant_server_reward(p_user_id,'daily_xp:'||v_today::text,'xp',case when v_day=7 then 100 else 50 end,jsonb_build_object('source','daily_return','day',v_day));
  end if;
  return jsonb_build_object('claimed',true,'streak_days',v_streak,'day',v_day,'reward',v_reward);
end;
$$;

create or replace function public.daily_return_reward_status(p_user_id uuid)
returns jsonb
language plpgsql
security definer
set search_path = public
as $$
declare
  v_claim public.player_daily_return_claims%rowtype;
  v_today date := (timezone('UTC', now()))::date;
  v_next_streak integer;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then raise exception 'service role required'; end if;
  select * into v_claim from public.player_daily_return_claims where user_id=p_user_id;
  if v_claim.last_claim_date = v_today then
    return jsonb_build_object('claimable',false,'streak_days',v_claim.streak_days);
  end if;
  v_next_streak := case when v_claim.last_claim_date = v_today-1 then coalesce(v_claim.streak_days,0)+1 else 1 end;
  return jsonb_build_object('claimable',true,'streak_days',v_next_streak);
end;
$$;

revoke all on function public.letterloom_level_for_xp(integer) from public, anon, authenticated;
revoke all on function public.consume_server_hint(uuid,text) from public, anon, authenticated;
revoke all on function public.grant_verified_google_purchase(uuid,text,text,jsonb) from public, anon, authenticated;
revoke all on function public.grant_server_reward(uuid,text,text,integer,jsonb) from public, anon, authenticated;
revoke all on function public.claim_daily_return_reward(uuid) from public, anon, authenticated;
revoke all on function public.daily_return_reward_status(uuid) from public, anon, authenticated;
grant execute on function public.consume_server_hint(uuid,text) to service_role;
grant execute on function public.grant_verified_google_purchase(uuid,text,text,jsonb) to service_role;
grant execute on function public.grant_server_reward(uuid,text,text,integer,jsonb) to service_role;
grant execute on function public.claim_daily_return_reward(uuid) to service_role;
grant execute on function public.daily_return_reward_status(uuid) to service_role;

create index if not exists letterloom_reward_events_user_created_idx
  on public.letterloom_reward_events(user_id, created_at desc);
