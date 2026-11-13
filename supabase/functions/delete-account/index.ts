// Edge Function: cancella l'account di chi la chiama (Apple 5.1.1(v), GDPR).
// Toglie i file dell'utente da `wardrobe-photos` e `profile-photos`, poi
// l'utente di autenticazione: le tabelle (profili, capi, outfit, calendario,
// wishlist) si svuotano da sole con `on delete cascade` su auth.users.
// Deploy: dalla dashboard (Edge Functions → Via Editor). L'editor non sa
// rinominare un secondo file: si incolla un file solo, con il contenuto di
// account.ts al posto dell'import (così è stata pubblicata il 04/11).
// "Verify JWT" acceso va bene: il token dell'utente passa, e
// l'utente lo ricontrolla comunque la funzione dal token della sessione.
// Usa la chiave segreta che Supabase mette nell'ambiente delle funzioni.
import { chunks, isConfirmed, listUserFiles, type ListEntry } from './account.ts';

const BUCKETS = ['wardrobe-photos', 'profile-photos'];

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function reply(status: number, body: Record<string, unknown>) {
  return new Response(JSON.stringify(body), {
    status,
    headers: { ...CORS, 'Content-Type': 'application/json' },
  });
}

/** Chiave con i permessi di amministrazione (legacy service_role o sb_secret_…). */
function adminKey(): string | null {
  const legacy = Deno.env.get('SUPABASE_SERVICE_ROLE_KEY');
  if (legacy) return legacy;
  try {
    const keys = JSON.parse(Deno.env.get('SUPABASE_SECRET_KEYS') ?? '{}');
    return (Object.values(keys)[0] as string) ?? null;
  } catch {
    return null;
  }
}

/** Utente dal token della sessione (null se manca o è scaduto). */
async function currentUserId(req: Request, url: string): Promise<string | null> {
  const auth = req.headers.get('Authorization') ?? '';
  const key = req.headers.get('apikey') ?? Deno.env.get('SUPABASE_ANON_KEY');
  if (!auth.startsWith('Bearer ') || !key) return null;
  const res = await fetch(`${url}/auth/v1/user`, { headers: { Authorization: auth, apikey: key } });
  if (!res.ok) return null;
  const user = await res.json();
  return typeof user?.id === 'string' ? user.id : null;
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') return new Response('ok', { headers: CORS });
  if (req.method !== 'POST') return reply(405, { error: 'delete-invalid' });

  const url = Deno.env.get('SUPABASE_URL');
  const key = adminKey();
  if (!url || !key) return reply(500, { error: 'delete-failed' });

  const userId = await currentUserId(req, url);
  if (!userId) return reply(401, { error: 'delete-auth' });
  if (!isConfirmed(await req.json().catch(() => null))) return reply(400, { error: 'delete-invalid' });

  // Le chiavi nuove (sb_secret_…) vanno solo in `apikey`: il gateway le
  // trasforma da sé in un token service_role. La legacy è un JWT e va anche
  // in Authorization.
  const admin: Record<string, string> = key.startsWith('sb_')
    ? { apikey: key, 'Content-Type': 'application/json' }
    : { apikey: key, Authorization: `Bearer ${key}`, 'Content-Type': 'application/json' };

  try {
    // 1. I file: prima dell'utente, perché dopo nessuno li collegherebbe più a lui
    for (const bucket of BUCKETS) {
      const list = async (prefix: string, offset: number): Promise<ListEntry[]> => {
        const res = await fetch(`${url}/storage/v1/object/list/${bucket}`, {
          method: 'POST',
          headers: admin,
          // La cartella senza la barra finale, come la manda supabase-js
          body: JSON.stringify({ prefix: prefix.replace(/\/$/, ''), limit: 1000, offset }),
        });
        if (!res.ok) throw new Error(`list-${res.status}`);
        return await res.json();
      };
      const files = await listUserFiles(list, userId);
      for (const group of chunks(files, 100)) {
        const res = await fetch(`${url}/storage/v1/object/${bucket}`, {
          method: 'DELETE',
          headers: admin,
          body: JSON.stringify({ prefixes: group }),
        });
        if (!res.ok) throw new Error(`remove-${res.status}`);
      }
    }

    // 2. L'utente: le sue righe nelle tabelle se ne vanno in cascata
    const res = await fetch(`${url}/auth/v1/admin/users/${userId}`, { method: 'DELETE', headers: admin });
    if (!res.ok) throw new Error(`user-${res.status}`);
  } catch (error) {
    // Nei log solo il passo fallito, nessun dato dell'utente
    console.error('delete-account', (error as Error).message);
    return reply(502, { error: 'delete-failed' });
  }
  return reply(200, { ok: true });
});
