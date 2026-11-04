import { describe, it, expect } from 'vitest';
import { LEGAL, legalText, CONTACT_EMAIL } from './legalContent';

describe('testi legali', () => {
  it('italiano e inglese hanno le stesse sezioni', () => {
    for (const page of ['privacy', 'support', 'deletion']) {
      expect(LEGAL.en[page].sections.length).toBe(LEGAL.it[page].sections.length);
    }
  });

  it('privacy: nomina tutti i fornitori dichiarati nel Privacy Manifest e nelle note', () => {
    const text = JSON.stringify(LEGAL.it.privacy);
    for (const name of ['Supabase', 'Irlanda', 'Open-Meteo', 'microlink.io', 'Resend', 'GitHub', 'MediaPipe']) {
      expect(text).toContain(name);
    }
    expect(text).toContain(CONTACT_EMAIL);
  });

  it('la pagina di eliminazione spiega il percorso nell\'app e quello senza accesso', () => {
    const text = JSON.stringify(LEGAL.it.deletion);
    expect(text).toContain('Elimina account');
    expect(text).toContain(CONTACT_EMAIL);
  });

  it('legalText: lingua dell\'interfaccia, italiano se sconosciuta', () => {
    expect(legalText('en-GB')).toBe(LEGAL.en);
    expect(legalText('fr')).toBe(LEGAL.it);
    expect(legalText(undefined)).toBe(LEGAL.it);
  });
});
