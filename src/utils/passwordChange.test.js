import { describe, it, expect } from 'vitest';
import { checkNewPassword } from './passwordChange';

describe('checkNewPassword', () => {
  it('nessun errore con due password uguali di almeno 6 caratteri', () => {
    expect(checkNewPassword('segreta1', 'segreta1')).toBeNull();
  });

  it('campi vuoti → missing-fields', () => {
    expect(checkNewPassword('', '')).toBe('missing-fields');
    expect(checkNewPassword('segreta1', '')).toBe('missing-fields');
  });

  it('meno di 6 caratteri → password-too-short (prima del confronto)', () => {
    expect(checkNewPassword('abc', 'abd')).toBe('password-too-short');
  });

  it('le due password non coincidono → passwords-mismatch', () => {
    expect(checkNewPassword('segreta1', 'segreta2')).toBe('passwords-mismatch');
  });
});
