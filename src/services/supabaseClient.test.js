import { describe, it, expect } from 'vitest';
import { authOptions } from './supabaseClient';

describe('authOptions', () => {
  it("nell'app iOS il token lo rinnova solo il nativo", () => {
    expect(authOptions(true).autoRefreshToken).toBe(false);
  });

  it('nel browser il sito rinnova da solo come sempre', () => {
    expect(authOptions(false).autoRefreshToken).toBe(true);
  });
});
