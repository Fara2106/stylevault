# Prova "Su modello" (overlay gratis sulla foto dell'utente) — design

**Data:** 2026-07-14
**Stato:** approvato (design-ahead). **Implementazione in coda dietro lo smistatore
scontorno capi** — richiede il ritaglio pulito del capo per non posare screenshot rotti.

## Idea

Un **terzo modo di visualizzazione gratis**, accanto a *3D* e *Piatto*: l'utente
vede i capi ritagliati **posati sulla propria foto** in posa standard. Gratis,
istantaneo, nessuna licenza (è la sua foto), nessuna AI generativa.

Nasce da un'osservazione di Lorenzo: siti che scontornano i capi e li fanno
indossare "in tempo reale, senza sembrare AI" alla foto di una persona. Tecnica:
**compositing 2D** (overlay del capo ritagliato), non generazione. Gratis e
real-time è possibile; il prezzo nascosto è che i capi restano **posati, non
indossati** (piatti, niente pieghe né occlusione). La resa realistica-addosso resta
alla scheda AI a pagamento.

## Decisioni prese (brainstorming)

- **Modo in più**, non sostitutivo: 3D e Piatto (avatar personalizzabile) restano;
  si aggiunge "Su modello". Nessuna perdita di personalizzazione.
- **La persona è l'utente stesso**: carica la propria foto → nessun problema di
  licenza. Si **riusa `referencePhoto`** che il Profilo già raccoglie per la scheda
  AI. Non un modello fisso fornito da noi, non foto stock.
- **Clausola posa standard sulla foto dell'utente**, gestita con **rilevamento
  posa in-browser + gate**: se non è una persona di fronte, in piedi, braccia lungo
  i fianchi → blocca e spiega (come il gate degli screenshot dello smistatore).
- **Overlay dei capi** come PNG ritagliati (prodotti dallo smistatore) in slot
  derivati dai punti chiave della posa.
- **Ripiego**: capo senza ritaglio pulito (screenshot degradato) → sagoma in tinta
  unita sul modello, mai lo screenshot.
- **Relazione con la scheda AI**: stesso input (la foto dell'utente), ma questo è
  il **gratis e posato**; "Sulla tua foto (AI)" resta il **realistico a pagamento**
  (~$0,04/foto, Gemini). Gratis e premium della stessa idea.

## Architettura

### Componenti

1. **Modo "Su modello"** — terzo tab di render accanto a 3D e Piatto (oggi
   `OutfitOnAvatar` / `TryOnPage` gestiscono i modi; qui va aggiunto il terzo).
2. **Foto di riferimento** — `referencePhoto` da `ProfileContext` (già esistente,
   già usata dalla scheda AI). Nessun nuovo input all'utente.
3. **Gate di posa** — al momento in cui l'utente imposta/aggiorna `referencePhoto`:
   un modello di pose in-browser (gratis, es. MediaPipe Pose o equivalente) verifica
   la posa standard. Se valida, estrae e salva i **punti chiave** normalizzati
   (spalle, fianchi, caviglie) insieme alla foto; se no, blocca con messaggio guida.
4. **Renderer overlay** — per ogni capo dell'outfit, posa il suo **PNG ritagliato**
   (dallo smistatore) in una regione derivata dai punti chiave:
   - top: spalle → fianchi
   - bottom: fianchi → caviglie
   - outerwear: sopra il top, spalle → fianchi (leggermente più largo)
   - scarpe: alle caviglie
   Ordine di sovrapposizione (z): bottom, top, outerwear, accessori. Nessuna
   deformazione pesante: la clausola posa-standard **sui capi** (già nello
   smistatore: capo ripreso di fronte/steso) li fa posare dritti.
5. **Ripiego** — capo con `kind:'flat'`/degradato (nessun ritaglio) → sagoma in
   tinta col colore del capo nella stessa regione, non lo screenshot.

### Flusso dati

```
IMPOSTA FOTO (Profilo) → pose detect → posa valida?
    → no  → blocca + spiega la posa
    → sì  → salva referencePhoto + keypoints normalizzati
RENDER "Su modello" → per ogni capo:
    ritaglio pulito? → overlay PNG nella regione da keypoints (con z-order)
                     → altrimenti sagoma tinta unita nella regione
```

### Dipendenze

- **Lo smistatore** (ritaglio pulito del capo) — prerequisito. Senza, si
  poserebbe lo stesso screenshot rotto, solo più evidente su una foto vera.
- **Modello di pose in-browser** — nuova dipendenza, ~qualche MB scaricato sul
  dispositivo alla prima volta (come la bg-removal ML dello smistatore).

## Limiti onesti (accettati)

- I capi restano **posati, non indossati**: piatti sopra la foto, niente pieghe né
  occlusione delle braccia (l'overlay sta sopra). Su una foto reale si nota più che
  sull'SVG stilizzato (valle perturbante).
- La posa va rispettata o il gate blocca; il rilevamento non è perfetto (tarare
  conservativo, come per lo smistatore).
- Capi con proporzioni molto diverse dalla posa frontale si posano peggio; la
  clausola posa-standard sui capi mitiga.

## Fuori scope

- Deformazione/drappeggio realistico dei capi (è la scheda AI a pagamento).
- Modello fisso fornito da noi / foto stock (scelto: la foto dell'utente).
- Gestione dell'occlusione (braccia davanti al capo).

## Sequenza

1. Chiudere e deployare lo **smistatore** (Piano 1 fatto; Piani 2-3 dopo).
2. Solo allora scrivere il **piano di implementazione** di questa feature (il piano
   riferisce l'API del ritaglio pulito che lo smistatore produce).
