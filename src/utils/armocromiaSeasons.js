/**
 * Le 12 sotto-stagioni: palette, colori da evitare, neutri, metallo, make-up.
 * Dati curati sul canone armocromia (sci-art 12 toni). I nameKey puntano a
 * i18n: i nomi colore servono anche come query per i link shop.
 */
const C = (hex, id) => ({ hex, nameKey: `armocromia.colors.${id}` });

const season = (id, data) => [id, {
  id, nameKey: `armocromia.seasons.${id}.name`, descKey: `armocromia.seasons.${id}.desc`, ...data,
}];

export const SEASONS = Object.fromEntries([
  season('light-spring', {
    palette: [C('#ffcba4', 'pesca'), C('#f4a460', 'albicocca'), C('#ff7f6a', 'corallo'),
              C('#b2d8b2', 'menta'), C('#87ceeb', 'azzurro-polvere'), C('#fff44f', 'limone')],
    avoid: [C('#000000', 'nero'), C('#4b0082', 'viola'), C('#800020', 'bordeaux')],
    neutrals: [C('#fffdd0', 'crema'), C('#f5f5dc', 'beige'), C('#c3b091', 'sabbia')],
    metal: 'gold',
    makeup: {
      lips: [C('#ff7f6a', 'corallo'), C('#ffb09a', 'pesca')],
      blush: [C('#ffb09a', 'pesca')],
      eyes: [C('#c3b091', 'sabbia'), C('#b87333', 'rame')],
      foundationUndertone: 'warm',
    },
  }),
  season('light-summer', {
    palette: [C('#e6c9d3', 'rosa-cipria'), C('#b6a8d4', 'lavanda'), C('#a9c1cf', 'azzurro-polvere'),
              C('#98b4a6', 'menta'), C('#d3a4b5', 'malva'), C('#a3b8cc', 'blu-ghiaccio')],
    avoid: [C('#ff5f00', 'arancio'), C('#8b4513', 'ruggine'), C('#000000', 'nero')],
    neutrals: [C('#c9c0bb', 'grigio-perla'), C('#b8a89a', 'tortora'), C('#f2efe9', 'bianco-caldo')],
    metal: 'silver',
    makeup: {
      lips: [C('#d38fa4', 'rosa-antico'), C('#c98b9b', 'malva')],
      blush: [C('#e3b7c0', 'rosa-cipria')],
      eyes: [C('#b8a89a', 'tortora'), C('#8e9aaf', 'blu-ghiaccio')],
      foundationUndertone: 'cool',
    },
  }),
  season('true-spring', {
    palette: [C('#ffa812', 'giallo-dorato'), C('#7bb661', 'verde-erba'), C('#ff7f50', 'corallo'),
              C('#40e0d0', 'turchese'), C('#ff6347', 'rosso-pomodoro'), C('#ffcba4', 'pesca')],
    avoid: [C('#000000', 'nero'), C('#c9c0bb', 'grigio-perla'), C('#722f37', 'vinaccia')],
    neutrals: [C('#fffdd0', 'crema'), C('#c19a6b', 'cammello'), C('#f2efe9', 'bianco-caldo')],
    metal: 'gold',
    makeup: {
      lips: [C('#ff7f50', 'corallo'), C('#ff6347', 'rosso-pomodoro')],
      blush: [C('#ffcba4', 'pesca')],
      eyes: [C('#c19a6b', 'cammello'), C('#b87333', 'rame')],
      foundationUndertone: 'warm',
    },
  }),
  season('true-summer', {
    palette: [C('#7f9bb3', 'azzurro-polvere'), C('#c98b9b', 'malva'), C('#8e6c88', 'prugna'),
              C('#98b4a6', 'menta'), C('#6e7f9e', 'blu-navy'), C('#d38fa4', 'rosa-antico')],
    avoid: [C('#ff5f00', 'arancio'), C('#ffa812', 'giallo-dorato'), C('#8b4513', 'ruggine')],
    neutrals: [C('#c9c0bb', 'grigio-perla'), C('#5d6970', 'grigio-antracite'), C('#f2efe9', 'bianco-caldo')],
    metal: 'silver',
    makeup: {
      lips: [C('#c98b9b', 'malva'), C('#b76e79', 'rosa-antico')],
      blush: [C('#e3b7c0', 'rosa-cipria')],
      eyes: [C('#8e9aaf', 'blu-ghiaccio'), C('#9a8f83', 'tortora')],
      foundationUndertone: 'cool',
    },
  }),
  season('true-autumn', {
    palette: [C('#b7410e', 'ruggine'), C('#808000', 'oliva'), C('#e2725b', 'terracotta'),
              C('#ffdb58', 'senape'), C('#b87333', 'rame'), C('#01796f', 'verde-pino')],
    avoid: [C('#ff69b4', 'rosa-shocking'), C('#a3b8cc', 'blu-ghiaccio'), C('#c9c0bb', 'grigio-perla')],
    neutrals: [C('#c19a6b', 'cammello'), C('#7b3f00', 'marrone-cioccolato'), C('#c3b091', 'kaki')],
    metal: 'gold',
    makeup: {
      lips: [C('#e2725b', 'terracotta'), C('#b7410e', 'ruggine')],
      blush: [C('#e2725b', 'terracotta')],
      eyes: [C('#7b3f00', 'marrone-cioccolato'), C('#808000', 'oliva')],
      foundationUndertone: 'warm',
    },
  }),
  season('true-winter', {
    palette: [C('#e0115f', 'fucsia'), C('#4169e1', 'blu-royal'), C('#50c878', 'smeraldo'),
              C('#dc143c', 'rosso-ciliegia'), C('#8e4585', 'viola'), C('#00a86b', 'verde-pino')],
    avoid: [C('#e2725b', 'terracotta'), C('#ffdb58', 'senape'), C('#c3b091', 'sabbia')],
    neutrals: [C('#000000', 'nero'), C('#ffffff', 'bianco-puro'), C('#36454f', 'grigio-antracite')],
    metal: 'silver',
    makeup: {
      lips: [C('#dc143c', 'rosso-ciliegia'), C('#e0115f', 'fucsia')],
      blush: [C('#d38fa4', 'rosa-antico')],
      eyes: [C('#36454f', 'grigio-antracite'), C('#4f2f4f', 'prugna')],
      foundationUndertone: 'cool',
    },
  }),
  season('bright-spring', {
    palette: [C('#ff4040', 'rosso-pomodoro'), C('#2e8b74', 'smeraldo'), C('#ff7f50', 'corallo'),
              C('#00bfff', 'turchese'), C('#ffd700', 'giallo-dorato'), C('#ff69b4', 'rosa-shocking')],
    avoid: [C('#9a8f83', 'tortora'), C('#c9c0bb', 'grigio-perla'), C('#808000', 'oliva')],
    neutrals: [C('#fffdd0', 'crema'), C('#36454f', 'grigio-antracite'), C('#c19a6b', 'cammello')],
    metal: 'gold',
    makeup: {
      lips: [C('#ff4040', 'rosso-pomodoro'), C('#ff7f50', 'corallo')],
      blush: [C('#ffb09a', 'pesca')],
      eyes: [C('#b87333', 'rame'), C('#2e8b74', 'smeraldo')],
      foundationUndertone: 'warm',
    },
  }),
  season('bright-winter', {
    palette: [C('#ff1493', 'fucsia'), C('#0047ab', 'blu-royal'), C('#00ffef', 'turchese'),
              C('#dc143c', 'rosso-ciliegia'), C('#9932cc', 'viola'), C('#01796f', 'verde-pino')],
    avoid: [C('#c3b091', 'sabbia'), C('#e2725b', 'terracotta'), C('#9a8f83', 'tortora')],
    neutrals: [C('#000000', 'nero'), C('#ffffff', 'bianco-puro'), C('#2c3539', 'grigio-antracite')],
    metal: 'silver',
    makeup: {
      lips: [C('#dc143c', 'rosso-ciliegia'), C('#ff1493', 'fucsia')],
      blush: [C('#e3b7c0', 'rosa-cipria')],
      eyes: [C('#2c3539', 'grigio-antracite'), C('#191970', 'blu-navy')],
      foundationUndertone: 'cool',
    },
  }),
  season('soft-autumn', {
    palette: [C('#c3a38a', 'sabbia'), C('#9caf88', 'verde-salvia'), C('#d19a6a', 'miele'),
              C('#b5836d', 'terracotta'), C('#8f9779', 'oliva'), C('#c08081', 'rosa-antico')],
    avoid: [C('#ff1493', 'fucsia'), C('#0047ab', 'blu-royal'), C('#000000', 'nero')],
    neutrals: [C('#b8a89a', 'tortora'), C('#c3b091', 'kaki'), C('#f5f5dc', 'beige')],
    metal: 'gold',
    makeup: {
      lips: [C('#c08081', 'rosa-antico'), C('#b5836d', 'terracotta')],
      blush: [C('#d19a6a', 'miele')],
      eyes: [C('#8f9779', 'oliva'), C('#b8a89a', 'tortora')],
      foundationUndertone: 'neutral',
    },
  }),
  season('soft-summer', {
    palette: [C('#8496a0', 'blu-ghiaccio'), C('#c8a2c8', 'lilla'), C('#9caf88', 'verde-salvia'),
              C('#b784a7', 'malva'), C('#6e7f9e', 'blu-navy'), C('#c08081', 'rosa-antico')],
    avoid: [C('#ff5f00', 'arancio'), C('#ffd700', 'giallo-dorato'), C('#b7410e', 'ruggine')],
    neutrals: [C('#c9c0bb', 'grigio-perla'), C('#b8a89a', 'tortora'), C('#5d6970', 'grigio-antracite')],
    metal: 'silver',
    makeup: {
      lips: [C('#b784a7', 'malva'), C('#c08081', 'rosa-antico')],
      blush: [C('#e3b7c0', 'rosa-cipria')],
      eyes: [C('#8496a0', 'blu-ghiaccio'), C('#9a8f83', 'tortora')],
      foundationUndertone: 'cool',
    },
  }),
  season('deep-autumn', {
    palette: [C('#722f37', 'vinaccia'), C('#01796f', 'verde-pino'), C('#b7410e', 'ruggine'),
              C('#ffdb58', 'senape'), C('#7b3f00', 'marrone-cioccolato'), C('#e2725b', 'terracotta')],
    avoid: [C('#e6c9d3', 'rosa-cipria'), C('#a3b8cc', 'blu-ghiaccio'), C('#c9c0bb', 'grigio-perla')],
    neutrals: [C('#3d2b1f', 'marrone-cioccolato'), C('#000000', 'nero'), C('#c19a6b', 'cammello')],
    metal: 'gold',
    makeup: {
      lips: [C('#722f37', 'vinaccia'), C('#b7410e', 'ruggine')],
      blush: [C('#e2725b', 'terracotta')],
      eyes: [C('#3d2b1f', 'marrone-cioccolato'), C('#01796f', 'verde-pino')],
      foundationUndertone: 'warm',
    },
  }),
  season('deep-winter', {
    palette: [C('#800020', 'bordeaux'), C('#191970', 'blu-navy'), C('#50c878', 'smeraldo'),
              C('#8e4585', 'prugna'), C('#dc143c', 'rosso-ciliegia'), C('#008080', 'petrolio')],
    avoid: [C('#ffcba4', 'pesca'), C('#c3b091', 'sabbia'), C('#d19a6a', 'miele')],
    neutrals: [C('#000000', 'nero'), C('#ffffff', 'bianco-puro'), C('#36454f', 'grigio-antracite')],
    metal: 'silver',
    makeup: {
      lips: [C('#800020', 'bordeaux'), C('#dc143c', 'rosso-ciliegia')],
      blush: [C('#8e4585', 'prugna')],
      eyes: [C('#36454f', 'grigio-antracite'), C('#191970', 'blu-navy')],
      foundationUndertone: 'cool',
    },
  }),
]);

export const getSeason = (id) => SEASONS[id] || null;
