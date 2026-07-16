/**
 * Guscio browser per la modalità "Su modello": porta le immagini in canvas e
 * chiama la logica pura (personSilhouette, modelComposer). Qui vivono solo
 * I/O e ritagli; niente geometria.
 *
 * La foto della persona passa dallo stesso scontorno @imgly dei capi e dalla
 * stessa cache IndexedDB, con l'id riservato `__person__`: se la foto di
 * riferimento cambia, la chiave (id+hash foto) cambia e si riscontorna.
 */
import { removeGarmentBackground } from './backgroundRemoval';
import { getCachedCutout, putCachedCutout } from './garmentCutoutCache';
import { analyzeSilhouette, garmentContentBounds } from './personSilhouette';
import { segmentBody, detectPose, SEG_CLOTHES, SEG_BODY_SKIN } from './bodyAnalysis';
import {
  imageRows,
  classRowSpans,
  classRuns,
  nearestRunSpan,
  polylineX,
  smoothSpans,
  garmentLegSplit,
  topWarpPlan,
  bottomWarpPlan,
} from './modelWarp';

const loadImage = (src) =>
  new Promise((resolve, reject) => {
    const img = new Image();
    img.crossOrigin = 'anonymous';
    img.onload = () => resolve(img);
    img.onerror = () => reject(new Error('load'));
    img.src = src;
  });

const readImageData = (img) => {
  const canvas = document.createElement('canvas');
  canvas.width = img.naturalWidth;
  canvas.height = img.naturalHeight;
  const ctx = canvas.getContext('2d', { willReadFrequently: true });
  ctx.drawImage(img, 0, 0);
  return ctx.getImageData(0, 0, canvas.width, canvas.height);
};

/** Scontorno della persona, cachato. @returns {Promise<string>} dataURL PNG. */
export async function loadPersonCutout(photo) {
  const pseudoItem = { id: '__person__', photo };
  let url = await getCachedCutout(pseudoItem);
  if (!url) {
    url = await removeGarmentBackground(photo);
    await putCachedCutout(pseudoItem, url);
  }
  return url;
}

/**
 * Landmark del corpo dal PNG scontornato della persona.
 * @returns {Promise<{person:object, width:number, height:number}|null>}
 *          null se nella foto non si distingue una figura.
 */
export async function analyzePersonImage(cutoutUrl) {
  const img = await loadImage(cutoutUrl);
  const person = analyzeSilhouette(readImageData(img));
  if (!person) return null;
  return { person, width: img.naturalWidth, height: img.naturalHeight };
}

/**
 * Ritaglia il PNG scontornato del capo al suo contenuto: il riquadro dei pixel
 * opachi, senza i margini trasparenti che @imgly lascia attorno (la foto intera
 * meno lo sfondo) e senza il gancio della gruccia (garmentContentBounds).
 * Serve il rapporto larghezza/altezza VERO del capo.
 * @returns {Promise<{url:string, aspect:number}|null>}
 */
export async function trimmedGarment(cutoutUrl) {
  const img = await loadImage(cutoutUrl);
  let imageData;
  try {
    imageData = readImageData(img);
  } catch {
    // dataURL nostro o foto senza CORS: in quest'ultimo caso niente ritaglio,
    // si usa la foto com'è (il chiamante decide).
    return null;
  }
  const b = garmentContentBounds(imageData);
  if (!b) return null;
  const w = b.right - b.left + 1;
  const h = b.bottom - b.top + 1;
  const out = document.createElement('canvas');
  out.width = w;
  out.height = h;
  out.getContext('2d').drawImage(img, b.left, b.top, w, h, 0, 0, w, h);
  return { url: out.toDataURL('image/png'), aspect: w / h };
}

/** Rapporto larghezza/altezza di un'immagine qualunque (per i ripieghi senza scontorno). */
export async function imageAspect(url) {
  const img = await loadImage(url);
  return img.naturalWidth / img.naturalHeight;
}

/* ── Warping sulla persona vera (passo 1+2: segmentazione + posa) ────────── */

/** Analisi ML della foto (una volta per foto: modelli e risultato cachati). */
const bodyCache = new Map();
export function analyzeBodyCached(photo) {
  if (!bodyCache.has(photo)) {
    bodyCache.set(
      photo,
      Promise.all([segmentBody(photo), detectPose(photo)]).then(([seg, pose]) => ({ seg, pose }))
    );
  }
  return bodyCache.get(photo);
}

const firstIndex = (rows) => rows.findIndex(Boolean);
const lastIndex = (rows) => {
  for (let y = rows.length - 1; y >= 0; y--) if (rows[y]) return y;
  return -1;
};

/** Larghezza media degli span nelle righe [y0, y1]. */
const meanWidth = (spans, y0, y1) => {
  let sum = 0;
  let n = 0;
  for (let y = Math.round(y0); y <= Math.round(y1); y++) {
    if (spans[y]) {
      sum += spans[y].right - spans[y].left + 1;
      n++;
    }
  }
  return n > 0 ? sum / n : 0;
};

/** Span allargati di una frazione (per il capospalla, che sta SOPRA il top). */
const expandSpans = (spans, factor) =>
  spans.map((s) =>
    s
      ? (() => {
          const grow = ((s.right - s.left + 1) * (factor - 1)) / 2;
          return { left: Math.round(s.left - grow), right: Math.round(s.right + grow) };
        })()
      : null
  );

/** Esegue un piano di warping su canvas grande quanto la foto della persona. */
const renderPlan = (garmentImg, plan, outWidth, outHeight) => {
  const out = document.createElement('canvas');
  out.width = outWidth;
  out.height = outHeight;
  const ctx = out.getContext('2d');
  for (const r of plan) {
    ctx.drawImage(garmentImg, r.sx0, r.ys, r.sw, 1, r.dx0, r.yd, r.dw, 1);
  }
  return out.toDataURL('image/png');
};

/**
 * Livelli warpati per la scena "Su di te": ogni capo deformato riga per riga
 * sulla sagoma vestita e sulla posa della persona. Richiede almeno una delle
 * due analisi ML; null = il chiamante usa i rettangoli classici.
 *
 * @returns {Promise<{layers:{kind:string,url:string}[],
 *                    shoes:{kind:string,x:number,y:number,width:number,height:number}[]}|null>}
 */
export async function buildWarpedLayers({ photo, cutoutUrl, person, assets }) {
  const { seg: rawSeg, pose } = await analyzeBodyCached(photo);
  const cutImg = await loadImage(cutoutUrl);
  const W = cutImg.naturalWidth;
  const H = cutImg.naturalHeight;
  // maschera di dimensioni inattese = inaffidabile, meglio ignorarla
  const seg = rawSeg && rawSeg.width === W && rawSeg.height === H ? rawSeg : null;
  if (!seg && !pose) return null;

  const cutData = readImageData(cutImg);
  const silRows = imageRows(cutData);
  const axis = person.cx;
  const bodyH = person.box.height;

  const clothesSpans = seg
    ? smoothSpans(classRowSpans(seg, [SEG_CLOTHES], axis), 5)
    : new Array(H).fill(null);
  const silSpans = smoothSpans(
    silRows.map((r) => (r ? nearestRunSpan(r.runs, axis) : null)),
    3
  );
  // La maschera può sbordare di qualche pixel: mai oltre la sagoma della persona.
  const clampToBody = (s, y) => {
    const sil = silRows[y];
    if (!s || !sil) return s;
    const left = Math.max(s.left, sil.left);
    const right = Math.min(s.right, sil.right);
    return left <= right ? { left, right } : null;
  };
  // destinazione del busto: i vestiti indossati, con la silhouette a tappare i buchi
  const torsoSpans = clothesSpans.map((s, y) => clampToBody(s, y) || silSpans[y] || null);

  // ── ancore verticali (posa se c'è, sennò silhouette) ──
  const shoulderY =
    pose && pose.shoulderL.visible && pose.shoulderR.visible
      ? Math.round(Math.min(pose.shoulderL.y, pose.shoulderR.y))
      : person.shoulders.y;
  let collarY = null;
  for (
    let y = Math.round(shoulderY - 0.12 * bodyH);
    y <= Math.round(shoulderY + 0.06 * bodyH);
    y++
  ) {
    if (clothesSpans[y]) {
      collarY = y;
      break;
    }
  }
  if (collarY === null) collarY = Math.round(shoulderY - 0.04 * bodyH);

  // Nella zona del colletto lo span dei vestiti è stretto (il girocollo del
  // capo indossato) mentre poche righe sotto ci sono già le spalle piene: se
  // il capo nuovo si adattasse allo span stretto, le spalle del capo vecchio
  // spunterebbero ai lati. Nella sola zona del colletto ogni riga guarda
  // anche un po' PIÙ GIÙ e prende l'unione: le spalle del capo nuovo coprono
  // quelle del vecchio.
  const lookahead = Math.round(0.05 * bodyH);
  const collarZoneEnd = collarY + Math.round(0.12 * bodyH);
  const topDestSpans = torsoSpans.map((s, y) => {
    if (!s || y > collarZoneEnd) return s;
    let { left, right } = s;
    for (let k = y; k <= y + lookahead && k < torsoSpans.length; k++) {
      const o = torsoSpans[k];
      if (!o) continue;
      if (o.left < left) left = o.left;
      if (o.right > right) right = o.right;
    }
    return { left, right };
  });

  const crotchY = person.crotchY;
  const kneeY =
    pose && pose.kneeL.visible && pose.kneeR.visible
      ? Math.round((pose.kneeL.y + pose.kneeR.y) / 2)
      : Math.round(person.box.top + 0.72 * bodyH);
  const ankleY =
    pose && pose.ankleL.visible && pose.ankleR.visible
      ? Math.round(Math.max(pose.ankleL.y, pose.ankleR.y) + 0.02 * bodyH)
      : person.ankleY;

  const readGarment = async (url) => {
    const img = await loadImage(url);
    const data = readImageData(img);
    const rows = imageRows(data);
    return { img, rows, box: { top: firstIndex(rows), bottom: lastIndex(rows) } };
  };

  const layers = [];

  // ── pantaloni / gonna: prima, il top ci va sopra ──
  if (assets.bottom) {
    const g = await readGarment(assets.bottom.url);
    const legSplit = garmentLegSplit(g.rows, g.img.naturalWidth);
    const waistY = Math.round(crotchY - 0.13 * bodyH);

    // orlo proporzionale al capo (gli shorts non arrivano alle caviglie):
    // scala = larghezza in vita della persona / larghezza in vita del capo
    const gH = g.box.bottom - g.box.top + 1;
    const gRowSpans = g.rows.map((r) => (r ? { left: r.left, right: r.right } : null));
    const gWaistW = meanWidth(gRowSpans, g.box.top, g.box.top + gH * 0.08);
    const destWaistW = meanWidth(torsoSpans, waistY, waistY + 0.04 * bodyH);
    const scale = gWaistW > 0 ? destWaistW / gWaistW : 1;
    let hemY = waistY + Math.round(gH * scale);
    hemY = Math.max(crotchY + Math.round(0.05 * bodyH), Math.min(hemY, ankleY));

    let legLSpans = [];
    let legRSpans = [];
    if (legSplit && pose) {
      // gambe visive: coppie anca/ginocchio/caviglia ordinate per x
      const sides = [
        [pose.hipL, pose.kneeL, pose.ankleL],
        [pose.hipR, pose.kneeR, pose.ankleR],
      ].sort((a, b) => a[0].x - b[0].x);
      // SOLO vestiti: la mano che pende lungo la coscia è "pelle" e, se
      // inclusa, allarga la gamba dei pantaloni proprio all'altezza della
      // mano (gradino visibile). Gambe nude (pantaloncini in foto): si
      // ripiega sulla corsa della silhouette vicino alla gamba.
      const legRuns = seg ? classRuns(seg, [SEG_CLOTHES]) : silRows.map((r) => (r ? r.runs : null));
      const silLegRuns = silRows.map((r) => (r ? r.runs : null));
      const hipW = person.hips.width;
      // Se le cosce si toccano la corsa è UNA per tutt'e due le gambe: va
      // divisa a metà strada fra le due polilinee, sennò ogni gamba del capo
      // verrebbe stirata sull'intera larghezza (e disegnata due volte).
      const spansFor = (polyThis, polyOther) => {
        const spans = [];
        for (let y = crotchY + 1; y <= hemY; y++) {
          const lx = polylineX(polyThis, y);
          const ox = polylineX(polyOther, y);
          let span = nearestRunSpan(legRuns[y], lx) || nearestRunSpan(silLegRuns[y], lx);
          if (span && span.left <= ox && ox <= span.right) {
            const mid = Math.round((lx + ox) / 2);
            span = lx < ox ? { left: span.left, right: mid } : { left: mid + 1, right: span.right };
          }
          spans[y] = span
            ? clampToBody(span, y)
            : {
                left: Math.round(lx - hipW * 0.17),
                right: Math.round(lx + hipW * 0.17),
              };
        }
        return smoothSpans(spans, 3);
      };
      const polyA = sides[0].map((p) => ({ x: p.x, y: p.y }));
      const polyB = sides[1].map((p) => ({ x: p.x, y: p.y }));
      legLSpans = spansFor(polyA, polyB);
      legRSpans = spansFor(polyB, polyA);
    }
    const plan = bottomWarpPlan({
      garmentRows: g.rows,
      garmentBox: g.box,
      legSplit,
      waistY,
      crotchY,
      ankleY: hemY,
      trunkSpans: torsoSpans,
      legLSpans,
      legRSpans,
    });
    layers.push({ kind: 'bottom', url: renderPlan(g.img, plan, W, H) });
  }

  // ── top / abito ──
  const topAsset = assets.dress || assets.top;
  if (topAsset) {
    const isDress = Boolean(assets.dress);
    const g = await readGarment(topAsset.url);
    // scala di lunghezza: rapporto fra larghezza "alle spalle" del capo e della persona
    const gRowSpans = g.rows.map((r) => (r ? { left: r.left, right: r.right } : null));
    const gH = g.box.bottom - g.box.top + 1;
    const gShoulderW = meanWidth(gRowSpans, g.box.top, g.box.top + gH * 0.15);
    const destShoulderW = meanWidth(torsoSpans, collarY, collarY + 0.1 * bodyH);
    const scale = gShoulderW > 0 ? destShoulderW / gShoulderW : 1;
    let hemY = collarY + Math.round(gH * scale);
    const minHem = crotchY - Math.round(0.12 * bodyH);
    const maxHem = isDress ? Math.min(ankleY - Math.round(0.04 * bodyH), kneeY + Math.round(0.1 * bodyH)) : crotchY + Math.round(0.1 * bodyH);
    hemY = Math.max(minHem, Math.min(hemY, maxHem));
    // l'abito scende oltre i fianchi: sotto il cavallo la destinazione è
    // l'intera sagoma (tutte e due le gambe), non la corsa centrale
    const destSpans = isDress
      ? topDestSpans.map((s, y) =>
          y > crotchY && silRows[y] ? { left: silRows[y].left, right: silRows[y].right } : s
        )
      : topDestSpans;
    const plan = topWarpPlan({
      garmentRows: g.rows,
      garmentBox: g.box,
      destSpans,
      collarY,
      hemY,
      shoulderRefWidth: gShoulderW,
    });
    layers.push({ kind: isDress ? 'dress' : 'top', url: renderPlan(g.img, plan, W, H) });
  }

  // ── capospalla: come il top ma più largo e un filo più lungo ──
  if (assets.outerwear) {
    const g = await readGarment(assets.outerwear.url);
    const gH = g.box.bottom - g.box.top + 1;
    const gRowSpans = g.rows.map((r) => (r ? { left: r.left, right: r.right } : null));
    const gShoulderW = meanWidth(gRowSpans, g.box.top, g.box.top + gH * 0.15);
    const dest = expandSpans(topDestSpans, 1.12);
    const destShoulderW = meanWidth(dest, collarY, collarY + 0.1 * bodyH);
    const scale = gShoulderW > 0 ? destShoulderW / gShoulderW : 1;
    let hemY = collarY - Math.round(0.01 * bodyH) + Math.round(gH * scale);
    hemY = Math.max(crotchY - Math.round(0.06 * bodyH), Math.min(hemY, kneeY));
    const plan = topWarpPlan({
      garmentRows: g.rows,
      garmentBox: g.box,
      destSpans: dest,
      collarY: collarY - Math.round(0.01 * bodyH),
      hemY,
      shoulderRefWidth: gShoulderW,
    });
    layers.push({ kind: 'outerwear', url: renderPlan(g.img, plan, W, H) });
  }

  // ── scarpe: alle caviglie vere (posa), stessa resa a rettangoli di prima ──
  const shoes = [];
  if (assets.shoes) {
    const { aspect } = assets.shoes;
    const bottom = person.box.bottom + 0.01 * bodyH;
    if (aspect >= 1.4) {
      const height = 0.1 * bodyH;
      const width = height * aspect;
      const cx =
        pose && pose.ankleL.visible && pose.ankleR.visible
          ? (pose.ankleL.x + pose.ankleR.x) / 2
          : person.cx;
      shoes.push({ kind: 'shoes', x: cx - width / 2, y: bottom - height, width, height });
    } else {
      const height = 0.09 * bodyH;
      const width = height * aspect;
      const centers =
        pose && pose.ankleL.visible && pose.ankleR.visible
          ? [pose.ankleL.x, pose.ankleR.x]
          : [person.cx - person.hips.width * 0.22, person.cx + person.hips.width * 0.22];
      for (const cx of centers) {
        shoes.push({ kind: 'shoes', x: cx - width / 2, y: bottom - height, width, height });
      }
    }
  }

  return { layers, shoes };
}
