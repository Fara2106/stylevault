import { describe, it, expect, vi, beforeEach, afterEach } from 'vitest';
import {
  fetchModel,
  downloadFraction,
  onModelProgress,
  _resetModelDownloads,
} from './modelDownload';

/** Una risposta che arriva in pezzi, come dalla rete. */
const chunked = (chunks, headers = {}) =>
  new Response(
    new ReadableStream({
      start(controller) {
        for (const c of chunks) controller.enqueue(new Uint8Array(c));
        controller.close();
      },
    }),
    { status: 200, headers }
  );

const ITEMS = [
  { key: 'a', bytes: 100 },
  { key: 'b', bytes: 300 },
];

describe('fetchModel', () => {
  beforeEach(() => _resetModelDownloads());

  it('restituisce tutti i byte e avvisa a ogni pezzo arrivato', async () => {
    const fetchMock = vi.fn().mockResolvedValue(chunked([[1, 2], [3, 4, 5]]));
    const seen = [];
    const stop = onModelProgress(() => seen.push(downloadFraction([{ key: 'a', bytes: 5 }])));
    const data = await fetchModel('a', 'https://x/a.task', 5, fetchMock);
    stop();
    expect([...data]).toEqual([1, 2, 3, 4, 5]);
    expect(seen).toContain(0.4);
    expect(seen.at(-1)).toBe(1);
  });

  it('errore HTTP: rifiuta, e il file non conta come scaricato', async () => {
    const fetchMock = vi.fn().mockResolvedValue(new Response('no', { status: 404 }));
    await expect(fetchModel('a', 'https://x/a.task', 5, fetchMock)).rejects.toThrow('model-http-404');
    expect(downloadFraction([{ key: 'a', bytes: 5 }])).toBe(0);
  });

  it('lo stesso file chiesto due volte si scarica una volta sola', async () => {
    const fetchMock = vi.fn().mockImplementation(async () => chunked([[7, 8]]));
    const [one, two] = await Promise.all([
      fetchModel('a', 'https://x/a.task', 2, fetchMock),
      fetchModel('a', 'https://x/a.task', 2, fetchMock),
    ]);
    expect(fetchMock).toHaveBeenCalledTimes(1);
    expect([...one]).toEqual([7, 8]);
    expect(two).toBe(one);
  });
});

describe('downloadFraction', () => {
  beforeEach(() => _resetModelDownloads());

  it('zero prima di cominciare, pesata sulle dimensioni dei file', async () => {
    expect(downloadFraction(ITEMS)).toBe(0);
    await fetchModel('a', 'https://x/a', 100, vi.fn().mockResolvedValue(chunked([new Array(100).fill(0)])));
    expect(downloadFraction(ITEMS)).toBe(0.25);
  });

  it('un file più grande del previsto (es. compresso) non supera il 100%', async () => {
    await fetchModel('a', 'https://x/a', 100, vi.fn().mockResolvedValue(chunked([new Array(150).fill(0)])));
    await fetchModel('b', 'https://x/b', 300, vi.fn().mockResolvedValue(chunked([new Array(10).fill(0)])));
    // b è finito: conta per intero anche se più piccolo del previsto
    expect(downloadFraction(ITEMS)).toBe(1);
  });
});

describe('modelli conservati sul dispositivo (Cache Storage)', () => {
  let store;
  beforeEach(() => {
    _resetModelDownloads();
    store = new Map();
    vi.stubGlobal('caches', {
      open: async () => ({
        match: async (url) => (store.has(url) ? new Response(store.get(url)) : undefined),
        put: async (url, res) => store.set(url, new Uint8Array(await res.arrayBuffer())),
      }),
    });
  });
  afterEach(() => vi.unstubAllGlobals());

  it('dopo il primo download il file si legge dal dispositivo, senza rete', async () => {
    const first = vi.fn().mockResolvedValue(chunked([[1, 2, 3]]));
    await fetchModel('a', 'https://x/a.task', 3, first);
    expect([...store.get('https://x/a.task')]).toEqual([1, 2, 3]);

    _resetModelDownloads(); // come una nuova apertura del sito o dell'app
    const offline = vi.fn().mockRejectedValue(new Error('offline'));
    const data = await fetchModel('a', 'https://x/a.task', 3, offline);
    expect([...data]).toEqual([1, 2, 3]);
    expect(offline).not.toHaveBeenCalled();
  });

  it('senza Cache Storage (sito in http) scarica lo stesso', async () => {
    vi.stubGlobal('caches', undefined);
    const fetchMock = vi.fn().mockResolvedValue(chunked([[9]]));
    expect([...(await fetchModel('a', 'https://x/a.task', 1, fetchMock))]).toEqual([9]);
  });

  it('Cache Storage che fallisce non blocca il download', async () => {
    vi.stubGlobal('caches', { open: async () => { throw new Error('quota'); } });
    const fetchMock = vi.fn().mockResolvedValue(chunked([[4]]));
    expect([...(await fetchModel('a', 'https://x/a.task', 1, fetchMock))]).toEqual([4]);
  });
});
