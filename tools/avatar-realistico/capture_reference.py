"""Task 1 della prova tecnica: genera l'immagine di riferimento (PyTorch fp16,
MPS: in fp32 il Mac da 16 GB va in swap) e registra ingressi e uscite di ogni pezzo alla prima chiamata, per
verificare poi la conversione in Core ML.

uso: python -I capture_reference.py REPO WEIGHTS
uscita: out/reference/{shapes.json, step0_<pezzo>_in.npz, step0_<pezzo>_out.npz, reference.png}
"""
import json
import sys
import time
from dataclasses import fields, is_dataclass
from pathlib import Path

import numpy as np
import torch

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402

DEVICE = "mps"


def flatten(value, prefix: str, into: dict):
    """Tensori annidati (liste, tuple, dict, output di transformers) → nome piatto."""
    if torch.is_tensor(value):
        into[prefix] = value.detach().float().cpu().numpy()
    elif isinstance(value, dict):
        for k, v in value.items():
            flatten(v, f"{prefix}.{k}" if prefix else str(k), into)
    elif isinstance(value, (list, tuple)):
        for i, v in enumerate(value):
            flatten(v, f"{prefix}.{i}" if prefix else str(i), into)
    elif is_dataclass(value):
        for f in fields(value):
            flatten(getattr(value, f.name), f"{prefix}.{f.name}" if prefix else f.name, into)


def main():
    repo, weights = sys.argv[1], sys.argv[2]
    out = common.OUT / "reference"
    out.mkdir(parents=True, exist_ok=True)

    t0 = time.time()
    pipe = common.load_pipeline(repo, weights, torch.float16, DEVICE)
    print(f"caricamento: {time.time() - t0:.1f} s", flush=True)

    # Pezzo → modulo; si registra solo la prima chiamata (passo 0)
    parts = {
        "denoiser_garment": pipe.denoiser_garment,
        "denoiser": pipe.denoiser,
        "encoder_hid_proj": pipe.denoiser.encoder_hid_proj,
        "vae_encode": pipe.vae.encoder,
        "vae_decoder": pipe.vae_decoder,
        "image_encoder": pipe.image_encoder,
        "text_encoder": pipe.text_encoder,
        "text_encoder_2": pipe.text_encoder_2,
    }
    shapes, done = {}, set()

    def hook(name):
        def record(module, args, kwargs, output):
            if name in done:
                return
            done.add(name)
            ins, outs = {}, {}
            flatten(list(args), "arg", ins)
            flatten(kwargs, "", ins)
            flatten(output, "out", outs)
            np.savez(out / f"step0_{name}_in.npz", **ins)
            np.savez(out / f"step0_{name}_out.npz", **outs)
            shapes[name] = {
                "in": {k: list(v.shape) for k, v in ins.items()},
                "out": {k: list(v.shape) for k, v in outs.items()},
            }
            print(f"{name}: in {shapes[name]['in']}\n  out {shapes[name]['out']}", flush=True)
        return record

    for name, module in parts.items():
        module.register_forward_hook(hook(name), with_kwargs=True)

    t1 = time.time()
    image = common.generate(pipe, common.test_inputs(), DEVICE)
    print(f"generazione: {time.time() - t1:.1f} s ({common.STEPS} passi, fp16)", flush=True)
    image.save(out / "reference.png")
    (out / "shapes.json").write_text(json.dumps(shapes, indent=2))
    missing = set(parts) - done
    print("pezzi registrati:", len(done), "| mancanti:", sorted(missing) or "nessuno")


if __name__ == "__main__":
    main()
