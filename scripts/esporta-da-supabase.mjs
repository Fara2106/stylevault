#!/usr/bin/env node
/**
 * Porta i dati di una persona dal vecchio sito all'app: scarica capi, desideri, outfit, calendario, profilo e
 * foto da Supabase e li scrive in uno zip nel formato di Profilo → Importa dell'app.
 *
 * Lo lancia Lorenzo, una volta per persona. La chiave service_role sta solo nell'ambiente e non va scritta da
 * nessuna parte:
 *   SUPABASE_URL=https://xxx.supabase.co SUPABASE_SERVICE_ROLE_KEY=... node scripts/esporta-da-supabase.mjs <id utente> [file.zip]
 * L'id utente è in Supabase → Authentication → Users. Legge soltanto: su Supabase non cambia nulla.
 */
import { randomUUID } from 'node:crypto';
import { writeFileSync } from 'node:fs';
import { fileURLToPath } from 'node:url';
import { deflateRawSync } from 'node:zlib';

const crcTable = Array.from({ length: 256 }, (_, n) => {
  let c = n;
  for (let k = 0; k < 8; k += 1) c = c & 1 ? 0xedb88320 ^ (c >>> 1) : c >>> 1;
  return c >>> 0;
});

function crc32(buffer) {
  let c = 0xffffffff;
  for (const byte of buffer) c = crcTable[(c ^ byte) & 255] ^ (c >>> 8);
  return (c ^ 0xffffffff) >>> 0;
}

/** Zip standard: il documento compresso, le foto come sono (sono già JPEG). */
export function makeZip(files) {
  const locals = [];
  const centrals = [];
  let offset = 0;
  for (const [name, content] of files) {
    const nameBytes = Buffer.from(name, 'utf8');
    const compress = name.endsWith('.json');
    const body = compress ? deflateRawSync(content) : content;
    const common = Buffer.alloc(26);
    common.writeUInt16LE(20, 0);
    common.writeUInt16LE(0x0800, 2);
    common.writeUInt16LE(compress ? 8 : 0, 4);
    common.writeUInt16LE(0, 6);
    common.writeUInt16LE(0x21, 8);
    common.writeUInt32LE(crc32(content), 10);
    common.writeUInt32LE(body.length, 14);
    common.writeUInt32LE(content.length, 18);
    common.writeUInt16LE(nameBytes.length, 22);
    const local = Buffer.concat([Buffer.from([0x50, 0x4b, 3, 4]), common, nameBytes, body]);
    // Commento, disco e attributi vuoti, poi la posizione dell'intestazione locale.
    const tail = Buffer.alloc(14);
    tail.writeUInt32LE(offset, 10);
    centrals.push(Buffer.concat([Buffer.from([0x50, 0x4b, 1, 2, 20, 0]), common, tail, nameBytes]));
    locals.push(local);
    offset += local.length;
  }
  const central = Buffer.concat(centrals);
  const end = Buffer.alloc(22);
  end.writeUInt32LE(0x06054b50, 0);
  end.writeUInt16LE(files.length, 8);
  end.writeUInt16LE(files.length, 10);
  end.writeUInt32LE(central.length, 12);
  end.writeUInt32LE(offset, 16);
  return Buffer.concat([...locals, central, end]);
}

/** I capi di un outfit salvato dal sito, ovunque stiano nel suo snapshot. */
export function outfitItemIds(payload = {}) {
  const pieces = [payload.top, payload.bottom, payload.shoes, payload.outerwear, payload.dress, ...(payload.accessories || [])];
  return [...new Set(pieces.filter(Boolean).map((piece) => (typeof piece === 'string' ? piece : piece.id)).filter(Boolean))];
}

const garment = (row, photos, withFavorite) => ({
  id: row.id,
  name: row.name,
  category: row.category,
  subcategory: row.subcategory ?? null,
  brand: row.brand ?? null,
  size: row.size ?? null,
  colors: row.colors ?? [],
  season: row.season ?? 'all',
  occasion: row.occasion ?? 'casual',
  warmthLevel: row.warmth_level ?? 2,
  sourceURL: row.source_url ?? null,
  price: row.price === null || row.price === undefined ? null : Number(row.price),
  favorite: withFavorite ? Boolean(row.favorite) : null,
  createdAt: row.created_at,
  photoFront: photos.front(row),
  photoBack: photos.back(row),
  cutout: null,
});

/** Dalle righe di Supabase al documento dell'app. `photos` dice in quale file finisce ogni foto. */
export function toBundle({ items, wishlist, outfits, calendar, profile }, photos, now = new Date()) {
  const city = profile?.default_city ?? null;
  const known = new Set(items.map((row) => row.id));
  const kept = (ids) => ids.filter((id) => known.has(id));
  return {
    version: 1,
    exportedAt: now.toISOString(),
    profile: profile
      ? {
          theme: profile.theme ?? 'system',
          cityName: city?.name ?? 'Milano',
          cityLatitude: city?.latitude ?? city?.lat ?? 45.4642,
          cityLongitude: city?.longitude ?? city?.lon ?? 9.19,
          cityCountry: city?.country ?? null,
          armocromia: profile.armocromia ? JSON.stringify(profile.armocromia) : null,
        }
      : null,
    items: items.map((row) => garment(row, photos, true)),
    wishlist: wishlist.map((row) => garment(row, photos, false)),
    // Il sito teneva i nomi solo nel browser: restano i capi, con un nome da cambiare a mano.
    customCategories: [...new Set(items.map((row) => row.category).filter((id) => id.startsWith('custom')))].map((id, index) => ({
      id,
      name: `Categoria ${index + 1}`,
      createdAt: now.toISOString(),
    })),
    outfits: outfits.map((row) => ({
      id: row.id,
      occasion: row.occasion ?? null,
      score: row.score ?? null,
      itemIDs: kept(row.item_ids?.length ? row.item_ids : outfitItemIds(row.payload)),
      createdAt: row.created_at,
    })),
    calendar: calendar.map((row) => ({
      id: row.id,
      day: row.date,
      worn: row.worn,
      outfitID: null,
      itemIDs: kept(outfitItemIds(row.payload)),
      createdAt: row.created_at,
    })),
    bodyPhotos: photos.body(profile),
  };
}

async function run(userID, output) {
  const url = process.env.SUPABASE_URL?.replace(/\/$/, '');
  const key = process.env.SUPABASE_SERVICE_ROLE_KEY;
  if (!url || !key || !userID) {
    console.error('Uso: SUPABASE_URL=... SUPABASE_SERVICE_ROLE_KEY=... node scripts/esporta-da-supabase.mjs <id utente> [file.zip]');
    process.exit(1);
  }
  const headers = { apikey: key, Authorization: `Bearer ${key}` };
  const table = async (name, filter) => {
    const response = await fetch(`${url}/rest/v1/${name}?${filter}&select=*&order=created_at.asc`, { headers });
    if (!response.ok) throw new Error(`${name}: ${response.status}`);
    return response.json();
  };
  const ofUser = `user_id=eq.${userID}`;
  const [items, wishlist, outfits, calendar, profiles] = await Promise.all([
    table('items', ofUser), table('wishlist_items', ofUser), table('outfits', ofUser),
    table('calendar_entries', ofUser), table('profiles', `id=eq.${userID}`),
  ]);

  const files = new Map();
  const missing = [];
  const fetchTo = async (name, address, withKey) => {
    try {
      const response = await fetch(address, withKey ? { headers } : {});
      if (!response.ok) throw new Error(String(response.status));
      files.set(name, Buffer.from(await response.arrayBuffer()));
    } catch (error) {
      missing.push(`${name}: ${error.message}`);
    }
  };
  const planned = [];
  const plan = (id, side, path, external, bucket) => {
    if (!path && !external) return null;
    const name = `photos/${id}-${side}.jpg`;
    planned.push(path ? [name, `${url}/storage/v1/object/${bucket}/${path}`, true] : [name, external, false]);
    return name;
  };
  const photos = {
    front: (row) => plan(row.id, 'front', row.photo_path, row.photo_url, 'wardrobe-photos'),
    back: (row) => plan(row.id, 'back', row.photo_back_path, row.photo_back_url, 'wardrobe-photos'),
    body: (profile) => {
      const paths = { front: profile?.reference_photo_path, ...(profile?.body_photos ?? {}) };
      return Object.entries(paths).flatMap(([kind, path]) => {
        const file = plan('body', kind, path, null, 'profile-photos');
        return file ? [{ kind, file }] : [];
      });
    },
  };
  const bundle = toBundle({ items, wishlist, outfits, calendar, profile: profiles[0] ?? null }, photos);
  for (let start = 0; start < planned.length; start += 6) {
    await Promise.all(planned.slice(start, start + 6).map(([name, address, withKey]) => fetchTo(name, address, withKey)));
  }
  // Una foto non scaricata non deve restare citata nel documento.
  for (const list of [bundle.items, bundle.wishlist]) {
    for (const row of list) {
      if (row.photoFront && !files.has(row.photoFront)) row.photoFront = null;
      if (row.photoBack && !files.has(row.photoBack)) row.photoBack = null;
    }
  }
  bundle.bodyPhotos = bundle.bodyPhotos.filter((photo) => files.has(photo.file));

  const name = output ?? `StyleVault-${randomUUID().slice(0, 8)}.zip`;
  writeFileSync(name, makeZip([['stylevault-export.json', Buffer.from(JSON.stringify(bundle, null, 2))], ...files]));
  console.log(`${name}: ${items.length} capi, ${wishlist.length} desideri, ${outfits.length} outfit, `
    + `${calendar.length} giorni, ${files.size} foto.`);
  if (missing.length) console.log(`Foto non scaricate (${missing.length}):\n${missing.join('\n')}`);
}

if (process.argv[1] === fileURLToPath(import.meta.url)) {
  run(process.argv[2], process.argv[3]).catch((error) => {
    console.error(`Esportazione non riuscita: ${error.message}`);
    process.exit(1);
  });
}
