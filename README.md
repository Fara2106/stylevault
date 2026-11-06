# StyleVault

Guardaroba digitale per iPhone e iPad, con outfit guidati dal meteo. I dati stanno
sul dispositivo e nell'iCloud dell'utente.

## Cosa fa

- **Guardaroba**: registra i capi con una foto, dalla fotocamera o dalla libreria,
  oppure incollando il link di uno shop online. Wishlist compresa.
- **Outfit**: scegli città o posizione, giorno e occasione; l'app propone gli outfit
  con punteggio meteo e armonia dei colori, più i consigli di stile.
- **Calendario**: pianifica gli outfit e segna cosa hai indossato.
- **Statistiche** nel Profilo: capi più e meno indossati, colori, categorie, costo per utilizzo.
- **Account facoltativo**: Apple, Google, email e password. I dati restano su iCloud
  e si può entrare anche senza account. Blocco facoltativo con Face ID.
- Italiano e inglese.

## Stack

SwiftUI, SwiftData con CloudKit, iOS 17. La logica senza interfaccia sta nel pacchetto
`ios/StyleVaultCore`. Gli account stanno su Supabase (`supabase/`): il workflow
`.github/workflows/keepalive.yml` lo tiene sveglio.

## Comandi

La prima volta copia `ios/Config/Secrets.xcconfig.example` in `ios/Config/Secrets.xcconfig`
e metti i valori del progetto Supabase.

```bash
cd ios && xcodegen generate
```

```bash
cd ios/StyleVaultCore && swift test
```

```bash
cd ios && xcodebuild test -project StyleVault.xcodeproj -scheme StyleVaultNative -destination 'platform=iOS Simulator,name=iPhone 17 Pro' -only-testing:StyleVaultNativeTests
```

## Struttura

- `ios/StyleVaultNative/` — l'app: `Wardrobe`, `Outfit`, `Calendar`, `Profile`, `Auth`, `Data`
- `ios/StyleVaultCore/` — motore outfit, armonia dei colori, meteo, statistiche, con i test
- `ios/project.yml` — progetto Xcode, generato con XcodeGen
- `supabase/` — migrazioni ed Edge Functions
- `docs/` — design, piani, verifiche e testi per la pubblicazione

Stato del progetto e ripartenza: vedi `MEMORIA.md`.
