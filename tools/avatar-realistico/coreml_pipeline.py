"""Task 3 della prova tecnica: rifà la generazione intera di Mobile-VTON con i
modelli Core ML al posto di quelli PyTorch e la confronta con reference.png.

Segue il ciclo di tryon_pipeline_full_cat.py (concatenazione lungo l'altezza,
guida senza feature del capo nel ramo incondizionato, FlowMatchEuler shift 3).
Non importa Mobile_VTON: solo scheduler di diffusers, tokenizer e processore
d'immagine di transformers, quindi si può lanciare senza il codice del repo.

uso: python -I coreml_pipeline.py WEIGHTS [--models out/coreml-fp16] [--units ALL]
uscita: out/<cartella dei modelli>.png, tempo per pezzo e PSNR contro il riferimento
"""
import argparse
import sys
import time
from collections import defaultdict
from pathlib import Path

import numpy as np
import torch
from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402
from components import DUPLICATES, FEATURES, GARMENT_OUT  # noqa: E402

SCALE, SHIFT_VAE = 1.5305, 0.0609   # normalizzazione dei latenti del VAE
T5_TOKENS, EMBED = 256, 4096          # il ramo T5 non c'è: 256 token a zero


class Models:
    """Carica i .mlpackage solo quando servono e conta il tempo di ogni pezzo."""

    def __init__(self, folder: Path, units: str):
        import coremltools as ct
        self.ct, self.folder = ct, folder
        self.units = getattr(ct.ComputeUnit, units)
        self.loaded, self.times = {}, defaultdict(float)

    def __call__(self, name: str, **inputs) -> dict:
        if name not in self.loaded:
            t0 = time.time()
            self.loaded[name] = self.ct.models.MLModel(str(self.folder / f"{name}.mlpackage"),
                                                       compute_units=self.units)
            self.times[f"{name} (caricamento)"] += time.time() - t0
        t0 = time.time()
        out = self.loaded[name].predict({k: np.ascontiguousarray(v) for k, v in inputs.items()})
        self.times[name] += time.time() - t0
        return out

    def drop(self, *names):
        for n in names:
            self.loaded.pop(n, None)


def encode_text(models: Models, tokenizers, text: str) -> np.ndarray:
    """CLIP-L e CLIP-G (penultimo strato) affiancati, allargati a 4096, più 256
    token T5 a zero: [1, 333, 4096] come _encode_prompt_with_clip_clip_noloadingt5."""
    hidden = []
    for name, tok in zip(("TextEncoder", "TextEncoder2"), tokenizers):
        ids = tok([text], padding="max_length", max_length=tok.model_max_length, truncation=True,
                  return_tensors="np").input_ids.astype(np.int32)
        hidden.append(models(name, input_ids=ids)["hidden_penultimate"])
    clip = np.concatenate(hidden, axis=-1)
    clip = np.pad(clip, ((0, 0), (0, 0), (0, EMBED - clip.shape[-1])))
    return np.concatenate([clip, np.zeros((1, T5_TOKENS, EMBED), np.float32)], axis=1)


def vae_latent(models: Models, image: np.ndarray) -> np.ndarray:
    """Media della distribuzione del VAE (il riferimento ne prende un campione)."""
    mean = models("VAEEncoder", image=image)["moments"][:, :16]
    return (mean - SHIFT_VAE) * SCALE


def to_model(img: Image.Image) -> np.ndarray:
    """PIL → [1, 3, H, W] in [-1, 1]."""
    return (np.asarray(img, np.float32).transpose(2, 0, 1)[None] / 127.5 - 1).astype(np.float32)


def psnr(a: Image.Image, b: Image.Image) -> float:
    x, y = np.asarray(a, np.float64), np.asarray(b, np.float64)
    mse = ((x - y) ** 2).mean()
    return float("inf") if mse == 0 else 10 * np.log10(255 ** 2 / mse)


def main():
    from diffusers import FlowMatchEulerDiscreteScheduler
    from transformers import AutoImageProcessor, CLIPTokenizer

    a = argparse.ArgumentParser()
    a.add_argument("weights")
    a.add_argument("--models", default=str(common.OUT / "coreml-fp16"))
    a.add_argument("--units", default="ALL", choices=["ALL", "CPU_AND_NE", "CPU_AND_GPU", "CPU_ONLY"])
    args = a.parse_args()
    folder = Path(args.models)
    models = Models(folder, args.units)
    inputs = common.test_inputs()
    t_start = time.time()

    # Testi: persona (con guida, quindi anche il negativo) e capo
    tokenizers = [CLIPTokenizer.from_pretrained(args.weights, subfolder=s) for s in ("tokenizer", "tokenizer_2")]
    prompt = np.concatenate([encode_text(models, tokenizers, common.NEGATIVE),
                             encode_text(models, tokenizers, inputs["caption"])])
    prompt_cloth = encode_text(models, tokenizers, inputs["caption_cloth"])
    models.drop("TextEncoder", "TextEncoder2")

    # Immagine del capo per DINOv2: il ramo incondizionato è DINOv2 di un'immagine nera
    dino = AutoImageProcessor.from_pretrained(f"{args.weights}/image_encoder")
    pixels = dino(images=inputs["cloth"], return_tensors="np").pixel_values.astype(np.float32)
    image_embeds = np.concatenate([models("ImageEncoder", pixel_values=np.zeros_like(pixels))["image_embeds"],
                                   models("ImageEncoder", pixel_values=pixels)["image_embeds"]])
    models.drop("ImageEncoder")

    # Latenti di persona e capo, impilati in altezza
    cloth = vae_latent(models, to_model(inputs["cloth"]))
    person = vae_latent(models, to_model(inputs["person"]))
    condition = np.concatenate([np.concatenate([person, cloth], axis=-2)] * 2)
    models.drop("VAEEncoder")

    # Rumore iniziale identico al riferimento: stesso generatore, stesso dtype
    gen = torch.Generator(device="cpu").manual_seed(common.SEED)
    noise = torch.randn((1, 16, common.H // 8, common.W // 8), generator=gen, dtype=torch.float16).float()
    latents = torch.cat([noise, noise], dim=-2)

    scheduler = FlowMatchEulerDiscreteScheduler(num_train_timesteps=1000, shift=common.SHIFT)
    scheduler.set_timesteps(common.STEPS)
    for i, t in enumerate(scheduler.timesteps):
        tv = float(t)
        garment = models("DenoiserGarment", sample=cloth, timestep=np.array([tv], np.float32),
                         encoder_hidden_states=prompt_cloth)
        feats = {f: garment[f] for f in GARMENT_OUT}
        feats.update({FEATURES[k]: garment[FEATURES[src]] for k, src in DUPLICATES.items()})
        feats = {f: np.concatenate([np.zeros_like(d2 := np.concatenate([d, d], axis=-2)), d2])
                 for f, d in feats.items()}
        sample = np.concatenate([np.concatenate([latents.numpy()] * 2), condition], axis=1)
        noise_pred = models("Denoiser", sample=sample, timestep=np.array([tv, tv], np.float32),
                            encoder_hidden_states=prompt, image_embeds=image_embeds, **feats)["noise_pred"]
        uncond, cond = noise_pred[:1], noise_pred[1:]
        guided = uncond + common.GUIDANCE * (cond - uncond)
        latents = scheduler.step(torch.from_numpy(guided), t, latents, return_dict=False)[0]
        print(f"passo {i + 1}/{common.STEPS}", flush=True)
    models.drop("DenoiserGarment", "Denoiser")

    final = latents[..., : latents.shape[-2] // 2, :].numpy() / SCALE + SHIFT_VAE
    image = models("VAEDecoder", latents=final.astype(np.float32))["image"][0]
    image = ((image / 2 + 0.5).clip(0, 1).transpose(1, 2, 0) * 255).round().astype(np.uint8)
    result = Image.fromarray(image)
    total = time.time() - t_start

    out = common.OUT / f"{folder.name}.png"
    result.save(out)
    for name, seconds in sorted(models.times.items(), key=lambda kv: -kv[1]):
        print(f"  {name:32s} {seconds:7.1f} s")
    print(f"totale {total:.1f} s ({args.units}) → {out}")
    ref = common.OUT / "reference" / "reference.png"
    if ref.exists():
        print(f"PSNR contro reference.png: {psnr(result, Image.open(ref).convert('RGB')):.2f} dB")


if __name__ == "__main__":
    main()
