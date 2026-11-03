import { describe, it, expect } from 'vitest';
import { resolveTheme } from './theme';

describe('resolveTheme', () => {
  it('"sistema" segue il telefono', () => {
    expect(resolveTheme('system', true)).toBe('dark');
    expect(resolveTheme('system', false)).toBe('light');
  });

  it('una scelta esplicita vince sul telefono', () => {
    expect(resolveTheme('dark', false)).toBe('dark');
    expect(resolveTheme('light', true)).toBe('light');
  });

  it('un valore mancante o vecchio vale come "sistema"', () => {
    expect(resolveTheme(undefined, true)).toBe('dark');
    expect(resolveTheme('boh', false)).toBe('light');
  });
});
