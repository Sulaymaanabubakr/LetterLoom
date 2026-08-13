-- pg_cron schedules are evaluated in UTC. 08:00 UTC is 09:00 in Nigeria
-- during the app's current WAT timezone.
create extension if not exists pg_cron with schema extensions;
create extension if not exists pg_net with schema extensions;

select cron.unschedule(jobid)
from cron.job
where jobname = 'letterloom-daily-challenge-reminder';

select cron.schedule(
  'letterloom-daily-challenge-reminder',
  '0 8 * * *',
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
