/**
 * Try-on fotografico via Google Gemini (modello immagini "Nano Banana").
 * La chiamata parte direttamente dal browser con la chiave API dell'utente,
 * salvata solo in localStorage: nessun server nostro di mezzo (il sito è
 * statico su GitHub Pages). Chiave gratuita su https://aistudio.google.com/apikey
 */

const MODEL = 'gemini-2.5-flash-image';
const ENDPOINT = `https://generativelanguage.googleapis.com/v1beta/models/${MODEL}:generateContent`;

const STORAGE_KEY = 'sv_gemini_key';

export const getGeminiKey = () => {
  try {
    return localStorage.getItem(STORAGE_KEY) || '';
  } catch {
    return '';
  }
};

export const setGeminiKey = (key) => {
  try {
    if (key) localStorage.setItem(STORAGE_KEY, key.trim());
    else localStorage.removeItem(STORAGE_KEY);
  } catch {
    /* storage pieno o negato: la chiave varrà solo per la sessione corrente */
  }
};

/** Scompone un dataURL immagine in { mimeType, data } per l'API. */
export const parseDataUrl = (src) => {
  if (typeof src !== 'string') return null;
  const match = src.match(/^data:(image\/[a-z+.-]+);base64,(.+)$/i);
  if (!match) return null;
  return { mimeType: match[1], data: match[2] };
};

/**
 * Converte una foto (dataURL o URL remota) in inline part per Gemini.
 * Le foto dei capi demo e quelle su Supabase sono URL remote: si scaricano
 * e si ricodificano in base64 (fallisce se il sito del negozio blocca CORS).
 */
export async function toInlinePart(src) {
  const direct = parseDataUrl(src);
  if (direct) return direct;
  if (typeof src !== 'string' || !/^https?:/i.test(src)) return null;
  try {
    const res = await fetch(src);
    if (!res.ok) return null;
    const blob = await res.blob();
    const dataUrl = await new Promise((resolve, reject) => {
      const reader = new FileReader();
      reader.onload = () => resolve(reader.result);
      reader.onerror = reject;
      reader.readAsDataURL(blob);
    });
    return parseDataUrl(dataUrl);
  } catch {
    return null;
  }
}

/** Corpo della richiesta: prompt + foto della persona + foto dei capi. */
export const buildTryOnRequest = (personPart, items) => {
  const names = items.map((i) => i.name).join(', ');
  const prompt =
    `Virtual try-on. The first image is a person. Dress this exact person ` +
    `with the garments shown in the following images (${names}). ` +
    `Keep the person's face, hair, body shape, pose and background completely ` +
    `unchanged. Replace only their clothing with the provided garments, ` +
    `fitted naturally and photorealistically. Return only the edited photo.`;

  return {
    contents: [
      {
        parts: [
          { text: prompt },
          { inlineData: personPart },
          ...items.map((i) => ({ inlineData: i.part })),
        ],
      },
    ],
    generationConfig: { responseModalities: ['TEXT', 'IMAGE'] },
  };
};

/** Estrae la prima immagine dalla risposta come dataURL, o null. */
export const extractImageFromResponse = (json) => {
  const parts = json?.candidates?.[0]?.content?.parts || [];
  for (const part of parts) {
    const img = part.inlineData || part.inline_data;
    if (img?.data) {
      return `data:${img.mimeType || img.mime_type || 'image/png'};base64,${img.data}`;
    }
  }
  return null;
};

/**
 * Genera la foto vestita. Errori con `code` per i messaggi in UI:
 * missing-key | person-photo | no-garments | invalid-key | quota | network | no-image
 */
export async function generateTryOnPhoto({ apiKey, personPhoto, items }) {
  const fail = (code) => {
    const e = new Error(code);
    e.code = code;
    throw e;
  };

  if (!apiKey) fail('missing-key');
  const personPart = await toInlinePart(personPhoto);
  if (!personPart) fail('person-photo');

  const garmentParts = [];
  const skipped = [];
  for (const item of items) {
    const part = await toInlinePart(item.photo);
    if (part) garmentParts.push({ name: item.name, part });
    else skipped.push(item.name);
  }
  if (garmentParts.length === 0) fail('no-garments');

  let res;
  try {
    res = await fetch(ENDPOINT, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'x-goog-api-key': apiKey,
      },
      body: JSON.stringify(buildTryOnRequest(personPart, garmentParts)),
    });
  } catch {
    fail('network');
  }

  if (res.status === 400 || res.status === 401 || res.status === 403) {
    fail('invalid-key');
  }
  if (res.status === 429) fail('quota');
  if (!res.ok) fail('network');

  const json = await res.json();
  const image = extractImageFromResponse(json);
  if (!image) fail('no-image');

  return { image, skipped };
}
