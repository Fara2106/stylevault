import { describe, it, expect } from 'vitest';
import { cutoutCacheKey, CUTOUT_VERSION } from './garmentCutoutCache';

describe('cutoutCacheKey', () => {
  it('include id e versione', () => {
    const k = cutoutCacheKey({ id: 'abc', photo: 'data:image/jpeg;base64,AAAA' });
    expect(k).toContain('abc');
    expect(k).toContain(String(CUTOUT_VERSION));
  });

  it('cambia se cambia la foto (invalidazione)', () => {
    const a = cutoutCacheKey({ id: 'x', photo: 'data:1' });
    const b = cutoutCacheKey({ id: 'x', photo: 'data:2' });
    expect(a).not.toBe(b);
  });

  it('è stabile a parità di input', () => {
    const item = { id: 'x', photo: 'data:same' };
    expect(cutoutCacheKey(item)).toBe(cutoutCacheKey(item));
  });
});
