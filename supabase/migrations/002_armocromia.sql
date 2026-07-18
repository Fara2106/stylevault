-- supabase/migrations/002_armocromia.sql
alter table public.profiles
  add column if not exists armocromia jsonb;
