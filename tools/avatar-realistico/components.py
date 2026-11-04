"""I 7 modelli Core ML: nomi di ingressi/uscite e da quali dati del Task 1 si
verificano. Unica fonte per conversione (convert_coreml.py) e verifica
(verify_components.py)."""
from dataclasses import dataclass, field

import numpy as np

N_FEATURES = 28
FEATURES = [f"garment_feature_{k}" for k in range(N_FEATURES)]
# Nella UNet del capo le feature 8–11 sono gli stessi tensori delle 12–15
# (verificato sul riferimento): Core ML le fonderebbe con nomi doppi, quindi
# DenoiserGarment dà solo le 24 distinte e l'app ricopia le 12–15 nelle 8–11
DUPLICATES = {8: 12, 9: 13, 10: 14, 11: 15}
GARMENT_OUT = [f for k, f in enumerate(FEATURES) if k not in DUPLICATES]


@dataclass
class Spec:
    name: str                 # file <name>.mlpackage
    ref_in: str               # pezzo del Task 1 da cui prendere gli ingressi
    ref_out: str              # ...e le uscite attese
    inputs: dict              # nome Core ML → chiave nel .npz di ingresso
    outputs: dict             # nome Core ML → chiave nel .npz di uscita
    int_inputs: tuple = ()
    out_slices: dict = field(default_factory=dict)  # nome → slice sull'asse 0
    batch: slice = None       # se dato, ingressi e uscite presi solo su questo tratto dell'asse 0

    def input_dtype(self, name):
        return np.int32 if name in self.int_inputs else np.float32

    def slice_in(self, name, value):
        return value[self.batch] if self.batch is not None and name not in self.int_inputs else value

    def slice_out(self, name, value):
        value = value[self.batch] if self.batch is not None else value
        return value[self.out_slices[name]] if name in self.out_slices else value


SPECS = [
    # Testo: penultimo strato (hidden_states[-2]) + embedding finale
    Spec("TextEncoder", "text_encoder", "text_encoder", {"input_ids": "arg.0"},
         {"hidden_penultimate": "out.hidden_states.11", "text_embeds": "out.text_embeds"},
         int_inputs=("input_ids",)),
    Spec("TextEncoder2", "text_encoder_2", "text_encoder_2", {"input_ids": "arg.0"},
         {"hidden_penultimate": "out.hidden_states.31", "text_embeds": "out.text_embeds"},
         int_inputs=("input_ids",)),
    # DINOv2 (hidden_states[-2]) + encoder_hid_proj: la metà condizionata [1:2]
    Spec("ImageEncoder", "image_encoder", "encoder_hid_proj", {"pixel_values": "arg.0"},
         {"image_embeds": "out"}, out_slices={"image_embeds": slice(1, 2)}),
    Spec("VAEEncoder", "vae_encode", "vae_encode", {"image": "arg.0"}, {"moments": "out"}),
    Spec("VAEDecoder", "vae_decoder", "vae_decoder", {"latents": "arg.0"}, {"image": "out"}),
    Spec("DenoiserGarment", "denoiser_garment", "denoiser_garment",
         {"sample": "sample", "timestep": "timestep", "encoder_hidden_states": "encoder_hidden_states"},
         {f: f"out.1.{k}" for k, f in enumerate(FEATURES) if f in GARMENT_OUT}),
    Spec("Denoiser", "denoiser", "denoiser",
         {"sample": "sample", "timestep": "timestep", "encoder_hidden_states": "encoder_hidden_states",
          **{f: f"garment_features.{k}" for k, f in enumerate(FEATURES)},
          "image_embeds": "added_cond_kwargs.image_embeds"},
         {"noise_pred": "out.0"}),
    # La UNet di prova a batch 1 (un ramo della guida per chiamata: metà
    # attivazioni). Si verifica sul ramo condizionato del riferimento.
    Spec("Denoiser1", "denoiser", "denoiser",
         {"sample": "sample", "timestep": "timestep", "encoder_hidden_states": "encoder_hidden_states",
          **{f: f"garment_features.{k}" for k, f in enumerate(FEATURES)},
          "image_embeds": "added_cond_kwargs.image_embeds"},
         {"noise_pred": "out.0"}, batch=slice(1, 2)),
]
