/**
 * Layer dati Supabase (Fase B).
 * Converte tra la forma degli oggetti dell'app (camelCase, `photo` pronta da
 * mostrare) e le righe del database (snake_case, foto come path su Storage).
 * Usato dai context solo quando isSupabaseEnabled è true.
 */
import { supabase } from './supabaseClient';

const SIGNED_URL_TTL = 60 * 60 * 24 * 6; // 6 giorni

// ── Foto su Storage ─────────────────────────────────────────────────────────

/** Carica un dataURL su Storage; ritorna il path salvato. */
export async function uploadPhoto(dataUrl, userId, bucket = 'wardrobe-photos') {
  const blob = await (await fetch(dataUrl)).blob();
  const path = `${userId}/${crypto.randomUUID()}.jpg`;
  const { error } = await supabase.storage
    .from(bucket)
    .upload(path, blob, { contentType: 'image/jpeg' });
  if (error) throw error;
  return path;
}

/** URL firmato per un singolo path (null se manca). */
export async function signedUrl(path, bucket = 'wardrobe-photos') {
  if (!path) return null;
  const { data, error } = await supabase.storage
    .from(bucket)
    .createSignedUrl(path, SIGNED_URL_TTL);
  if (error) return null;
  return data.signedUrl;
}

/** URL firmati in blocco: Map path -> url. */
async function signedUrlMap(paths, bucket = 'wardrobe-photos') {
  const unique = [...new Set(paths.filter(Boolean))];
  if (unique.length === 0) return new Map();
  const { data, error } = await supabase.storage
    .from(bucket)
    .createSignedUrls(unique, SIGNED_URL_TTL);
  if (error) return new Map();
  return new Map(data.map((d) => [d.path, d.signedUrl]));
}

export async function deletePhoto(path, bucket = 'wardrobe-photos') {
  if (!path) return;
  await supabase.storage.from(bucket).remove([path]);
}

// ── Mappers capo ────────────────────────────────────────────────────────────

function rowToItem(row, urls) {
  return {
    id: row.id,
    name: row.name,
    category: row.category,
    subcategory: row.subcategory || '',
    brand: row.brand || '',
    size: row.size || '',
    colors: row.colors || [],
    season: row.season,
    occasion: row.occasion,
    warmthLevel: row.warmth_level,
    photo: row.photo_path ? urls.get(row.photo_path) || '' : row.photo_url || '',
    photoPath: row.photo_path || null,
    sourceUrl: row.source_url || '',
    price: row.price,
    favorite: row.favorite ?? false,
    dateAdded: (row.created_at || '').split('T')[0],
  };
}

function itemToRow(item, userId) {
  return {
    user_id: userId,
    name: item.name,
    category: item.category,
    subcategory: item.subcategory || null,
    brand: item.brand || null,
    size: item.size || null,
    colors: item.colors || [],
    season: item.season || 'all',
    occasion: item.occasion || 'casual',
    warmth_level: item.warmthLevel ?? 2,
    photo_path: item.photoPath || null,
    photo_url: item.photoPath ? null : item.photo || null,
    source_url: item.sourceUrl || null,
    price: item.price ?? null,
    favorite: item.favorite ?? false,
  };
}

const outfitItemIds = (outfit) =>
  [outfit.top, outfit.bottom, outfit.shoes, outfit.outerwear, ...(outfit.accessories || [])]
    .filter(Boolean)
    .map((i) => i.id);

// ── Caricamento iniziale ────────────────────────────────────────────────────

/** Carica tutti i dati dell'utente e firma le URL delle foto. */
export async function fetchAllData(userId) {
  const [items, wishlist, outfits, calendar] = await Promise.all([
    supabase.from('items').select('*').order('created_at', { ascending: true }),
    supabase.from('wishlist_items').select('*').order('created_at', { ascending: true }),
    supabase.from('outfits').select('*').order('created_at', { ascending: true }),
    supabase.from('calendar_entries').select('*').order('created_at', { ascending: false }),
  ]);
  const firstError = items.error || wishlist.error || outfits.error || calendar.error;
  if (firstError) throw firstError;

  const allPaths = [...items.data, ...wishlist.data].map((r) => r.photo_path);
  const urls = await signedUrlMap(allPaths);

  return {
    items: items.data.map((r) => rowToItem(r, urls)),
    wishlist: wishlist.data.map((r) => rowToItem(r, urls)),
    savedOutfits: outfits.data.map((r) => ({
      ...r.payload,
      id: r.id,
      occasion: r.occasion,
      score: r.score ?? r.payload.score,
      savedAt: r.created_at,
    })),
    outfitHistory: calendar.data.map((r) => ({
      id: r.id,
      date: r.date,
      worn: r.worn,
      outfit: r.payload,
      timestamp: new Date(r.created_at).getTime(),
    })),
  };
}

// ── CRUD capi ───────────────────────────────────────────────────────────────

/**
 * Inserisce un capo. Se `item.photo` è un dataURL lo carica su Storage.
 * Ritorna il capo nella forma dell'app (photo = URL firmata).
 */
export async function insertItem(item, userId, table = 'items') {
  const prepared = { ...item };
  if (prepared.photo?.startsWith('data:')) {
    prepared.photoPath = await uploadPhoto(prepared.photo, userId);
  }
  const { data, error } = await supabase
    .from(table)
    .insert(itemToRow(prepared, userId))
    .select()
    .single();
  if (error) throw error;
  const urls = data.photo_path
    ? new Map([[data.photo_path, await signedUrl(data.photo_path)]])
    : new Map();
  return rowToItem(data, urls);
}

export async function updateItemRow(id, updates, userId, table = 'items') {
  const prepared = { ...updates };
  if (prepared.photo?.startsWith('data:')) {
    prepared.photoPath = await uploadPhoto(prepared.photo, userId);
  }
  const row = itemToRow(prepared, userId);
  const { error } = await supabase.from(table).update(row).eq('id', id);
  if (error) throw error;
  return prepared.photoPath ? await signedUrl(prepared.photoPath) : null;
}

export async function deleteItemRow(id, photoPath, table = 'items') {
  const { error } = await supabase.from(table).delete().eq('id', id);
  if (error) throw error;
  await deletePhoto(photoPath);
}

export async function setFavorite(id, favorite) {
  const { error } = await supabase.from('items').update({ favorite }).eq('id', id);
  if (error) throw error;
}

// ── Outfit salvati ──────────────────────────────────────────────────────────

export async function insertOutfit(outfit, userId) {
  const { data, error } = await supabase
    .from('outfits')
    .insert({
      user_id: userId,
      occasion: outfit.occasion || null,
      score: outfit.score ?? null,
      item_ids: outfitItemIds(outfit),
      payload: outfit,
    })
    .select('id, created_at')
    .single();
  if (error) throw error;
  return { id: data.id, savedAt: data.created_at };
}

export async function deleteOutfit(id) {
  const { error } = await supabase.from('outfits').delete().eq('id', id);
  if (error) throw error;
}

// ── Calendario ──────────────────────────────────────────────────────────────

export async function insertCalendarEntry(outfit, date, worn, userId) {
  const { data, error } = await supabase
    .from('calendar_entries')
    .insert({ user_id: userId, date, worn, payload: outfit })
    .select('id, created_at')
    .single();
  if (error) throw error;
  return { id: data.id, timestamp: new Date(data.created_at).getTime() };
}

export async function updateCalendarEntry(id, updates) {
  const row = {};
  if ('worn' in updates) row.worn = updates.worn;
  if ('date' in updates) row.date = updates.date;
  const { error } = await supabase.from('calendar_entries').update(row).eq('id', id);
  if (error) throw error;
}

export async function deleteCalendarEntry(id) {
  const { error } = await supabase.from('calendar_entries').delete().eq('id', id);
  if (error) throw error;
}

// ── Profilo ─────────────────────────────────────────────────────────────────

export async function fetchProfile(userId) {
  const { data, error } = await supabase
    .from('profiles')
    .select('*')
    .eq('id', userId)
    .maybeSingle();
  if (error) throw error;
  if (!data) return null;
  return {
    displayName: data.display_name,
    language: data.language,
    defaultCity: data.default_city,
    avatarConfig: data.avatar_config,
    referencePhoto: data.reference_photo_path
      ? await signedUrl(data.reference_photo_path, 'profile-photos')
      : null,
    referencePhotoPath: data.reference_photo_path,
    onboarded: data.onboarded,
  };
}

export async function upsertProfile(userId, updates) {
  const row = { id: userId, updated_at: new Date().toISOString() };
  if ('displayName' in updates) row.display_name = updates.displayName;
  if ('language' in updates) row.language = updates.language;
  if ('defaultCity' in updates) row.default_city = updates.defaultCity;
  if ('avatarConfig' in updates) row.avatar_config = updates.avatarConfig;
  if ('onboarded' in updates) row.onboarded = updates.onboarded;

  if ('referencePhoto' in updates) {
    if (updates.referencePhoto?.startsWith('data:')) {
      row.reference_photo_path = await uploadPhoto(
        updates.referencePhoto,
        userId,
        'profile-photos'
      );
    } else if (updates.referencePhoto === null) {
      row.reference_photo_path = null;
    }
  }

  const { error } = await supabase.from('profiles').upsert(row);
  if (error) throw error;
  return row.reference_photo_path
    ? await signedUrl(row.reference_photo_path, 'profile-photos')
    : null;
}
