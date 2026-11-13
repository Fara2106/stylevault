# App iOS StyleVault: installazione sul tuo iPhone

Prova "in locale" con l'Apple ID gratuito: niente App Store, niente
abbonamento. L'app installata così **scade dopo 7 giorni**: per continuare a
usarla si ripete il punto 4.

## 1. Una volta sola: Apple ID in Xcode

1. Apri Xcode → **Impostazioni… → Account** → **+** → **Apple ID**, entra col
   tuo account.
2. Comparirà un team "Lorenzo Faraoni (Personal Team)".

## 2. Una volta sola: il progetto

```bash
cd "ios"
xcodegen generate
open StyleVault.xcodeproj
```

Serve `ios/Config/Secrets.xcconfig` (non è in git): copialo da
`Secrets.xcconfig.example` e metti URL e chiave di `.env.local`.

In Xcode: target **StyleVault** → **Signing & Capabilities** → **Team** =
il tuo Personal Team. Se Xcode dice che il bundle id è già preso, cambia
`it.faraoni.stylevault` in qualcosa di tuo (anche in `project.yml`).

## 3. Una volta sola: l'iPhone

1. Collega l'iPhone al Mac col cavo e sbloccalo; "Autorizza questo computer".
2. Sull'iPhone: **Impostazioni → Privacy e sicurezza → Modalità sviluppatore**
   → attiva e riavvia.

## 4. Installare (e reinstallare ogni 7 giorni)

1. In Xcode scegli in alto il tuo iPhone come destinazione e lo schema
   **StyleVault**, configurazione **Release** (Product → Scheme → Edit
   Scheme → Run → Build Configuration). In Release l'app carica il sito
   pubblicato; in Debug il server di sviluppo del Mac, che l'iPhone non vede.
2. **Product → Run** (⌘R).
3. La prima volta, sull'iPhone: **Impostazioni → Generali → VPN e gestione
   dispositivi** → il tuo Apple ID → **Autorizza**.

## Prima di provarla davvero

- La **migrazione 003** deve essere applicata su Supabase (SQL Editor:
  `supabase/migrations/003_app_ios.sql`), sennò foto del corpo e tema non si
  salvano.
- Il **sito pubblicato** deve contenere il branch `feat/app-ios` (ponte con
  l'app, campo retro, tema): si pubblica dopo la migrazione.
- **Accedi con Google**: client OAuth su Google Cloud Console con redirect
  `https://frukvktbmxndyzgivwxq.supabase.co/auth/v1/callback`, provider Google
  attivo su Supabase, e `stylevault://auth-callback` tra le Redirect URLs di
  Supabase (Authentication → URL Configuration). Finché non è attivo, il
  bottone non compare.

## Quando ci sarà l'Apple Developer Program (99 €/anno)

- **Accedi con Apple**: capability "Sign in with Apple" nel target, Services
  ID e chiave sul portale Apple, provider Apple su Supabase, poi
  `AppConfig.appleSignInEnabled = true`.
- **TestFlight** per Mary, e niente più scadenza dei 7 giorni.

## Cosa provare (checklist del progetto)

1. Login con email (o Google, se attivo).
2. Primo accesso: 3 foto (davanti, lato, spalle). Chi ha già la foto del
   profilo scatta solo lato e spalle.
3. Un outfit di 2–4 capi → "Vedilo addosso": la tua figura coi capi in meno
   di 2 secondi, scorrendo lato e spalle.
4. Riapri l'app: le foto ci sono ancora.
5. Profilo → Tema: Chiaro, Scuro, Sistema; anche login e avatar seguono.
6. Il sito continua a funzionare per Mary come prima.
