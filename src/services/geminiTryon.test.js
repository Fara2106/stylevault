import { describe, it, expect } from 'vitest';
import {
  parseDataUrl,
  buildTryOnRequest,
  extractImageFromResponse,
} from './geminiTryon';

const person = { mimeType: 'image/jpeg', data: 'PERSONA' };
const item = (id, name, data) => ({
  id,
  name,
  part: { mimeType: 'image/jpeg', data },
});

describe('geminiTryon', () => {
  it('parseDataUrl estrae mime e base64 da un dataURL', () => {
    expect(parseDataUrl('data:image/jpeg;base64,AAAA')).toEqual({
      mimeType: 'image/jpeg',
      data: 'AAAA',
    });
    expect(parseDataUrl('data:image/png;base64,BB==')).toEqual({
      mimeType: 'image/png',
      data: 'BB==',
    });
  });

  it('parseDataUrl rifiuta stringhe che non sono dataURL base64', () => {
    expect(parseDataUrl('https://example.com/foto.jpg')).toBeNull();
    expect(parseDataUrl('data:text/plain;base64,AAAA')).toBeNull();
    expect(parseDataUrl(null)).toBeNull();
  });

  it('buildTryOnRequest mette prompt, persona e capi in un unico turno', () => {
    const req = buildTryOnRequest(person, [
      item('1', 'T-shirt Bianca', 'CAPO1'),
      item('2', 'Jeans Slim', 'CAPO2'),
    ]);
    const parts = req.contents[0].parts;

    // Primo part: il prompt testuale che cita i capi per nome
    expect(parts[0].text).toContain('T-shirt Bianca');
    expect(parts[0].text).toContain('Jeans Slim');

    // Poi la foto della persona, poi una foto per capo
    const images = parts.filter((p) => p.inlineData);
    expect(images.map((p) => p.inlineData.data)).toEqual([
      'PERSONA',
      'CAPO1',
      'CAPO2',
    ]);
  });

  it('extractImageFromResponse ricava un dataURL dalla risposta', () => {
    const json = {
      candidates: [
        {
          content: {
            parts: [
              { text: 'Ecco il risultato' },
              { inlineData: { mimeType: 'image/png', data: 'RISULTATO' } },
            ],
          },
        },
      ],
    };
    expect(extractImageFromResponse(json)).toBe(
      'data:image/png;base64,RISULTATO'
    );
  });

  it('extractImageFromResponse restituisce null se non ci sono immagini', () => {
    expect(extractImageFromResponse({})).toBeNull();
    expect(
      extractImageFromResponse({
        candidates: [{ content: { parts: [{ text: 'solo testo' }] } }],
      })
    ).toBeNull();
  });
});
