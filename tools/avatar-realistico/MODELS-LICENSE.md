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

I pacchetti contengono anche componenti che Mobile-VTON riusa da altri progetti. Le loro licenze sono incluse nella Release / The packages also contain components Mobile-VTON reuses from other projects; their licenses are included in this release.

| Componente / Component | Origine / Origin | Licenza / License |
|---|---|---|
| VAE (`VAEEncoder`, `VAEDecoder`) | Stable Diffusion 3.5 Large (`_name_or_path`), tramite Mobile-VTON | Stability AI Community License — `STABILITY-AI-COMMUNITY-LICENSE.md`, `NOTICE.txt` |
| Codificatori di testo (`TextEncoder` CLIP ViT-L/14, `TextEncoder2` OpenCLIP ViT-bigG/14) | architettura e dimensioni (768, 1280) dei codificatori di Stable Diffusion 3.5; in origine OpenAI CLIP e OpenCLIP | Stability AI Community License (via SD 3.5), MIT — `CLIP-LICENSE.txt`, `OPEN_CLIP-LICENSE.txt` |
| Tokenizzatore CLIP (`vocab.json`, `merges.txt`) | OpenAI CLIP | MIT — `CLIP-LICENSE.txt` |
| Codificatore d'immagine (`ImageEncoder`) | DINOv2 base (Meta) | Apache 2.0 — `DINOV2-LICENSE.txt` |

**Powered by Stability AI.** This Stability AI Model is licensed under the Stability AI Community License, Copyright © Stability AI Ltd. All Rights Reserved. Vedi / see `NOTICE.txt` per le modifiche / for the changes made.

Uso / use: StyleVault è un'app gratuita, senza pubblicità né acquisti, e usa questi modelli solo a fini non commerciali / StyleVault is a free app with no ads or purchases and uses these models for non-commercial purposes only.
