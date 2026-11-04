/** Lunghezza minima della password (la stessa di Supabase e della registrazione). */
export const MIN_PASSWORD_LENGTH = 6;

/**
 * Controllo della nuova password prima di mandarla a Supabase.
 * @param {string} password
 * @param {string} confirm la stessa, ripetuta
 * @returns {null|'missing-fields'|'password-too-short'|'passwords-mismatch'}
 *   codice tradotto in auth.errors.*
 */
export function checkNewPassword(password, confirm) {
  if (!password || !confirm) return 'missing-fields';
  if (password.length < MIN_PASSWORD_LENGTH) return 'password-too-short';
  if (password !== confirm) return 'passwords-mismatch';
  return null;
}
