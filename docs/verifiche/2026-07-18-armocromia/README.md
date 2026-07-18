# Verifica a schermo — Armocromia (2026-07-18)

Flusso completo guidato in Chrome headless (puppeteer-core, dev server in
modalità locale) su una **foto vera** (docs/verifiche/2026-07-16-su-di-te/
risultato-warping-posa.jpg come foto di riferimento del profilo).

| Screenshot | Cosa mostra |
|---|---|
| `armo-01-card-profilo.png` | card "Armocromia — scopri i tuoi colori" nel Profilo |
| `armo-02-intro.png` | pagina /armocromia, invito con hint sulla luce |
| `armo-03-colori-trovati.png` | colori estratti: pelle `#b38b73`, capelli `#4d4038`, occhi non trovati (foto piccola) |
| `armo-04-verdetto.png` | verdetto "Inverno Profondo" + palette/neutri/evitare/metalli; avviso di verdetto incerto (11%) |
| `armo-05-outfit-shop.png` | combo outfit con link Zalando/ASOS/Amazon (query `maglia bordeaux` ecc.) |
| `armo-06-guardaroba-makeup.png` | capi del guardaroba in palette + make-up con link Sephora/Douglas/Amazon |
| `armo-07-riaperto-salvato.png` | dopo il reload la pagina riapre direttamente sul risultato salvato |

Esiti osservati:
- estrazione on-device reale (MediaPipe scaricato al primo uso, poi cache);
- occhi non trovati → la correzione manuale col picker funziona (impostato
  `#4f6b8f` via evento sul color input, il ricalcolo lo usa);
- salvataggio → `sv_profile_*.armocromia.season = 'deep-winter'`, riapertura
  diretta sul risultato;
- console: zero errori (solo gli INFO attesi di TensorFlow Lite).

**PENDENTE: la verifica umana di Lorenzo** (foto sua vera, luce naturale, e la
sensatezza estetica del verdetto). NB per il deploy: applicare
`supabase/migrations/002_armocromia.sql` al DB live PRIMA del merge.
