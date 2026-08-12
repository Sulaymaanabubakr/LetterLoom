-- The cron credential is provisioned into both Supabase Vault and the Edge
-- Function environment outside source control. Fail closed if it is absent.
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

do $$
begin
  if not exists (select 1 from vault.secrets where name = 'letterloom_daily_reminder_secret') then
    raise exception 'The daily reminder Vault secret must be provisioned before this migration runs.';
  end if;
end;
$$;

select cron.unschedule(jobid)
from cron.job
where jobname = 'letterloom-daily-challenge-reminder';

select cron.schedule(
  'letterloom-daily-challenge-reminder',
  '0 9 * * *',
  $job$
    select net.http_post(
      url := (select decrypted_secret from vault.decrypted_secrets where name = 'letterloom_project_url') || '/functions/v1/daily-notification-reminders',
      headers := jsonb_build_object(
        'Content-Type', 'application/json',
        'x-letterloom-cron-secret', (select decrypted_secret from vault.decrypted_secrets where name = 'letterloom_daily_reminder_secret')
      ),
      body := jsonb_build_object('source', 'scheduled-daily-reminder')
    );
  $job$
);
