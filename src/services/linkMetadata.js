/**
 * Estrazione metadati da un link di shop online (Fase A).
 * Usa l'API pubblica di microlink.io (CORS aperto, piano gratuito):
 * legge i metadati Open Graph della pagina prodotto.
 * In Fase B verrà sostituita da una Edge Function Supabase.
 */

const MICROLINK_URL = 'https://api.microlink.io/';

/**
 * @param {string} url - Link alla pagina prodotto
 * @returns {Promise<{title: string, image: string, site: string}>}
 * @throws {Error} 'link-metadata-failed' se la pagina non è leggibile
 */
export async function fetchLinkMetadata(url) {
  let res;
  try {
    res = await fetch(`${MICROLINK_URL}?url=${encodeURIComponent(url)}`);
  } catch (networkError) {
    throw new Error('link-metadata-failed', { cause: networkError });
  }
  if (!res.ok) throw new Error('link-metadata-failed');

  const data = await res.json();
  if (data.status !== 'success' || !data.data) {
    throw new Error('link-metadata-failed');
  }

  return {
    title: data.data.title || '',
    image: data.data.image?.url || data.data.logo?.url || '',
    site: data.data.publisher || '',
  };
}

/** Validazione superficiale di un URL http(s). */
export function isValidHttpUrl(value) {
  try {
    const parsed = new URL(value);
    return parsed.protocol === 'http:' || parsed.protocol === 'https:';
  } catch {
    return false;
  }
}
