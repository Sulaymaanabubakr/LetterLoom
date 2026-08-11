alter table public.ranked_queue
  add column if not exists expires_at timestamptz;

create index if not exists ranked_queue_expiry_idx
  on public.ranked_queue (expires_at)
  where status in ('waiting', 'matching');

create or replace function public.claim_ranked_opponent(p_user_id uuid)
returns table(opponent_user_id uuid, opponent_rating integer, opponent_display_name text)
language plpgsql security definer set search_path = public
as $$
declare
  v_rating integer;
  v_opponent ranked_queue%rowtype;
begin
  if not pg_has_role(current_user, 'service_role', 'member') then
    raise exception 'service role required';
  end if;
  update ranked_queue set status = 'cancelled', updated_at = now()
    where status in ('waiting', 'matching') and expires_at is not null and expires_at <= now();
  select rating into v_rating from ranked_queue
    where user_id = p_user_id and status = 'waiting' and (expires_at is null or expires_at > now()) for update;
  if v_rating is null then return; end if;

  select * into v_opponent from ranked_queue q
    where q.status = 'waiting' and q.user_id <> p_user_id
      and (q.expires_at is null or q.expires_at > now())
      and abs(q.rating - v_rating) <= 200
    order by abs(q.rating - v_rating), q.created_at
    limit 1 for update skip locked;
  if not found then return; end if;

  update ranked_queue set status = 'matching', updated_at = now()
    where user_id in (p_user_id, v_opponent.user_id);
  return query select v_opponent.user_id, v_opponent.rating, v_opponent.display_name;
end;
$$;
