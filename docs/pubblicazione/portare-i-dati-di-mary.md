# Portare i dati di Mary dal sito all'app

Serve una volta sola, per persona. Lo script legge da Supabase e non cambia nulla lassù.

1. Su Supabase apri Authentication → Users e copia l'id dell'account con i capi. Mary ne ha due: i dati stanno in quello vecchio, che inizia con `3c113b1f`.
2. Su Supabase apri Project Settings → API e copia la chiave `service_role`. Non scriverla in un file e non incollarla in chat: legge i dati di tutti.
3. Nel Terminale, dalla cartella del progetto:

   ```bash
   SUPABASE_URL=https://TUOPROGETTO.supabase.co SUPABASE_SERVICE_ROLE_KEY=LA_CHIAVE node scripts/esporta-da-supabase.mjs ID_UTENTE dati-mary.zip
   ```

4. Il comando scrive quanti capi, outfit e foto ha salvato, e quali foto non è riuscito a scaricare.
5. Manda `dati-mary.zip` a Mary con AirDrop. Dentro ci sono le sue foto, anche quelle del corpo, quindi evita chat e posta.
6. Mary lo salva in File, poi nell'app apre Profilo → I tuoi dati → Importa da un file. L'import aggiunge e non cancella nulla, e si può ripetere senza creare doppioni.

Le categorie personali del sito stavano solo nel browser: i capi restano collegati, ma le categorie si chiamano "Categoria 1", "Categoria 2" e vanno rinominate.
