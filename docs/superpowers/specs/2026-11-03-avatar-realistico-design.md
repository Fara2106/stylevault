# Avatar realistico sull'iPhone (Mobile-VTON): Design

**Data:** 2026-11-03
**Stato:** bozza, da approvare da parte di Lorenzo
**Base:** branch `feat/app-ios` (app iOS con avatar "collage" in 3 viste,
correzioni del 2026-11-03 su scarpe, sagoma e vista sbagliata)

## 1. Perché

L'avatar dell'app oggi è un **collage**: la foto piatta del capo, scontornata,
viene appoggiata sul corpo come un rettangolo. Anche dopo le correzioni del
2026-11-03 il capo non segue il corpo: maniche, spalle e orli non coincidono con
la persona. Lorenzo vuole i capi **«esattamente lungo le linee del corpo»**,
cioè **deformati** per coprire i lineamenti della persona.

Una prova usa-e-getta sul Mac (M1 Pro) con **Mobile-VTON** (CVPR 2026, modello
di prova virtuale pensato per girare sul telefono) ha dato un risultato quasi
fotografico: il maglione veste davvero la persona, con maniche ai polsi, pieghe
e volumi, la maglia originale sparisce, viso e mani restano intatti. Ha
funzionato anche a figura intera e **di spalle**. Con 10 passi la qualità è
quasi uguale a 28 (9 s di calcolo sul Mac). Risultati in
`docs/verifiche/2026-11-03-avatar-realistico/` (da copiare dalla scratchpad
della prova).

Alternative scartate: servizio esterno a pagamento (FASHN e simili, ~0,07 $ a
immagine, un capo per volta, 10–20 s, le foto escono dal telefono) e collage
deformato riga per riga (preciso ma senza pieghe né volumi).

## 2. Obiettivi

1. **Versione realistica della parte di sopra**, calcolata **sull'iPhone**,
   offline, gratis: le foto non escono dal telefono.
2. **Flusso** (deciso da Lorenzo):
   - si apre "Vedilo addosso" → parte **da sola** la versione realistica della
     vista **davanti**;
   - mentre calcola: **barra di avanzamento con percentuale** accanto;
   - finita la vista davanti, sotto compaiono i pulsanti **"Genera di profilo"**
     e **"Genera di spalle"**: ognuno parte solo quando lo si tocca, con la sua
     barra.
3. **Primo uso**: i modelli (~1 GB dopo la compressione) si scaricano **in
   automatico al primo "Vedilo addosso"**, una volta sola, **con la barra di
   avanzamento** (deciso da Lorenzo).
4. Ogni vista generata resta **salvata**: riaprendo lo stesso outfit compare
   subito, senza ricalcolo.

## 3. Non obiettivi

- **Pantaloni, gonne e scarpe**: Mobile-VTON cambia solo la parte di sopra.
  Restano col collage di oggi. Deformarli (per esempio riga per riga come
  `src/utils/modelWarp.js` del sito) è un progetto separato.
- **Uso commerciale**: la licenza di Mobile-VTON (codice e pesi) è
  **CC BY-NC-SA 4.0**, solo non commerciale. Va bene finché StyleVault è per
  Lorenzo e Mary. Se un giorno l'app dovesse guadagnare, questo modello va
  sostituito (o licenziato dagli autori): per questo il motore realistico sta
  dietro un'interfaccia sola (`RealisticTryOn`), così si cambia modello o si
  passa a un servizio a pagamento senza toccare la schermata.
  **Aggiornamento 2026-11-04 (Lorenzo):** l'app si pubblica **gratis** per
  tutti. È compatibile con la licenza solo senza pubblicità, acquisti in-app o
  abbonamenti, e con autori e licenza mostrati nell'app ("Crediti").
- Il **sito** non cambia: la versione realistica esiste solo nell'app iOS.
- Nessun servizio esterno, nessun costo a consumo.

## 4. Cosa sarebbe un fallimento (anche se "funziona")

- L'app resta bloccata o si chiude per memoria durante il calcolo.
- La barra resta ferma a lungo o va avanti "a caso": la percentuale deve essere
  vera (passi del calcolo).
- Il primo download parte senza che si capisca cosa sta succedendo, o si
  ricomincia da zero a ogni interruzione.
- Il risultato realistico copre il collage peggiorandolo (viso deformato,
  pantaloni o scarpe del collage cancellati).

## 5. Come funziona

### 5.1 Schermata "Vedilo addosso"

- Compare **subito il collage** di oggi (immediato). Sopra o sotto l'immagine,
  la barra "Versione realistica… 40%". Quando il calcolo finisce, il collage
  della vista davanti viene **sostituito** dalla versione realistica.
  *(Scelta mia: Lorenzo ha confermato il flusso, la presenza del collage durante
  l'attesa l'ho decisa io.)*
- Le altre due viste mostrano il collage finché non si tocca "Genera di
  profilo" / "Genera di spalle"; i pulsanti stanno sotto l'immagine e compaiono
  solo quando la vista davanti è pronta.
- Una sola generazione alla volta. Chiudendo la schermata il calcolo si ferma
  (nessun lavoro in background) e la vista non resta a metà.
- Primo uso: prima della generazione, barra del download "Scarico i modelli per
  la versione realistica… 35% (350 MB di 1 GB)".

### 5.2 Cosa entra nel modello

Per ogni vista: la foto del corpo di quella vista (quella già salvata nel
profilo), la foto del **capo della parte di sopra** e una breve descrizione del
capo.

- **Quale capo**: se l'outfit ha un capospalla, il realistico usa il
  **capospalla** (è quello che si vede); altrimenti il **top** (o l'abito). Il
  capo che non entra nel realistico resta col collage solo se non coperto.
  *(Scelta mia.)*
- **Di spalle**: se il capo ha la **foto del retro** (campo del sito), si usa
  quella, come fa già il collage.
- **Descrizione**: il modello vuole una frase in inglese tipo "The item is a
  cream cable-knit sweater with long sleeves…". Si costruisce dai dati del capo
  (nome, sottocategoria, colore) con un modello fisso; niente AI esterna.
  *(Scelta mia.)*
- **Inquadratura**: il modello è addestrato su foto 3:4 768×1024. La foto del
  corpo si porta a 3:4 aggiungendo bordo, come nella prova "figura intera" che
  ha funzionato.

### 5.3 Come si compone col resto

Il risultato del modello è la foto della persona con la parte di sopra
ridisegnata. Su questa si applicano poi **pantaloni e scarpe col collage**
(come oggi), così l'outfit è completo. Scontorno e posa si ricalcolano sul
risultato. Sul risultato realistico **non** si disegnano più top e capospalla
col collage.

Requisito: la parte di sopra realistica deve restare **sopra** i pantaloni del
collage (l'orlo del maglione copre la vita dei jeans, come oggi). Come
ottenerlo (per esempio ridisegnando sopra i pantaloni la zona della parte di
sopra) è lasciato a chi costruisce.

### 5.4 Salvataggio

Risultato per **capo usato + vista + foto del corpo** (la pagina Prova non
salva l'outfit, quindi la chiave sono gli id dei capi e il percorso della foto
del corpo: se si rifanno le foto o si cambia capo, si rigenera). In `Caches`,
come gli scontorni. *(Scelta mia.)*

## 6. Come si costruisce (parte tecnica)

### 6.1 Prima di tutto: prova tecnica sull'iPhone

Il rischio vero è la conversione. Il primo passo del piano è una **prova
tecnica** che risponde a due domande prima di costruire il resto:

1. Le reti di Mobile-VTON si convertono in **Core ML**? Sono tre parti: due
   reti "UNet" (tryon e garment), il codificatore e il decodificatore
   d'immagine (VAE), due codificatori di testo CLIP e un codificatore di
   immagine DINOv2.
2. Quanto ci mette **un passo** e quanta memoria usa sui due telefoni che lo
   useranno: l'**iPhone 18 Pro Max** di Lorenzo e l'**iPhone 15 Pro** di Mary
   (8 GB di RAM: è il limite che conta).

**Soglie per andare avanti** *(scelta mia)*: vista davanti completa in
**≤ 60 s sul 18 Pro Max** e **≤ 90 s sul 15 Pro**, senza che iOS chiuda l'app
per memoria sul 15 Pro. Se non ci si sta, ci si ferma e si torna da Lorenzo
prima di costruire il resto.

Note:

- I codificatori di testo si possono calcolare **sul Mac** una volta per frase
  modello e salvare gli "embedding", se la descrizione è fissa per categoria:
  così sull'iPhone non servono (−1,6 GB). Da valutare nella prova.
- Compressione dei pesi (palettizzazione a 6 bit, come fa Apple per Stable
  Diffusion) per scendere verso ~1 GB.
- **La conversione esegue codice scaricato** (il modello Python di
  Mobile-VTON): Claude Code la blocca, la lancia Lorenzo dal Terminale con
  i comandi che gli prepariamo, come nella prova del 2026-11-03.

### 6.2 Dove stanno i modelli

I modelli convertiti (~1 GB) **non** stanno nell'app: si scaricano al primo
uso da una **Release su GitHub** del repo di StyleVault (deciso da Lorenzo;
file fino a 2 GB, gratis), con ripresa se il download si interrompe e
controllo dell'integrità (hash). La Release riporta autori e licenza
CC BY-NC-SA 4.0 di Mobile-VTON, come chiede la licenza.

### 6.3 Nell'app

- Un servizio `RealisticTryOn` (nome indicativo) che carica i modelli Core ML,
  esegue i 10 passi, comunica l'avanzamento (passo n di 10) e restituisce
  l'immagine.
- Gira fuori dal thread principale; la schermata resta usabile (si può
  scorrere tra le viste).
- Se qualcosa va storto (modelli mancanti, memoria, errore): si resta sul
  collage con un messaggio breve, l'app non si chiude.

## 7. Come capiamo che funziona

Sul suo iPhone Lorenzo:

1. al primo "Vedilo addosso" vede la barra del download, poi quella del
   calcolo, e la vista davanti diventa realistica in **≤ 60 s**;
2. tocca "Genera di profilo" e "Genera di spalle" e ottiene le altre due viste;
3. riapre lo stesso outfit: le viste realistiche compaiono subito;
4. pantaloni e scarpe restano al loro posto sopra il risultato realistico;
5. chiude la schermata a metà calcolo: nessun blocco, nessun crash.

## 8. Deciso

- iPhone: quello di Lorenzo (18 Pro Max) e quello di Mary (15 Pro) — deciso
  da Lorenzo.
- Modelli su una Release GitHub del repo di StyleVault — deciso da Lorenzo.

Nota pratica: con l'Apple ID gratuito l'app installata da Xcode **scade dopo
7 giorni** e va reinstallata; il 15 Pro di Mary va collegato al Mac, con la
Modalità sviluppatore attiva, come è stato per quello di Lorenzo.

Deciso da me: il download del primo uso parte con qualsiasi rete, mostrando la
dimensione (~1 GB) nella barra.

## 9. Lasciato a chi costruisce

Nomi dei tipi, struttura dei file, formato della cache, testo esatto dei
messaggi, dettagli della conversione Core ML, numero di passi se 8 o 12
rendono meglio di 10.
