# Licenza dei modelli / Models license

## Italiano

I modelli di questa Release sono una **versione convertita** di Mobile-VTON e si distribuiscono con la stessa licenza dell'originale, **CC BY-NC-SA 4.0** (Creative Commons Attribuzione - Non commerciale - Condividi allo stesso modo).

- **Opera originale:** "Mobile-VTON: High-Fidelity On-Device Virtual Try-On"
- **Autori:** Zhenchen Wan, Ce Chen, Runqi Lin, Jiaxin Huang, Tianxi Chen, Yanwu Xu, Tongliang Liu, Mingming Gong (2026, arXiv)
- **Sorgente:** https://github.com/tmllab/2026_CVPR_Mobile-VTON
- **Licenza:** CC BY-NC-SA 4.0, https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode

**Modifiche apportate:** conversione in Core ML, palettizzazione a 6 bit (k-means), posizioni di DINOv2 fissate per immagini 224×224, UNet del capo con uscita di 24 feature.

Uso non commerciale: questi modelli non si possono usare a fini commerciali. Chi li ridistribuisce o li modifica deve citare gli autori, indicare le modifiche e mantenere la stessa licenza. I modelli sono forniti senza alcuna garanzia.

## English

The models in this release are a **converted version** of Mobile-VTON and are distributed under the same license as the original, **CC BY-NC-SA 4.0** (Creative Commons Attribution-NonCommercial-ShareAlike).

- **Original work:** "Mobile-VTON: High-Fidelity On-Device Virtual Try-On"
- **Authors:** Zhenchen Wan, Ce Chen, Runqi Lin, Jiaxin Huang, Tianxi Chen, Yanwu Xu, Tongliang Liu, Mingming Gong (2026, arXiv)
- **Source:** https://github.com/tmllab/2026_CVPR_Mobile-VTON
- **License:** CC BY-NC-SA 4.0, https://creativecommons.org/licenses/by-nc-sa/4.0/legalcode

**Changes made:** conversion to Core ML, 6-bit k-means palettization, DINOv2 positions fixed for 224×224 inputs, garment UNet outputs 24 features.

Non-commercial use only. Anyone redistributing or adapting these models must credit the authors, indicate changes and keep the same license. The models are provided without warranty.

## Componenti di terze parti / Third-party components

I pacchetti contengono anche componenti che Mobile-VTON riusa da altri progetti. Origine e licenza qui sotto sono ricavate **solo dai file locali** del checkpoint (`config.json`, `model_index.json`) e dal README del repository; dove non sono dichiarate, sono segnate "da verificare prima della Release". La licenza CC BY-NC-SA 4.0 del README del repository dichiara di coprire "codice e checkpoint" di Mobile-VTON nel suo insieme.

| Componente / Component | Origine dichiarata localmente / Origin stated locally | Licenza / License |
|---|---|---|
| Tokenizzatore CLIP (`vocab.json`, `merges.txt`; identici in `tokenizer` e `tokenizer_2`) | classe `CLIPTokenizer` (transformers); nessuna origine né licenza nei file | da verificare prima della Release / to verify before release |
| Codificatore di testo 1 (`TextEncoder`) | `CLIPTextModelWithProjection`, 12 strati, dimensione 768; `_name_or_path` è solo un percorso locale dell'autore | da verificare prima della Release / to verify before release |
| Codificatore di testo 2 (`TextEncoder2`) | `CLIPTextModelWithProjection`, 32 strati, dimensione 1280; `_name_or_path` è solo un percorso locale dell'autore | da verificare prima della Release / to verify before release |
| Codificatore d'immagine (`ImageEncoder`) | DINOv2 (`model_type: dinov2`, `_name_or_path: ../dinov2_base`); non è indicata la fonte | da verificare prima della Release / to verify before release |
| VAE (`VAEEncoder`, `VAEDecoder`) | `AutoencoderKL`; `_name_or_path` indica `stable-diffusion-3.5-large` (percorso locale dell'autore) | da verificare prima della Release (la licenza di Stable Diffusion 3.5 non è nei file locali) / to verify before release |

The packages also contain components that Mobile-VTON reuses from other projects. Origin and license above come **only from local files** (checkpoint `config.json` and `model_index.json`, repository README). Where they are not stated locally they are marked "to verify before release"; no license has been assumed. The repository README states that the code and checkpoints of Mobile-VTON as a whole are under CC BY-NC-SA 4.0, and thanks IP-Adapter and IDM-VTON (for code and DensePose data, not model weights).
