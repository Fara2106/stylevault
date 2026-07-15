/**
 * Compositore "Su modello": dati i landmark della persona (analyzeSilhouette)
 * e i rapporti larghezza/altezza dei capi scontornati, calcola i rettangoli
 * in cui appoggiare le foto dei capi sulla persona, nelle sue proporzioni
 * reali. Puro: coordinate nello stesso sistema dei landmark (pixel della
 * foto scontornata della persona).
 *
 * I fattori di larghezza tengono conto che i capi sono fotografati stesi:
 * un top steso ha le maniche aperte in orizzontale, quindi è più largo dello
 * span delle spalle di chi lo indossa (le maniche indossate ricadono).
 * I valori sono tarati a schermo su foto vere, non calcolati.
 */

export const TOP_WIDTH_FACTOR = 1.35;
export const DRESS_WIDTH_FACTOR = 1.25;
export const OUTER_WIDTH_FACTOR = 1.5;
/** I pantaloni scalano sull'altezza vita→caviglia; una foto anomala molto
 * larga (capo steso di traverso) non deve coprire mezza figura. */
export const BOTTOM_MAX_WIDTH_FACTOR = 1.6;

/** Quanto il colletto sale sopra la linea delle spalle, in frazione dell'altezza figura. */
const TOP_NECK_RISE = 0.03;
const OUTER_NECK_RISE = 0.04;
/** La vita dei pantaloni sta sopra il cavallo di questa frazione dell'altezza. */
const WAIST_ABOVE_CROTCH = 0.13;
/** L'orlo dei pantaloni scende un filo oltre le caviglie. */
const HEM_BELOW_ANKLE = 0.02;
const SHOE_HEIGHT = 0.09;
const SHOE_SPREAD = 0.22;
const SHOE_DROP = 0.01;

/** Rettangolo centrato su `cx`, con la larghezza data e l'altezza dal rapporto della foto. */
const byWidth = (kind, cx, y, width, aspect) => ({
  kind,
  x: cx - width / 2,
  y,
  width,
  height: width / aspect,
});

/**
 * @param {ReturnType<import('./personSilhouette').analyzeSilhouette>} person
 * @param {{top?:{aspect:number,isDress?:boolean}, bottom?:{aspect:number},
 *          outerwear?:{aspect:number}, shoes?:{aspect:number}}} garments
 *        `aspect` = larghezza/altezza del ritaglio del capo.
 * @returns {{kind:string,x:number,y:number,width:number,height:number}[]}
 *          in ordine di pittura: bottom, top/abito, capospalla, scarpe.
 */
export function garmentPlacements(person, garments) {
  if (!person) return [];
  const H = person.box.height;
  const out = [];

  if (garments.bottom) {
    const { aspect } = garments.bottom;
    const y = person.crotchY - WAIST_ABOVE_CROTCH * H;
    const hem = person.ankleY + HEM_BELOW_ANKLE * H;
    let height = hem - y;
    let width = height * aspect;
    const cap = person.hips.width * BOTTOM_MAX_WIDTH_FACTOR;
    if (width > cap) {
      width = cap;
      height = width / aspect;
    }
    out.push({ kind: 'bottom', x: person.cx - width / 2, y: hem - height, width, height });
  }

  if (garments.top) {
    const { aspect, isDress } = garments.top;
    const factor = isDress ? DRESS_WIDTH_FACTOR : TOP_WIDTH_FACTOR;
    out.push(
      byWidth(
        isDress ? 'dress' : 'top',
        person.cx,
        person.shoulders.y - TOP_NECK_RISE * H,
        person.shoulders.width * factor,
        aspect
      )
    );
  }

  if (garments.outerwear) {
    out.push(
      byWidth(
        'outerwear',
        person.cx,
        person.shoulders.y - OUTER_NECK_RISE * H,
        person.shoulders.width * OUTER_WIDTH_FACTOR,
        garments.outerwear.aspect
      )
    );
  }

  if (garments.shoes) {
    const height = SHOE_HEIGHT * H;
    const width = height * garments.shoes.aspect;
    const y = person.box.bottom + SHOE_DROP * H - height;
    for (const side of [-1, 1]) {
      const cx = person.cx + side * person.hips.width * SHOE_SPREAD;
      out.push({ kind: 'shoes', x: cx - width / 2, y, width, height });
    }
  }

  return out;
}
