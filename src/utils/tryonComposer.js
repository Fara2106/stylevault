/**
 * Composizione manuale dell'outfit sulla foto della persona (pagina "Prova",
 * pagina Prova). L'outfit ha la stessa forma di quelli del motore:
 * { top, bottom, shoes, outerwear, accessories[] }; un abito (categoria
 * "dresses") occupa lo slot top e lascia il bottom vuoto, come fa il motore.
 */

export const MAX_ACCESSORIES = 3;

const SLOT_CATEGORIES = {
  outerwear: ['outerwear'],
  top: ['tops', 'dresses'],
  bottom: ['bottoms'],
  shoes: ['shoes'],
  accessories: ['accessories'],
};

export const TRYON_SLOTS = Object.keys(SLOT_CATEGORIES);

export const slotCategories = (slot) => SLOT_CATEGORIES[slot] || [];

export const slotForItem = (item) => {
  if (!item) return null;
  return (
    TRYON_SLOTS.find((slot) => SLOT_CATEGORIES[slot].includes(item.category)) || null
  );
};

export const emptyOutfit = () => ({
  top: null,
  bottom: null,
  shoes: null,
  outerwear: null,
  accessories: [],
});

/** Adatta un outfit arrivato da fuori (motore, calendario) alla forma completa. */
export const normalizeOutfit = (outfit) => ({
  ...emptyOutfit(),
  ...outfit,
  accessories: outfit?.accessories || [],
});

export const outfitFromItem = (item) => {
  const slot = slotForItem(item);
  return slot ? applyItem(emptyOutfit(), slot, item) : emptyOutfit();
};

export const outfitHasItems = (outfit) =>
  Boolean(
    outfit.top ||
      outfit.bottom ||
      outfit.shoes ||
      outfit.outerwear ||
      outfit.accessories?.length
  );

export const applyItem = (outfit, slot, item) => {
  if (slot === 'accessories') {
    const already = outfit.accessories.some((a) => a.id === item.id);
    if (already) {
      return { ...outfit, accessories: outfit.accessories.filter((a) => a.id !== item.id) };
    }
    if (outfit.accessories.length >= MAX_ACCESSORIES) return outfit;
    return { ...outfit, accessories: [...outfit.accessories, item] };
  }
  const next = { ...outfit, [slot]: item };
  // Abito e bottom si escludono a vicenda
  if (slot === 'top' && item.category === 'dresses') next.bottom = null;
  if (slot === 'bottom' && outfit.top?.category === 'dresses') next.top = null;
  return next;
};

/**
 * Layer di vestizione da disegnare sull'avatar, in ordine di pittura:
 * bottom sotto, poi top/abito, capospalla sopra tutto, scarpe a parte.
 * Gli accessori non hanno una sagoma sul corpo e restano fuori.
 */
export const garmentLayers = (outfit) => {
  if (!outfit) return [];
  const layers = [];
  if (outfit.bottom) layers.push({ kind: 'bottom', item: outfit.bottom });
  if (outfit.top) {
    layers.push({
      kind: outfit.top.category === 'dresses' ? 'dress' : 'top',
      item: outfit.top,
    });
  }
  if (outfit.outerwear) layers.push({ kind: 'outerwear', item: outfit.outerwear });
  if (outfit.shoes) layers.push({ kind: 'shoes', item: outfit.shoes });
  return layers;
};

export const removeFromSlot = (outfit, slot, itemId) => {
  if (slot === 'accessories') {
    return { ...outfit, accessories: outfit.accessories.filter((a) => a.id !== itemId) };
  }
  return { ...outfit, [slot]: null };
};
