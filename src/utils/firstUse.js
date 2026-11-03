/**
 * "Prima volta" dei modelli on-device (scontorno @imgly, MediaPipe): il primo
 * uso scarica decine di MB e può durare un minuto, poi il browser li tiene in
 * cache e tutto è molto più veloce. Si ricorda per dispositivo se il primo
 * giro è già avvenuto, così la spiegazione compare solo quando serve.
 */
const key = (name) => `sv_models_ready_${name}`;

/** true se su questo dispositivo i modelli di `name` sono già stati usati. */
export function modelsReady(name) {
  try {
    return localStorage.getItem(key(name)) === '1';
  } catch {
    return false;
  }
}

/** Segna che i modelli di `name` sono scaricati (dopo il primo giro riuscito). */
export function markModelsReady(name) {
  try {
    localStorage.setItem(key(name), '1');
  } catch {
    /* memoria piena o bloccata: al massimo la spiegazione ricompare */
  }
}
