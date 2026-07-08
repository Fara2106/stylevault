-- StyleVault — schema iniziale (Fase B)
-- Esegui questo file nel SQL Editor del progetto Supabase (o con `supabase db push`).
-- Ogni tabella ha Row Level Security: ogni utente vede solo le proprie righe.

-- ── Profili ────────────────────────────────────────────────────────────────
create table public.profiles (
  id uuid primary key references auth.users (id) on delete cascade,
  display_name text,
  language text default 'it',
  default_city jsonb,
  avatar_config jsonb,
  reference_photo_path text,
  onboarded boolean not null default false,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

create policy "profiles: own rows" on public.profiles
  for all using (auth.uid() = id) with check (auth.uid() = id);

-- ── Capi del guardaroba ────────────────────────────────────────────────────
create table public.items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  category text not null,
  subcategory text,
  brand text,
  size text,
  colors text[] not null default '{}',
  season text not null default 'all',
  occasion text not null default 'casual',
  warmth_level int not null default 2,
  photo_path text,   -- foto caricata su Storage (bucket wardrobe-photos)
  photo_url text,    -- oppure immagine esterna estratta dal link shop
  source_url text,
  price numeric,
  favorite boolean not null default false,
  created_at timestamptz not null default now()
);

create index items_user_idx on public.items (user_id);
alter table public.items enable row level security;

create policy "items: own rows" on public.items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── Wishlist ───────────────────────────────────────────────────────────────
create table public.wishlist_items (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  name text not null,
  category text,
  subcategory text,
  brand text,
  size text,
  colors text[] not null default '{}',
  season text not null default 'all',
  occasion text not null default 'casual',
  warmth_level int not null default 2,
  photo_path text,
  photo_url text,
  source_url text,
  price numeric,
  created_at timestamptz not null default now()
);

create index wishlist_user_idx on public.wishlist_items (user_id);
alter table public.wishlist_items enable row level security;

create policy "wishlist: own rows" on public.wishlist_items
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── Outfit salvati ─────────────────────────────────────────────────────────
-- payload = outfit completo (capi inclusi come snapshot jsonb): la UI lo rende
-- direttamente e sopravvive alla cancellazione di un capo.
create table public.outfits (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  occasion text,
  score int,
  item_ids text[] not null default '{}',
  payload jsonb not null,
  created_at timestamptz not null default now()
);

create index outfits_user_idx on public.outfits (user_id);
alter table public.outfits enable row level security;

create policy "outfits: own rows" on public.outfits
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── Calendario (pianificato/indossato) ─────────────────────────────────────
create table public.calendar_entries (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users (id) on delete cascade,
  date date not null,
  worn boolean not null default true,
  payload jsonb not null, -- snapshot dell'outfit
  created_at timestamptz not null default now()
);

create index calendar_user_date_idx on public.calendar_entries (user_id, date);
alter table public.calendar_entries enable row level security;

create policy "calendar: own rows" on public.calendar_entries
  for all using (auth.uid() = user_id) with check (auth.uid() = user_id);

-- ── Storage: bucket privati con policy per-utente ──────────────────────────
-- I percorsi dei file iniziano sempre con l'id utente: <uid>/<uuid>.jpg
insert into storage.buckets (id, name, public)
values ('wardrobe-photos', 'wardrobe-photos', false),
       ('profile-photos', 'profile-photos', false)
on conflict (id) do nothing;

create policy "storage: own files read" on storage.objects
  for select using (
    bucket_id in ('wardrobe-photos', 'profile-photos')
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "storage: own files write" on storage.objects
  for insert with check (
    bucket_id in ('wardrobe-photos', 'profile-photos')
    and auth.uid()::text = (storage.foldername(name))[1]
  );

create policy "storage: own files delete" on storage.objects
  for delete using (
    bucket_id in ('wardrobe-photos', 'profile-photos')
    and auth.uid()::text = (storage.foldername(name))[1]
  );

-- ── Profilo automatico alla registrazione ──────────────────────────────────
create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer set search_path = public
as $$
begin
  insert into public.profiles (id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data ->> 'name', split_part(new.email, '@', 1)));
  return new;
end;
$$;

create trigger on_auth_user_created
  after insert on auth.users
  for each row execute procedure public.handle_new_user();
