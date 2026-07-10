/**
 * WebGL non c'è sempre: vecchi telefoni, accelerazione disattivata, modalità
 * risparmio energetico. In quel caso la modalità 3D si disabilita e si spiega
 * perché, invece di mostrare una tela nera.
 */
let cached = null;

export function hasWebGL() {
  if (cached !== null) return cached;
  if (typeof document === 'undefined') {
    cached = false;
    return cached;
  }
  try {
    const canvas = document.createElement('canvas');
    cached = Boolean(
      canvas.getContext('webgl2') || canvas.getContext('webgl')
    );
  } catch {
    cached = false;
  }
  return cached;
}
