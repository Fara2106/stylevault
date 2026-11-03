import { describe, it, expect } from 'vitest';
import { findSensitive, canSendFeedback, deviceInfo, FEEDBACK_MAX } from './feedback';

describe('findSensitive', () => {
  it('trova email, numeri lunghi (telefono, carta) e IBAN', () => {
    expect(findSensitive('scrivimi a mario@gmail.com')).toEqual(['email']);
    expect(findSensitive('chiamami al 333 123 4567')).toEqual(['number']);
    expect(findSensitive('carta 4111-1111-1111-1111')).toEqual(['number']);
    expect(findSensitive('IBAN IT60X0542811101000000123456')).toContain('iban');
  });

  it('lascia passare taglie, anni, prezzi e testo normale', () => {
    expect(findSensitive('La taglia 42 nel 2026 costava 49,90 €: il pulsante non va')).toEqual([]);
    expect(findSensitive('')).toEqual([]);
  });
});

describe('canSendFeedback', () => {
  it('serve un testo tra 10 e 2000 caratteri senza dati sensibili', () => {
    expect(canSendFeedback('  corto  ')).toBe(false);
    expect(canSendFeedback('Il calendario non si apre')).toBe(true);
    expect(canSendFeedback('x'.repeat(FEEDBACK_MAX + 1))).toBe(false);
    expect(canSendFeedback('Non va, scrivimi a a@b.it')).toBe(false);
  });
});

describe('deviceInfo', () => {
  it("nell'app usa le info del nativo e non lo user agent", () => {
    const info = deviceInfo({
      native: { appVersion: '0.1.0 (1)', osVersion: 'iOS 27.0', model: 'iPhone18,2', extra: 'x' },
      userAgent: 'Mozilla/5.0',
      language: 'it',
    });
    expect(info).toEqual({
      source: 'app iOS',
      appVersion: '0.1.0 (1)',
      osVersion: 'iOS 27.0',
      model: 'iPhone18,2',
      language: 'it',
    });
  });

  it('nel browser manda lo user agent; i campi vuoti non partono', () => {
    expect(deviceInfo({ userAgent: 'Mozilla/5.0 (iPhone)', language: '' })).toEqual({
      source: 'sito web',
      userAgent: 'Mozilla/5.0 (iPhone)',
    });
  });
});
