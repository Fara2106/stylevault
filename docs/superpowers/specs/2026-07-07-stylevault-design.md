# StyleVault — Design della prima versione pubblica

**Data:** 2026-07-07
**Stato:** approvato dall'utente (brainstorming completato)
**Nome di lavoro:** StyleVault (modificabile in seguito)

## 1. Visione

App web mobile-first per gestire il proprio guardaroba digitale e ricevere proposte di outfit
basate sul meteo reale del luogo scelto. Prodotto pubblico multi-utente, gratuito al lancio.

Flusso tipico: l'utente apre l'app → sceglie città e giorno ("domani a Milano, 8° e pioggia") →
riceve 3 proposte di outfit dal proprio guardaroba adatte a temperatura, condizioni e occasione →
blocca i capi che vuole tenere e rigenera gli altri → prova l'outfit sull'avatar → lo assegna a
un giorno nel calendario.

## 2. Decisioni chiave (dal brainstorming)

| Aspetto | Decisione |
|---|---|
| Pubblico | Prodotto pubblico multi-utente |
| Backend | Supabase (auth, Postgres, Storage, Edge Functions) |
| Aggiunta capo via foto | Foto + form manuale; nessuna AI di riconoscimento |
| Aggiunta capo via link | Estrazione automatica di immagine/titolo/sito dai metadati Open Graph via Edge Function; fallback a form manuale |
| Meteo | Ricerca città manuale (nessun GPS), API Open-Meteo (attuale + 7 giorni) |
| Avatar | Figura 2D stilizzata SVG, configurata manualmente con foto dell'utente come riferimento visivo; foto e configurazione salvate su cloud |
| Try-on | Composizione a slot delle foto reali dei capi sull'avatar (styling board); nessuna AI generativa |
| Consigli | Basati su regole (armonia colori, meteo, occasione, ripetizione); nessuna AI |
| Scope v1 | Nucleo + wishlist + calendario outfit + statistiche |
| Stile visivo | Lusso "light editorial": crema/avorio, nero inchiostro, serif editoriale |
| Lingue | Italiano e inglese (i18next, già presente) |
| Costi al lancio | Zero: piani gratuiti Supabase + Open-Meteo + hosting statico (Vercel/Netlify) |

## 3. Architettura

### 3.1 Stack

- **Frontend:** React 19 + Vite (SPA), react-router-dom v7, i18next. CSS puro con variabili
  centralizzate (design system), coerente con i componenti già scritti.
- **Backend:** Supabase — Auth (email+password e Google OAuth), Postgres con Row Level
  Security, Storage per le foto, una Edge Function per la lettura dei link shop.
- **Meteo:** Open-Meteo (geocoding per ricerca città + forecast). Gratuita, senza chiave.

### 3.2 Stato attuale del codice e risanamento

Il repo contiene fondamenta valide ma l'app non è avviabile come React:

- **Da riusare:** `src/utils/` (outfitAlgorithm, colorHarmony, weatherMapper, categories),
  `src/context/` (Wardrobe, Auth, Settings — da adattare a Supabase), `src/components/`
  (ClothingCard, OutfitCard, WeatherBadge, CategoryFilter, BottomNav, LanguageSwitch, common),
  `src/i18n/` (it/en).
- **Da rifondare:** bootstrap dell'app. React e react-dom non sono installati; `src/main.ts` è
  ancora il template Vite vanilla (counter). Vanno installate le dipendenze React, creato
  `src/main.jsx` + `src/App.jsx` con router e provider, eliminati `counter.ts`, `main.ts` e
  gli asset del template.
- **Da adattare:** `WardrobeContext` oggi persiste su localStorage; passa a query Supabase.
  `AuthContext` passa a Supabase Auth. localStorage resta solo come cache di lettura
  (consultazione offline) e per preferenze locali.

### 3.3 Schema dati (Postgres)

Tutte le tabelle hanno `user_id` con RLS: ogni utente legge/scrive solo le proprie righe.

- **profiles** — `id` (= auth.uid), `display_name`, `default_city` (nome + lat/lon),
  `language`, `avatar_config` (jsonb: corporatura, carnagione, colore e taglio capelli),
  `reference_photo_path` (foto dell'utente su Storage, privata), `created_at`.
- **items** — `id`, `user_id`, `name`, `category`, `subcategory`, `brand`, `size`,
  `colors` (array di id colore), `season`, `occasion`, `warmth_level` (1–5),
  `photo_path` (Storage) **oppure** `photo_url` (immagine estratta da shop),
  `source_url` (link shop di origine, nullable), `price` (nullable, per statistiche),
  `favorite`, `created_at`.
- **outfits** — `id`, `user_id`, `name`, `item_ids` (array), `occasion`, `score`,
  `created_at`.
- **wishlist_items** — stessi campi di `items` + `source_url` obbligatorio; azione
  "sposta nel guardaroba" che converte la riga in `items`.
- **calendar_entries** — `id`, `user_id`, `date`, `outfit_id`, `worn` (boolean:
  pianificato vs indossato), `created_at`. Vincolo: una entry per utente per data.

Storage: bucket `wardrobe-photos` (foto capi) e `profile-photos` (foto riferimento avatar),
entrambi privati con policy per-utente. Le immagini vengono ridimensionate lato client
(max ~1200px, jpeg) prima dell'upload.

### 3.4 Edge Function `fetch-link-metadata`

Input: URL di una pagina prodotto. Comportamento: scarica l'HTML lato server, estrae
`og:image`, `og:title`, `og:site_name` (fallback: `<title>`, prima immagine grande).
Output: `{ image, title, site }` oppure errore tipizzato. Timeout 8s. Non salva nulla:
è l'app client che compila il form con i valori estratti e l'utente completa e conferma.

## 4. Pagine e flussi

Navigazione principale con BottomNav (5 voci: Guardaroba, Outfit, Aggiungi, Calendario,
Profilo). Wishlist raggiungibile dal Guardaroba (tab) e dal Profilo.

1. **Login/Registrazione** — email+password e Google. Onboarding al primo accesso:
   (a) creazione avatar con caricamento opzionale della propria foto come riferimento,
   (b) città predefinita, (c) invito ad aggiungere i primi capi. Nessun dato di esempio
   precaricato in produzione (i SAMPLE_ITEMS attuali restano solo per sviluppo).
2. **Guardaroba (home)** — griglia foto, filtri categoria (riuso CategoryFilter), ricerca
   testuale, toggle preferiti, tab Wishlist. Tocco su capo → Dettaglio capo.
3. **Dettaglio capo** — foto grande, tutti gli attributi, link allo shop se presente,
   modifica/elimina, "in quanti outfit compare", "ultima volta indossato".
4. **Aggiungi capo** — scelta percorso Foto o Link.
   - *Foto:* scatto/upload → ritaglio quadrato opzionale → form (nome, categoria,
     sottocategoria, colori multipli, stagione, occasione, calore 1–5, brand, taglia,
     prezzo opzionale).
   - *Link:* incolla URL → chiamata alla Edge Function → anteprima immagine+titolo
     precompilati → stesso form. Destinazione: guardaroba o wishlist.
5. **Outfit** — selettore città (ricerca per nome, default profilo) + selettore giorno
   (oggi–7gg) + occasione. Mostra WeatherBadge (temperatura min/max, condizione).
   Genera 3 proposte con punteggio e consigli testuali. Azioni per proposta: blocca capo
   (lucchetto) e rigenera, salva outfit, prova sull'avatar.
6. **Prova sull'avatar** — avatar SVG dell'utente con le foto dei capi disposte a slot
   (capospalla dietro/sopra il busto, top sul busto, bottom sulle gambe, scarpe ai piedi,
   accessori a lato). Palette colori dell'outfit e consigli sotto. Accessibile da outfit
   proposti, salvati e dalla wishlist (mix capi posseduti + desiderati).
7. **Calendario** — vista mensile + lista. Assegna outfit a date future (accanto: meteo
   previsto se entro 7 giorni); segna come "indossato"; storico. Avviso se l'outfit
   assegnato è stato indossato negli ultimi 7 giorni.
8. **Profilo** — editor avatar (con foto di riferimento affiancata), foto riferimento
   sostituibile/eliminabile, città predefinita, lingua, logout, eliminazione account.
   Sezione **Statistiche**: capi più/meno indossati (da calendar_entries con worn=true),
   ripartizione per colore e categoria, costo-per-utilizzo (solo capi con prezzo).

## 5. Avatar e motore outfit

### 5.1 Avatar

- SVG stilizzato, estetica da figurino di moda coerente con lo stile lusso.
- Parametri: corporatura (4–5 sagome), carnagione (6–8 tonalità), capelli (colore +
  5–6 tagli). Salvati in `profiles.avatar_config`, sincronizzati tra dispositivi.
- Configurazione manuale; se l'utente carica una propria foto, questa appare affiancata
  all'editor come riferimento visivo. La foto è privata e salvata su Storage.
- Try-on a slot: le foto reali dei capi si dispongono sulle zone della sagoma con
  z-order fisso (capospalla > top > bottom; scarpe e accessori in aree dedicate).
  Nessuna deformazione delle immagini: collage curato, non fotorealismo.

### 5.2 Motore outfit (riuso + estensioni)

Riuso di `outfitAlgorithm.js` (filtra per stagione/occasione, compone top+bottom+scarpe
[+capospalla se il target di calore lo richiede], punteggia su calore-vs-temperatura,
armonia colori, occasione; restituisce le 3 migliori). Estensioni:

1. **Blocco capo:** parametro `lockedItemIds`; le combinazioni generate contengono
   sempre i capi bloccati, si rigenera solo il resto.
2. **Penalità ripetizione:** i capi/outfit presenti in `calendar_entries` (worn=true)
   negli ultimi 7 giorni ricevono una penalità di punteggio decrescente con i giorni.
3. **Input meteo reale:** `weatherMapper` riceve i dati Open-Meteo del giorno scelto
   (temperatura percepita min/max, probabilità pioggia) e produce il target di calore
   e i vincoli (pioggia → penalizza calzature aperte, richiede capo esterno adeguato).

### 5.3 Consigli (rule-based)

Generati dagli stessi punteggi, come frasi localizzate (it/en):

- armonia colori (complementari/analoghi/troppi colori accesi → suggerisci neutro);
- meteo (sotto/sopra il target di calore, pioggia, escursione giorno/sera);
- occasione (capo che eleva o abbassa la formalità);
- varietà (outfit o capo indossato di recente).

## 6. Design system "light editorial"

- **Palette:** fondo `#FAF7F2` (crema), superficie `#FFFFFF`, testo `#1A1A1A` (inchiostro),
  testo secondario `#6B6560`, accento `#8B7355` (terra/bronzo, uso parco), bordi `#E5DFD6`.
- **Tipografia:** Playfair Display (titoli, numeri statistiche), Inter (corpo, form).
  Maiuscoletto spaziato per label ed etichette di sezione.
- **Componenti:** bordi sottili al posto di ombre pesanti, raggi 4–8px, spaziatura
  generosa, transizioni 150–200ms. Variabili CSS in `src/styles/tokens.css`; i componenti
  esistenti (Button, Input, Modal, Header, card) vengono rivestiti con i token.
- Mobile-first (breakpoint principali 480/768/1024); da desktop la griglia guardaroba
  si allarga e la BottomNav scompare a favore della navigazione nell'header (stile
  testata di rivista).

## 7. Gestione errori

- **Upload foto fallito:** retry automatico (2 tentativi), form che conserva i dati
  inseriti; errore mostrato con azione "riprova".
- **Link shop illeggibile:** messaggio chiaro ("questo negozio non permette la lettura
  automatica"), passaggio al form manuale, `source_url` comunque salvato.
- **Meteo non disponibile:** si usa l'ultima previsione in cache con indicazione
  dell'orario; in mancanza, input manuale di temperatura e condizione per generare
  comunque l'outfit.
- **Guardaroba insufficiente:** messaggio garbato che indica le categorie mancanti
  per comporre outfit completi.
- **Offline:** guardaroba e outfit salvati consultabili dalla cache di lettura;
  scritture bloccate con messaggio; nessuna sync offline in v1.
- **Errori Supabase/auth:** messaggi localizzati non tecnici + retry; sessione scaduta →
  redirect a login senza perdita del form in corso (bozza in localStorage).

## 8. Test e verifica

- **Unit (Vitest):** outfitAlgorithm (incluse estensioni blocco/ripetizione),
  colorHarmony, weatherMapper (mapping temperatura→target calore, pioggia),
  logica statistiche, conversione wishlist→guardaroba.
- **Integrazione con mock Supabase:** flussi aggiunta capo (foto e link), generazione
  outfit end-to-end con meteo mockato, salvataggio calendario, RLS attesa (un utente
  non vede dati altrui — test sulle query).
- **Verifica manuale pre-lancio:** flussi foto/upload da mobile reale, editor avatar,
  resa del design system su iOS/Android/desktop.

## 9. Fasatura dell'implementazione (decisione utente, 2026-07-07)

**Fase A — Solo UI (da fare ora):** tutta l'interfaccia e i flussi delle 8 pagine,
design system light editorial, avatar, motore outfit con le estensioni, meteo reale
Open-Meteo. Persistenza su localStorage (i contexts esistenti già lo fanno): l'app è
pienamente usabile in locale su un solo dispositivo. Login simulato (AuthContext
locale), nessun account reale. La Edge Function per i link non esiste ancora: in
questa fase l'estrazione dai link usa un servizio proxy pubblico se praticabile,
altrimenti solo form manuale con link salvato.

**Fase B — Backend (dopo la validazione della UI):** Supabase come da sezione 3;
i contexts passano da localStorage alle query Supabase senza toccare le pagine.

## 10. Fuori scope v1 (fase 2+)

- AI di riconoscimento capi da foto; rimozione sfondo.
- Try-on fotorealistico AI.
- Tracking prezzi wishlist.
- Condivisione social/outfit pubblici.
- App native e sync offline completa.
- Monetizzazione.
