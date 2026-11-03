import { describe, it, expect, vi, afterEach } from 'vitest';
import { avatarPayload, postToNative, isNativeApp } from './nativeBridge';

const item = (id, category, extra = {}) => ({
  id,
  category,
  name: `capo ${id}`,
  photo: `https://x/${id}.jpg`,
  ...extra,
});

describe('avatarPayload', () => {
  it('manda top, bottom, scarpe e capospalla con lo slot; niente accessori', () => {
    const outfit = {
      top: item('t', 'tops', { photoBack: 'https://x/t-back.jpg' }),
      bottom: item('b', 'bottoms'),
      shoes: item('s', 'shoes'),
      outerwear: null,
      accessories: [item('a1', 'accessories'), item('a2', 'accessories')],
    };
    const { items } = avatarPayload(outfit);
    expect(items.map((i) => i.slot)).toEqual(['top', 'bottom', 'shoes']);
    expect(items[0]).toEqual({
      id: 't',
      category: 'tops',
      slot: 'top',
      photo: 'https://x/t.jpg',
      photoBack: 'https://x/t-back.jpg',
      name: 'capo t',
    });
    expect(items[1].photoBack).toBeNull();
  });

  it('un abito sta nello slot top', () => {
    const { items } = avatarPayload({ top: item('d', 'dresses') });
    expect(items).toHaveLength(1);
    expect(items[0].slot).toBe('top');
  });
});

describe('postToNative', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('fuori dall\'app non fa nulla e non lancia', () => {
    vi.stubGlobal('window', {});
    expect(isNativeApp()).toBe(false);
    expect(postToNative('signOut', {})).toBe(false);
  });

  it('nell\'app consegna { type, payload } all\'handler svNative', () => {
    const postMessage = vi.fn();
    vi.stubGlobal('window', { webkit: { messageHandlers: { svNative: { postMessage } } } });
    expect(isNativeApp()).toBe(true);
    expect(postToNative('themeChanged', { setting: 'dark' })).toBe(true);
    expect(postMessage).toHaveBeenCalledWith({ type: 'themeChanged', payload: { setting: 'dark' } });
  });
});
