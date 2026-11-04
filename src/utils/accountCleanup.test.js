import { describe, it, expect } from 'vitest';
import { keysToForget } from './accountCleanup';

describe('keysToForget', () => {
  it('toglie i dati personali e tiene lingua, tema e modelli scaricati', () => {
    const keys = [
      'sv_auth_user',
      'sv_cloud_cache_u1',
      'sv_profile_u1',
      'sv_outfit_place',
      'sv_weather_openmeteo_position',
      'sv_items',
      'sv_settings',
      'sv_models_ready_vision',
      'sv_chunk_reload',
      'altro_sito',
    ];
    expect(keysToForget(keys).sort()).toEqual(
      [
        'sv_auth_user',
        'sv_cloud_cache_u1',
        'sv_items',
        'sv_outfit_place',
        'sv_profile_u1',
        'sv_weather_openmeteo_position',
      ].sort()
    );
  });

  it('nessuna chiave → niente da togliere', () => {
    expect(keysToForget([])).toEqual([]);
  });
});
