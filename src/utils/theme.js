/**
 * Tema dell'app: "light", "dark" o "system" (segue il telefono).
 * resolveTheme è pura (testata); applyTheme tocca il documento.
 */

/** @returns {'light'|'dark'} il tema effettivo da mostrare. */
export function resolveTheme(setting, prefersDark) {
  if (setting === 'light' || setting === 'dark') return setting;
  return prefersDark ? 'dark' : 'light';
}

// Colore della barra di sistema (Safari, schermata Home) per ciascun tema:
// uguale al fondo, come --sv-bg nei token.
const THEME_COLOR = { light: '#FAF7F2', dark: '#141210' };

/** Applica il tema risolto a <html data-theme> e alla barra del browser. */
export function applyTheme(resolved) {
  const root = document.documentElement;
  root.dataset.theme = resolved;
  root.style.colorScheme = resolved;
  const meta = document.querySelector('meta[name="theme-color"]');
  if (meta) meta.setAttribute('content', THEME_COLOR[resolved]);
}
