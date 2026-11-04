import { describe, it, expect } from 'vitest';
import { bodyPhotoSlots, BODY_VIEWS } from './bodyPhotos';

describe('bodyPhotoSlots', () => {
  it('davanti, di lato, di spalle: la davanti è la foto di riferimento del profilo', () => {
    const slots = bodyPhotoSlots({
      referencePhoto: 'https://x/front.jpg',
      bodyPhotos: { side: 'https://x/side.jpg', back: null },
    });
    expect(slots).toEqual([
      { view: 'front', url: 'https://x/front.jpg' },
      { view: 'side', url: 'https://x/side.jpg' },
      { view: 'back', url: null },
    ]);
    expect(BODY_VIEWS).toEqual(['front', 'side', 'back']);
  });

  it('senza profilo caricato: tre caselle vuote', () => {
    expect(bodyPhotoSlots({}).map((s) => s.url)).toEqual([null, null, null]);
  });
});
