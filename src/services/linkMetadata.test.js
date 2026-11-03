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
      title: 'Camicia in lino',
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

  it('lancia link-metadata-failed se lo shop blocca la lettura (403 "Access Denied")', async () => {
    // Risposta reale di microlink per una pagina prodotto H&M (2026-11-03):
    // status "success" ma la pagina letta è il muro anti-bot.
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          status: 'success',
          statusCode: 403,
          data: {
            title: 'Access Denied',
            image: null,
            logo: { url: 'https://vmc.digicert.com/logo.svg' },
            publisher: 'hm.com',
          },
        }),
      })
    );
    await expect(
      fetchLinkMetadata('https://www2.hm.com/it_it/productpage.1341159002.html')
    ).rejects.toThrow('link-metadata-failed');
  });

  it('non usa il logo del sito come foto del capo', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          status: 'success',
          statusCode: 200,
          data: {
            title: 'Pantaloni chino',
            image: null,
            logo: { url: 'https://shop.example.com/logo.svg' },
            publisher: 'Shop',
          },
        }),
      })
    );
    expect((await fetchLinkMetadata('https://shop.example.com/p/1')).image).toBe('');
  });

  it('lancia link-metadata-limit quando il piano gratuito di microlink è esaurito', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: false,
        status: 429,
        json: async () => ({ status: 'fail', message: 'Your daily rate limit has been reached.' }),
      })
    );
    await expect(fetchLinkMetadata('https://www.zalando.it/p.html')).rejects.toThrow(
      'link-metadata-limit'
    );
  });

  it('toglie il nome dello shop in coda al titolo', async () => {
    vi.stubGlobal(
      'fetch',
      vi.fn().mockResolvedValue({
        ok: true,
        json: async () => ({
          status: 'success',
          statusCode: 200,
          data: {
            title: 'Polo Club RIGBY GO U - Maglione - ecru/bianco - Zalando.it',
            image: { url: 'https://img01.ztat.net/a.jpg' },
            publisher: 'zalando.it',
          },
        }),
      })
    );
    expect((await fetchLinkMetadata('https://www.zalando.it/p.html')).title).toBe(
      'Polo Club RIGBY GO U - Maglione - ecru/bianco'
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
