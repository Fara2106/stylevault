import { describe, it, expect, vi } from 'vitest';
import { fetchLinkMetadata, isValidHttpUrl } from './linkMetadata';

describe('fetchLinkMetadata', () => {
  it('mappa la risposta microlink in {title, image, site}', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          status: 'success',
          data: {
            title: 'Camicia in lino - Zara',
            image: { url: 'https://cdn.example.com/camicia.jpg' },
            publisher: 'Zara',
          },
        }),
      })
    );

    expect(await fetchLinkMetadata('https://zara.com/p/123')).toEqual({
      title: 'Camicia in lino - Zara',
      image: 'https://cdn.example.com/camicia.jpg',
      site: 'Zara',
    });
  });

  it('lancia link-metadata-failed quando lo shop si protegge', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({ status: 'fail' }),
      })
    );
    await expect(fetchLinkMetadata('https://negozio-blindato.com')).rejects.toThrow(
      'link-metadata-failed'
    );
  });

  it('lancia link-metadata-failed senza rete', async () => {
    vi.stubGlobal('fetch', vi.fn().mockRejectedValue(new Error('offline')));
    await expect(fetchLinkMetadata('https://zara.com')).rejects.toThrow(
      'link-metadata-failed'
    );
  });
});

describe('isValidHttpUrl', () => {
  it('accetta http/https e rifiuta il resto', () => {
    expect(isValidHttpUrl('https://zara.com/p/1')).toBe(true);
    expect(isValidHttpUrl('http://example.com')).toBe(true);
    expect(isValidHttpUrl('ftp://x.com')).toBe(false);
    expect(isValidHttpUrl('non-un-url')).toBe(false);
    expect(isValidHttpUrl('')).toBe(false);
  });
});
