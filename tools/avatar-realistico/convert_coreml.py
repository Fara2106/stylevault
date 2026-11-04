"""Task 2 della prova tecnica: converte i pezzi di Mobile-VTON in Core ML
(.mlpackage, fp16, forme fisse prese dal riferimento del Task 1).

Va lanciato col venv di conversione (torch 2.7, il più recente testato da
coremltools 9), un pezzo alla volta per non riempire la memoria:

uso: python -I convert_coreml.py REPO WEIGHTS [--only Denoiser VAEDecoder ...]
     (Denoiser1 = UNet di prova a batch 1, un ramo della guida per chiamata)
uscita: out/coreml-fp16/<Nome>.mlpackage
"""
import argparse
import gc
import json
import sys
import time
from pathlib import Path

import numpy as np
import torch
from torch import nn

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402
from components import DUPLICATES, FEATURES, SPECS  # noqa: E402
from verify_components import reference  # noqa: E402


class TextEncoder(nn.Module):
    def __init__(self, model):
        super().__init__()
        self.model = model

    def forward(self, input_ids):
        out = self.model(input_ids, output_hidden_states=True)
        return out.hidden_states[-2], out.text_embeds


class ImageEncoder(nn.Module):
    """DINOv2 (penultimo strato) + encoder_hid_proj della UNet di prova."""

    def __init__(self, dino, proj):
        super().__init__()
        self.dino, self.proj = dino, proj

    def forward(self, pixel_values):
        return self.proj(self.dino(pixel_values, output_hidden_states=True).hidden_states[-2])


class VAEEncoder(nn.Module):
    def __init__(self, vae):
        super().__init__()
        self.encoder = vae.encoder

    def forward(self, image):
        return self.encoder(image)


class VAEDecoder(nn.Module):
    def __init__(self, decoder):
        super().__init__()
        self.decoder = decoder

    def forward(self, latents):
        return self.decoder(latents)


class DenoiserGarment(nn.Module):
    def __init__(self, unet):
        super().__init__()
        self.unet = unet

    def forward(self, sample, timestep, encoder_hidden_states):
        _, features = self.unet(sample=sample, timestep=timestep,
                                encoder_hidden_states=encoder_hidden_states, return_dict=False)
        return tuple(f for k, f in enumerate(features) if k not in DUPLICATES)


class Denoiser(nn.Module):
    def __init__(self, unet):
        super().__init__()
        self.unet = unet

    def forward(self, sample, timestep, encoder_hidden_states, image_embeds, *features):
        return self.unet(sample=sample, timestep=timestep, encoder_hidden_states=encoder_hidden_states,
                         return_dict=False, garment_features=list(features),
                         added_cond_kwargs={"image_embeds": image_embeds})[0]


def build(name: str, repo: str, weights: str) -> nn.Module:
    """Carica solo ciò che serve al pezzo, in fp32 su CPU."""
    sys.path.insert(0, repo)
    from diffusers.models.autoencoders import AutoencoderKL
    from transformers import AutoModel, CLIPTextModelWithProjection
    from Mobile_VTON.models.autoencoders.vae import Decoder
    from Mobile_VTON.models.unets.unet_2d_condition_tryon import UNet2DConditionModel as UnetTryon
    from Mobile_VTON.models.unets.unet_2d_condition_garment import UNet2DConditionModel as UnetGarment

    if name == "TextEncoder":
        return TextEncoder(CLIPTextModelWithProjection.from_pretrained(weights, subfolder="text_encoder"))
    if name == "TextEncoder2":
        return TextEncoder(CLIPTextModelWithProjection.from_pretrained(weights, subfolder="text_encoder_2"))
    if name == "ImageEncoder":
        proj = UnetTryon.from_pretrained(weights, subfolder="denoiser").encoder_hid_proj
        dino = AutoModel.from_pretrained(weights, subfolder="image_encoder")
        # Core ML non ha l'interpolazione bicubica: con l'ingresso fisso a 224×224
        # le posizioni interpolate sono sempre le stesse, si calcolano qui una volta
        emb = dino.embeddings
        with torch.no_grad():
            tokens = (224 // dino.config.patch_size) ** 2 + 1
            fixed = emb.interpolate_pos_encoding(torch.zeros(1, tokens, dino.config.hidden_size), 224, 224)
        emb.interpolate_pos_encoding = lambda embeddings, height, width: fixed
        return ImageEncoder(dino, proj)
    if name == "VAEEncoder":
        return VAEEncoder(AutoencoderKL.from_pretrained(weights, subfolder="vae"))
    if name == "VAEDecoder":
        decoder = Decoder(**json.load(open(f"{weights}/vae_decoder/decoder.json")))
        decoder.load_state_dict(torch.load(f"{weights}/vae_decoder/decoder.pt", map_location="cpu",
                                           weights_only=True), strict=True)
        return VAEDecoder(decoder)
    if name == "DenoiserGarment":
        return DenoiserGarment(UnetGarment.from_pretrained(weights, subfolder="denoiser_garment"))
    if name in ("Denoiser", "Denoiser1"):
        return Denoiser(UnetTryon.from_pretrained(weights, subfolder="denoiser"))
    raise ValueError(name)


def input_order(spec) -> list:
    """Ordine degli argomenti di forward(); per il Denoiser le feature in fondo."""
    if spec.name in ("Denoiser", "Denoiser1"):
        return ["sample", "timestep", "encoder_hidden_states", "image_embeds", *FEATURES]
    return list(spec.inputs)


def convert(spec, repo: str, weights: str, out_dir: Path):
    import coremltools as ct

    t0 = time.time()
    module = build(spec.name, repo, weights).float().eval()
    ins, expected = reference(spec)
    order = input_order(spec)
    example = tuple(torch.from_numpy(ins[n]) for n in order)
    with torch.no_grad():
        traced = torch.jit.trace(module, example, strict=False)
    mlmodel = ct.convert(
        traced,
        convert_to="mlprogram",
        inputs=[ct.TensorType(name=n, shape=ins[n].shape,
                              dtype=np.int32 if n in spec.int_inputs else np.float32) for n in order],
        outputs=[ct.TensorType(name=n) for n in expected],
        compute_precision=ct.precision.FLOAT16,
        minimum_deployment_target=ct.target.iOS18,
    )
    mlmodel.short_description = "Mobile-VTON (CVPR 2026), CC BY-NC-SA 4.0 — solo uso non commerciale"
    mlmodel.save(str(out_dir / f"{spec.name}.mlpackage"))
    print(f"{spec.name}: convertito in {time.time() - t0:.0f} s", flush=True)
    del module, traced, mlmodel
    gc.collect()


def main():
    a = argparse.ArgumentParser()
    a.add_argument("repo")
    a.add_argument("weights")
    a.add_argument("--only", nargs="*", default=None)
    args = a.parse_args()
    out_dir = common.OUT / "coreml-fp16"
    out_dir.mkdir(parents=True, exist_ok=True)
    for spec in SPECS:
        if args.only and spec.name not in args.only:
            continue
        try:
            convert(spec, args.repo, args.weights, out_dir)
        except Exception as error:  # un pezzo che non si converte è già un dato per il cancello
            print(f"{spec.name}: NON CONVERTITO — {type(error).__name__}: {error}", flush=True)


if __name__ == "__main__":
    main()
