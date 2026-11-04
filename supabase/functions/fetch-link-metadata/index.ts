// Edge Function: legge i metadati Open Graph di una pagina prodotto.
// Solo per utenti loggati (token della sessione) e solo verso pagine
// pubbliche (guard.ts): non è un proxy aperto verso la rete del server.
// Deploy dalla dashboard: l'editor non sa rinominare un secondo file, quindi
// si incolla un file solo con il contenuto di guard.ts al posto dell'import.
// Il client la usa al posto di microlink quando disponibile.
import { isPublicHttpUrl } from './guard.ts';

const CORS = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
};

function extract(html: string, property: string): string | null {
  // <meta property="og:image" content="..."> in entrambi gli ordini di attributi
  const patterns = [
    new RegExp(
      `<meta[^>]+(?:property|name)=["']${property}["'][^>]+content=["']([^"']+)["']`,
      'i'
    ),
    new RegExp(
      `<meta[^>]+content=["']([^"']+)["'][^>]+(?:property|name)=["']${property}["']`,
      'i'
    ),
  ];
  for (const re of patterns) {
    const match = html.match(re);
    if (match) return match[1];
  }
  return null;
}

/** Utente dal token della sessione (null se manca o è scaduto). */
async function isSignedIn(req: Request): Promise<boolean> {
  const auth = req.headers.get('Authorization') ?? '';
  const base = Deno.env.get('SUPABASE_URL');
  const key = req.headers.get('apikey') ?? Deno.env.get('SUPABASE_ANON_KEY');
  if (!auth.startsWith('Bearer ') || !base || !key) return false;
  const res = await fetch(`${base}/auth/v1/user`, { headers: { Authorization: auth, apikey: key } });
  if (!res.ok) return false;
  const user = await res.json();
  return typeof user?.id === 'string';
}

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }
  if (!(await isSignedIn(req))) {
    return new Response(JSON.stringify({ error: 'link-metadata-auth' }), {
      status: 401,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }

  try {
    const { url } = await req.json();
    if (!isPublicHttpUrl(url)) throw new Error('bad-url');
    const parsed = new URL(url);

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    // I redirect si seguono a mano (al massimo 5): anche ogni destinazione
    // deve essere una pagina pubblica
    let target = url;
    let res: Response | null = null;
    for (let hop = 0; hop < 6; hop++) {
      res = await fetch(target, {
        signal: controller.signal,
        redirect: 'manual',
        headers: {
          // Molti shop rispondono solo a user agent da browser
          'User-Agent':
            'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36',
          Accept: 'text/html',
        },
      });
      const location = res.headers.get('location');
      if (res.status < 300 || res.status >= 400 || !location) break;
      target = new URL(location, target).href;
      if (!isPublicHttpUrl(target)) throw new Error('bad-redirect');
      res = null;
    }
    clearTimeout(timer);
    if (!res) throw new Error('too-many-redirects');
    if (!res.ok) throw new Error(`http-${res.status}`);

    const html = (await res.text()).slice(0, 500_000);
    const title =
      extract(html, 'og:title') ||
      html.match(/<title[^>]*>([^<]+)<\/title>/i)?.[1]?.trim() ||
      '';
    const image = extract(html, 'og:image') || '';
    const site = extract(html, 'og:site_name') || parsed.hostname.replace('www.', '');

    return new Response(JSON.stringify({ title, image, site }), {
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  } catch (_e) {
    return new Response(JSON.stringify({ error: 'link-metadata-failed' }), {
      status: 422,
      headers: { ...CORS, 'Content-Type': 'application/json' },
    });
  }
});
