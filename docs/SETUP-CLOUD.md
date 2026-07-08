# StyleVault — Attivare il cloud (Supabase) e pubblicare online

L'app funziona già in **modalità locale** (dati nel browser, login simulato).
Questa guida attiva account veri, foto sul cloud e sincronizzazione tra
dispositivi, e pubblica il sito. Servono ~20 minuti e due account gratuiti.

## 1. Crea il progetto Supabase (gratuito)

1. Vai su https://supabase.com → **Start your project** → registrati (va bene GitHub o Google).
2. **New project**: scegli nome (es. `stylevault`), password del database (salvala), regione `eu-central-1` (Francoforte, la più vicina).
3. Attendi ~2 minuti che il progetto sia pronto.

## 2. Crea le tabelle

1. Nel progetto: menu **SQL Editor** → **New query**.
2. Copia tutto il contenuto di [`supabase/migrations/001_init.sql`](../supabase/migrations/001_init.sql) e incollalo.
3. **Run**. Deve dire "Success". Questo crea tabelle, sicurezza per-utente (RLS), bucket foto e profilo automatico alla registrazione.

## 3. Collega l'app

1. Nel progetto Supabase: **Project Settings → API**. Copia **Project URL** e **anon public key**.
2. Nella cartella dell'app, copia `.env.example` in `.env.local` e incolla i due valori:
   ```
   VITE_SUPABASE_URL=https://xxxx.supabase.co
   VITE_SUPABASE_ANON_KEY=eyJ...
   ```
3. Riavvia `npm run dev`. Da questo momento l'app è in modalità cloud: la
   registrazione crea un account vero e i dati vanno su Supabase.

**Nota email di conferma:** di default Supabase invia una email di conferma alla
registrazione. Per disattivarla durante i test: **Authentication → Providers →
Email → disabilita "Confirm email"**.

## 4. (Facoltativo) Accesso con Google

1. **Authentication → Providers → Google → Enable**.
2. Segui le istruzioni nella pagina per creare le credenziali OAuth su Google
   Cloud Console e incolla Client ID e Secret.
3. Il bottone "Continua con Google" nell'app funziona da solo appena il
   provider è attivo.

## 5. (Facoltativo) Lettura link shop più robusta

Senza questo passo i link degli shop passano da microlink.io (50 richieste/giorno).
Con la Edge Function il limite sparisce:

```bash
npm install -g supabase
supabase login
supabase link --project-ref <ref-del-progetto>   # lo trovi nell'URL del progetto
supabase functions deploy fetch-link-metadata --no-verify-jwt
```

## 6. Pubblica su Vercel (gratuito)

1. Vai su https://vercel.com → registrati → **Add New → Project**.
2. Importa la cartella del progetto (via GitHub, oppure `npm i -g vercel && vercel` dal terminale).
3. In **Environment Variables** aggiungi `VITE_SUPABASE_URL` e `VITE_SUPABASE_ANON_KEY` con gli stessi valori del punto 3.
4. Deploy. Il file `vercel.json` è già pronto (gestisce le rotte dell'app).
5. In Supabase: **Authentication → URL Configuration → Site URL** = l'indirizzo
   Vercel (es. `https://stylevault.vercel.app`), così login e Google
   reindirizzano al posto giusto.

## Come verificare che il cloud è attivo

- La pagina di login mostra il bottone **"Continua con Google"** (in locale
  mostra invece la nota "arriva con la versione online").
- Registrati, aggiungi un capo con foto, apri l'app da un altro browser o dal
  telefono con lo stesso account: il capo c'è.
