import { describe, it, expect, vi, afterEach } from 'vitest';
import {
  avatarPayload,
  postToNative,
  isNativeApp,
  installNativeHooks,
  onNativeLocation,
  onNativeForecast,
  requestNativeLocation,
  requestNativeForecast,
  _resetNativeListeners,
} from './nativeBridge';

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
      descriptor: 'capo t',
    });
    expect(items[1].photoBack).toBeNull();
  });

  it('un abito sta nello slot top', () => {
    const { items } = avatarPayload({ top: item('d', 'dresses') });
    expect(items).toHaveLength(1);
    expect(items[0].slot).toBe('top');
  });

  it('manda la descrizione inglese del capo', () => {
    const { items } = avatarPayload({
      top: item('k', 'tops', { subcategory: 'sweater', colors: ['cream'] }),
    });
    expect(items[0].descriptor).toBe('cream sweater');
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

describe('installNativeHooks', () => {
  afterEach(() => vi.unstubAllGlobals());

  it('espone setSession e avvisa il nativo che è pronto a riceverla', () => {
    const postMessage = vi.fn();
    const win = { webkit: { messageHandlers: { svNative: { postMessage } } } };
    vi.stubGlobal('window', win);
    const setSession = vi.fn();
    installNativeHooks({ setSession });
    expect(win.svNative.setSession).toBe(setSession);
    expect(postMessage).toHaveBeenCalledWith({ type: 'ready', payload: {} });
  });
});

describe('posizione e previsione dall\'app', () => {
  afterEach(() => {
    vi.unstubAllGlobals();
    _resetNativeListeners();
  });

  const nativeWindow = () => {
    const postMessage = vi.fn();
    const win = { webkit: { messageHandlers: { svNative: { postMessage } } } };
    vi.stubGlobal('window', win);
    installNativeHooks({ setSession: vi.fn() });
    return { win, postMessage };
  };

  it('setLocation arriva a chi è iscritto', () => {
    const { win } = nativeWindow();
    const cb = vi.fn();
    onNativeLocation(cb);
    win.svNative.setLocation({ latitude: 41.9, longitude: 12.5, name: 'Roma' });
    expect(cb).toHaveBeenCalledWith({ latitude: 41.9, longitude: 12.5, name: 'Roma' });
  });

  it('chi si iscrive dopo riceve l\'ultima posizione', () => {
    const { win } = nativeWindow();
    win.svNative.setLocation({ latitude: 41.9, longitude: 12.5, name: 'Roma' });
    const cb = vi.fn();
    const stop = onNativeLocation(cb);
    expect(cb).toHaveBeenCalledWith({ latitude: 41.9, longitude: 12.5, name: 'Roma' });
    stop();
    win.svNative.setLocation({ latitude: 1, longitude: 2, name: 'Altro' });
    expect(cb).toHaveBeenCalledTimes(1);
  });

  it('setForecast arriva a chi è iscritto', () => {
    const { win } = nativeWindow();
    const cb = vi.fn();
    onNativeForecast(cb);
    win.svNative.setForecast({ source: 'apple', payload: {} });
    expect(cb).toHaveBeenCalledWith({ source: 'apple', payload: {} });
  });

  it('le richieste vanno al nativo', () => {
    const { postMessage } = nativeWindow();
    requestNativeLocation();
    expect(postMessage).toHaveBeenCalledWith({ type: 'requestLocation', payload: {} });
    requestNativeForecast({ name: 'Roma', latitude: 41.9, longitude: 12.5, country: 'IT' });
    expect(postMessage).toHaveBeenCalledWith({
      type: 'requestForecast',
      payload: { latitude: 41.9, longitude: 12.5, name: 'Roma' },
    });
  });
});
