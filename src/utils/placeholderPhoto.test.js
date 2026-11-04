import { describe, it, expect } from 'vitest';
import { placeholderInitial, makePlaceholderPhoto } from './placeholderPhoto';

describe('segnaposto del capo senza foto', () => {
  it('usa l\'iniziale del nome, maiuscola', () => {
    expect(placeholderInitial('maglione blu')).toBe('M');
    expect(placeholderInitial('  èlite')).toBe('È');
  });

  it('nome vuoto → un segno neutro', () => {
    expect(placeholderInitial('')).toBe('·');
    expect(placeholderInitial(undefined)).toBe('·');
  });

  it('senza canvas (test, server) non inventa una foto: stringa vuota', () => {
    expect(makePlaceholderPhoto('Maglione', null)).toBe('');
  });
});
