-- supabase/migrations/003_app_ios.sql
-- App iOS: tema scelto, foto del corpo di lato e di spalle, retro dei capi.
-- Solo colonne nuove e facoltative: il sito attuale continua a funzionare.

alter table public.profiles
  add column if not exists theme text default 'system',
  -- { "side": "<uid>/<uuid>.jpg", "back": "<uid>/<uuid>.jpg" } nel bucket profile-photos
  add column if not exists body_photos jsonb;

alter table public.items
  add column if not exists photo_back_path text,
  add column if not exists photo_back_url text;

alter table public.wishlist_items
  add column if not exists photo_back_path text,
  add column if not exists photo_back_url text;
