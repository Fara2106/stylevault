/**
 * Statistiche del guardaroba, calcolate dallo storico outfit del calendario.
 * Contano solo le voci "indossate" (worn !== false), non quelle pianificate.
 */

const outfitItems = (outfit) =>
  [outfit.top, outfit.bottom, outfit.shoes, outfit.outerwear, ...(outfit.accessories || [])]
    .filter(Boolean);

/** Mappa itemId -> { count, lastDate } dalle voci indossate. */
export function getWearStats(outfitHistory) {
  const stats = new Map();
  for (const log of outfitHistory || []) {
    if (log.worn === false) continue;
    for (const item of outfitItems(log.outfit)) {
      const current = stats.get(item.id) || { count: 0, lastDate: null };
      current.count += 1;
      if (!current.lastDate || log.date > current.lastDate) current.lastDate = log.date;
      stats.set(item.id, current);
    }
  }
  return stats;
}

/** Capi più indossati (solo con almeno 1 utilizzo). */
export function getMostWorn(items, outfitHistory, limit = 5) {
  const stats = getWearStats(outfitHistory);
  return items
    .map((item) => ({ item, count: stats.get(item.id)?.count || 0 }))
    .filter((e) => e.count > 0)
    .sort((a, b) => b.count - a.count)
    .slice(0, limit);
}

/** Capi meno indossati (i mai indossati per primi). */
export function getLeastWorn(items, outfitHistory, limit = 5) {
  const stats = getWearStats(outfitHistory);
  return items
    .map((item) => ({ item, count: stats.get(item.id)?.count || 0 }))
    .sort((a, b) => a.count - b.count)
    .slice(0, limit);
}

/** Ripartizione per categoria, ordinata per numerosità. */
export function getCategoryBreakdown(items) {
  const counts = new Map();
  for (const item of items) {
    counts.set(item.category, (counts.get(item.category) || 0) + 1);
  }
  return [...counts.entries()]
    .map(([category, count]) => ({ category, count }))
    .sort((a, b) => b.count - a.count);
}

/** Ripartizione per colore (un capo può contarne più d'uno). */
export function getColorBreakdown(items) {
  const counts = new Map();
  for (const item of items) {
    for (const color of item.colors || []) {
      counts.set(color, (counts.get(color) || 0) + 1);
    }
  }
  return [...counts.entries()]
    .map(([color, count]) => ({ color, count }))
    .sort((a, b) => b.count - a.count);
}

/**
 * Costo per utilizzo (solo capi con prezzo).
 * I capi mai indossati riportano costPerWear = prezzo pieno.
 */
export function getCostPerWear(items, outfitHistory, limit = 5) {
  const stats = getWearStats(outfitHistory);
  return items
    .filter((item) => item.price != null && item.price !== '' && Number(item.price) > 0)
    .map((item) => {
      const count = stats.get(item.id)?.count || 0;
      return {
        item,
        count,
        costPerWear: Number(item.price) / Math.max(1, count),
      };
    })
    .sort((a, b) => a.costPerWear - b.costPerWear)
    .slice(0, limit);
}
