/**
 * Le 3 foto del corpo del profilo: davanti (è la foto di riferimento, la usano
 * anche Prova e Armocromia), di lato e di spalle (colonna body_photos).
 */

export const BODY_VIEWS = ['front', 'side', 'back'];

/** Le caselle da mostrare, nell'ordine davanti → lato → spalle; url null se manca. */
export function bodyPhotoSlots({ referencePhoto = null, bodyPhotos = {} } = {}) {
  return BODY_VIEWS.map((view) => ({
    view,
    url: (view === 'front' ? referencePhoto : bodyPhotos?.[view]) || null,
  }));
}
