-- ============================================================
-- Fix: on_auth_user_created trigger missing from fresh bootstraps
-- ============================================================
-- supabase/baseline.sql was extracted via `supabase db dump --schema
-- public,storage`, which cannot capture a trigger defined on auth.users
-- (originally created by 003_auth_and_subscriptions.sql) — that trigger
-- lives in the auth schema, outside the dump's scope. Since baseline.cut
-- folds migration 003 into the baseline (skipped on replay), a database
-- bootstrapped from baseline.sql + post-cut migrations never gets this
-- trigger, so no public.profiles row is ever created on signup.
--
-- Prod already has the real trigger (applied by 003 originally), so this
-- is idempotent there too: drop-if-exists + recreate is a no-op change.

drop trigger if exists on_auth_user_created on auth.users;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function public.handle_new_user();

-- Backfill: create profiles rows for any existing auth.users that predate
-- this fix (e.g. users who signed up on a self-hosted instance before the
-- trigger existed).
insert into public.profiles (id, email)
select u.id, u.email
from auth.users u
left join public.profiles p on p.id = u.id
where p.id is null;
