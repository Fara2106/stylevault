"""Esporta per RealisticBench gli ingressi veri della coppia di prova, così
l'app può rifare sull'iPhone (o nel simulatore) la stessa generazione di
coreml_pipeline.py e confrontarne l'immagine.

Restano sul Mac solo i passi che nell'app vera saranno codice Swift ancora da
scrivere: tokenizzazione CLIP, preprocessing di DINOv2 e calcolo dei sigma
dello scheduler. Tutto il resto (testi, immagine del capo, VAE, UNet,
decoder) lo fanno i modelli Core ML sul dispositivo.

Non importa Mobile_VTON.

uso: python -I export_bench_inputs.py WEIGHTS
uscita: out/bench-inputs/ con un .bin (little endian) per tensore e manifest.json
"""
import argparse
import json
import sys
from pathlib import Path

import numpy as np
import torch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402
from coreml_pipeline import to_model  # noqa: E402


def main():
    from diffusers import FlowMatchEulerDiscreteScheduler
    from transformers import AutoImageProcessor, CLIPTokenizer

    a = argparse.ArgumentParser()
    a.add_argument("weights")
    args = a.parse_args()
    out = common.OUT / "bench-inputs"
    out.mkdir(parents=True, exist_ok=True)
    inputs = common.test_inputs()

    tensors = {}
    for sub, key in (("tokenizer", "ids"), ("tokenizer_2", "ids2")):
        tok = CLIPTokenizer.from_pretrained(args.weights, subfolder=sub)
        for text, name in ((common.NEGATIVE, "negative"), (inputs["caption"], "caption"),
                           (inputs["caption_cloth"], "caption_cloth")):
            tensors[f"{key}_{name}"] = tok([text], padding="max_length", max_length=tok.model_max_length,
                                           truncation=True, return_tensors="np").input_ids.astype(np.int32)
    dino = AutoImageProcessor.from_pretrained(f"{args.weights}/image_encoder")
    tensors["cloth_pixels"] = dino(images=inputs["cloth"], return_tensors="np").pixel_values.astype(np.float32)
    tensors["person"] = to_model(inputs["person"])
    tensors["cloth"] = to_model(inputs["cloth"])
    gen = torch.Generator(device="cpu").manual_seed(common.SEED)
    tensors["noise"] = torch.randn((1, 16, common.H // 8, common.W // 8), generator=gen,
                                   dtype=torch.float16).float().numpy()

    scheduler = FlowMatchEulerDiscreteScheduler(num_train_timesteps=1000, shift=common.SHIFT)
    scheduler.set_timesteps(common.STEPS)
    manifest = {
        "timesteps": [float(t) for t in scheduler.timesteps],
        "sigmas": [float(s) for s in scheduler.sigmas],
        "guidance": common.GUIDANCE,
        "tensors": {},
    }
    for name, value in tensors.items():
        value = np.ascontiguousarray(value)
        value.astype(value.dtype.newbyteorder("<")).tofile(out / f"{name}.bin")
        manifest["tensors"][name] = {"shape": list(value.shape), "dtype": str(value.dtype)}
    (out / "manifest.json").write_text(json.dumps(manifest, indent=1))
    print(f"{len(tensors)} tensori in {out}")
    print("timesteps", manifest["timesteps"])


if __name__ == "__main__":
    main()
