# Verifica a schermo — avatar 3D (2026-07-09)

- `00-bug-originale.png` — il difetto di partenza, riprodotto: la foto dei jeans
  ritagliata con `slice` dentro la sagoma. Delle gambe si vede quasi solo lo
  **sfondo** della foto; del capo resta una striscia centrale.
- `01-3d-fronte.png` — avatar 3D vestito. La fantasia vera (il logo "SV") è sul
  petto, la cintura e il bottone sui jeans.
- `02-3d-ruotato.png` — la figura ruotata col trascinamento: la fantasia segue il
  corpo. Resta un artefatto cosmetico: il decal è un cilindro a raggio costante
  mentre il busto si assottiglia, quindi di lato sporge leggermente.
- `03-piatto.png` — modalità piatta. **È la prova che il difetto è chiuso**: capo
  intero, al posto giusto, nessuno sfondo dentro le gambe.
- `04-senza-webgl.png` — Chrome avviato senza GPU: il bottone 3D è disabilitato e
  compare il messaggio; la modalità piatta funziona.

Zero errori in console in tutti gli scenari.
