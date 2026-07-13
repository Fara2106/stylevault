/**
 * Geometria del pannello su cui si mappa il ritaglio del capo nell'avatar 3D.
 * Puro e senza three.js: così è testabile in Vitest (ambiente node).
 *
 * Il ritaglio (una foto di un capo, con la sua proporzione larghezza/altezza)
 * va inserito nella "zona del capo" sul corpo — l'intervallo di quota del
 * profilo — rispettando l'aspect: né schiacciato né tilato. Il pannello è un
 * arco di cilindro; qui si calcolano quota, altezza, raggio e ampiezza d'arco.
 */

/**
 * @param {Object} input
 * @param {Array<[number, number]>} input.profile  profilo [raggio, quota] della parte principale del capo
 * @param {number} [input.offsetX=0]   scostamento laterale (capi sdoppiati: gambe)
 * @param {boolean} [input.mirror=false] true se il capo è sdoppiato (pantaloni): il pannello deve avvolgere entrambe le istanze
 * @param {number} input.aspect        larghezza/altezza del ritaglio
 * @param {number} input.arc           apertura massima del pannello, in radianti
 * @param {number} input.gap           stacco dal corpo
 * @returns {{ yCenter: number, height: number, radius: number, arcAngle: number }}
 */
export function panelPlacement({ profile, offsetX = 0, mirror = false, aspect, arc, gap }) {
  const ys = profile.map(([, y]) => y);
  const yMin = Math.min(...ys);
  const yMax = Math.max(...ys);
  const regionHeight = yMax - yMin;

  const baseRadius = Math.max(...profile.map(([r]) => r));
  const radius = (mirror ? offsetX + baseRadius : baseRadius) + gap;

  const frontWidth = radius * arc;
  const regionAspect = frontWidth / regionHeight;

  let panelWidth;
  let panelHeight;
  if (aspect >= regionAspect) {
    // Ritaglio più largo della zona: riempie l'arco, si accorcia in altezza.
    panelWidth = frontWidth;
    panelHeight = frontWidth / aspect;
  } else {
    // Ritaglio più alto della zona: riempie l'altezza, si stringe d'arco.
    panelHeight = regionHeight;
    panelWidth = regionHeight * aspect;
  }

  return {
    yCenter: (yMin + yMax) / 2,
    height: panelHeight,
    radius,
    arcAngle: panelWidth / radius,
  };
}
