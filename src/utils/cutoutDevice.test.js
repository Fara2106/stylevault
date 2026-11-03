import { describe, it, expect, vi, beforeEach } from 'vitest';
import { cutoutWithGpuFallback, resetGpuFallback } from './cutoutDevice';

describe('cutoutWithGpuFallback', () => {
  beforeEach(() => resetGpuFallback());

  it('chiede la GPU, senza proxy (siamo già in un worker)', async () => {
    const remove = vi.fn().mockResolvedValue('blob-gpu');
    expect(await cutoutWithGpuFallback(remove, 'foto')).toBe('blob-gpu');
    expect(remove).toHaveBeenCalledWith('foto', { device: 'gpu', proxyToWorker: false });
  });

  it('se la GPU fallisce ritenta su CPU e non la richiede più', async () => {
    const remove = vi
      .fn()
      .mockRejectedValueOnce(new Error('webgpu'))
      .mockResolvedValue('blob-cpu');
    expect(await cutoutWithGpuFallback(remove, 'a')).toBe('blob-cpu');
    expect(await cutoutWithGpuFallback(remove, 'b')).toBe('blob-cpu');
    expect(remove.mock.calls.map((c) => c[1].device)).toEqual(['gpu', 'cpu', 'cpu']);
  });
});
