import { describe, it, expect, vi, beforeEach } from 'vitest';

// Supabase finto: la colonna "theme" non esiste ancora (migrazione 003 non applicata)
const calls = [];
vi.mock('./supabaseClient', () => ({
  isSupabaseEnabled: true,
  supabase: {
    from: () => ({
      upsert: async (row) => {
        calls.push(row);
        return 'theme' in row ? { error: { message: 'column "theme" does not exist' } } : { error: null };
      },
    }),
  },
}));

const { upsertProfile } = await import('./db');

describe('upsertProfile senza la migrazione 003', () => {
  beforeEach(() => {
    calls.length = 0;
  });

  it('il tema non trascina lingua e città nel fallimento', async () => {
    await upsertProfile('u1', { language: 'it', defaultCity: { name: 'Milano' }, theme: 'dark' });
    const saved = calls.find((row) => row.language === 'it');
    expect(saved).toBeTruthy();
    expect('theme' in saved).toBe(false);
  });
});
