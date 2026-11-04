// Filtro dei link (testato in index_test.ts): la funzione legge solo pagine
// pubbliche, mai indirizzi della rete interna del server (SSRF).

const PRIVATE_V4 = [
  /^0\./,
  /^10\./,
  /^127\./,
  /^169\.254\./,
  /^172\.(1[6-9]|2\d|3[01])\./,
  /^192\.168\./,
  /^100\.(6[4-9]|[7-9]\d|1[01]\d|12[0-7])\./, // CGNAT
];

/** true solo per http(s) verso un nome di dominio pubblico o un IPv4 pubblico. */
export function isPublicHttpUrl(raw: string): boolean {
  let url: URL;
  try {
    url = new URL(raw);
  } catch {
    return false;
  }
  if (url.protocol !== 'http:' && url.protocol !== 'https:') return false;
  const host = url.hostname.toLowerCase();
  if (host.startsWith('[') || host.includes(':')) return false; // IPv6 letterali: non servono ai negozi
  if (/^\d+\.\d+\.\d+\.\d+$/.test(host)) return !PRIVATE_V4.some((re) => re.test(host));
  // Un nome senza punto (intranet) o di rete locale
  if (!host.includes('.')) return false;
  if (/\.(local|localhost|internal|lan|home|corp)$/.test(host)) return false;
  return true;
}
