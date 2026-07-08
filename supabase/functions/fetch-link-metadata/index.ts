// Edge Function: legge i metadati Open Graph di una pagina prodotto.
// Deploy: `supabase functions deploy fetch-link-metadata --no-verify-jwt`
// (o dalla dashboard). Il client la usa al posto di microlink quando disponibile.

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

Deno.serve(async (req) => {
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: CORS });
  }

  try {
    const { url } = await req.json();
    const parsed = new URL(url);
    if (!['http:', 'https:'].includes(parsed.protocol)) throw new Error('bad-url');

    const controller = new AbortController();
    const timer = setTimeout(() => controller.abort(), 8000);
    const res = await fetch(url, {
      signal: controller.signal,
      headers: {
        // Molti shop rispondono solo a user agent da browser
        'User-Agent':
          'Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/126.0 Safari/537.36',
        Accept: 'text/html',
      },
    });
    clearTimeout(timer);
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
