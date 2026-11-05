"""Riferimento PyTorch di FASHN VTON sul Mac.

Da lanciare sempre con guard.sh. Tre modi:
  capture: solo gli ingressi del trasformatore (out/inputs.npz), nessun passo.
  step:    un passaggio singolo a batch 1, per misurare tempo e memoria.
  full:    generazione intera (ore su un Mac da 16 GB: non usarla senza motivo).

Uso: FASHN_SPIKE=<cartella> python reference.py --mode capture|step|full
       [--device mps|cpu] [--dtype fp16|fp32] [--steps 30]
"""
import argparse
import json
import time

import numpy as np
import torch
from PIL import Image

import common


class Captured(Exception):
    """Interrompe la pipeline appena ha preparato gli ingressi."""


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--mode", default="capture", choices=["capture", "step", "full"])
    ap.add_argument("--device", default="mps")
    ap.add_argument("--dtype", default="fp16", choices=["fp16", "fp32"])
    ap.add_argument("--steps", type=int, default=common.STEPS)
    args = ap.parse_args()

    fv = common.import_fashn()
    common.OUT.mkdir(exist_ok=True)
    dtype = torch.float16 if args.dtype == "fp16" else torch.float32
    device = torch.device(args.device)

    pipe = fv.TryOnPipeline(weights_dir=str(common.SPIKE / "weights"), device="cpu")
    # La pipeline sceglie fp32 fuori da CUDA: la spostiamo a mano
    pipe.device = device
    pipe.inference_dtype = dtype
    # In capture i pesi restano in fp16 sulla CPU: bastano le forme e gli ingressi
    pipe.tryon_model.to(device if args.mode != "capture" else "cpu", dtype=dtype)
    # rope() usa float64, che la GPU del Mac (MPS) non ha: posizioni calcolate sulla CPU
    pe = pipe.tryon_model.pe_embedder
    pe_forward = pe.forward
    pe.forward = lambda ids: pe_forward(ids.cpu()).to(ids.device)

    captured = {}
    original = pipe.tryon_model.forward

    def capture(x, times, ca_images, garment_images, person_poses, garment_poses, mask=None, **kw):
        if not captured:
            for k, v in dict(x=x, times=times, ca_images=ca_images, garment_images=garment_images,
                             person_poses=person_poses, garment_poses=garment_poses, mask=mask,
                             garment_categories=kw.get("garment_categories")).items():
                floating = torch.is_floating_point(v)
                captured[k] = (v.detach().float() if floating else v.detach()).cpu().numpy()
            np.savez(common.OUT / "inputs.npz", **captured)
            if args.mode == "capture":
                raise Captured
        return original(x, times, ca_images, garment_images, person_poses, garment_poses, mask=mask, **kw)

    pipe.tryon_model.forward = capture

    person = Image.open(common.PERSON).convert("RGB")
    cloth = Image.open(common.CLOTH).convert("RGB")
    call = dict(category=common.CATEGORY, garment_photo_type="flat-lay", guidance_scale=common.GUIDANCE,
                seed=common.SEED, segmentation_free=True)

    if args.mode != "full":
        # Prima solo gli ingressi; in "step" poi un passaggio a batch 1
        mode, args.mode = args.mode, "capture"
        try:
            pipe(person, cloth, num_timesteps=1, **call)
        except Captured:
            pass
        args.mode = mode
        print("ingressi salvati in", common.OUT / "inputs.npz")
        if mode == "capture":
            return
        d = np.load(common.OUT / "inputs.npz")
        kw = {n: torch.from_numpy(d[n][:1]).to(device, dtype=dtype)
              for n in ["ca_images", "garment_images", "person_poses", "garment_poses"]}
        cat = torch.from_numpy(d["garment_categories"][:1]).to(device)
        x = torch.from_numpy(d["x"][:1]).to(device, dtype=dtype)
        t = torch.from_numpy(d["times"][:1]).to(device, dtype=dtype)
        times = []
        with torch.inference_mode():
            for _ in range(2):  # il primo passaggio prepara la GPU
                s = time.time()
                out = original(x, t, garment_categories=cat, **kw)["x"]
                if args.device == "mps":
                    torch.mps.synchronize()
                times.append(round(time.time() - s, 2))
                print("passaggio", times[-1], "s", flush=True)
        info = {"mode": "step", "device": args.device, "dtype": args.dtype, "seconds": times,
                "nan": bool(torch.isnan(out).any())}
    else:
        t0 = time.time()
        result = pipe(person, cloth, num_timesteps=args.steps, **call)
        info = {"mode": "full", "device": args.device, "dtype": args.dtype, "steps": args.steps,
                "seconds_total": round(time.time() - t0, 1)}
        result.images[0].save(common.OUT / f"reference-{args.device}-{args.dtype}-{args.steps}.png")

    (common.OUT / f"reference-{args.mode}-{args.device}-{args.dtype}.json").write_text(json.dumps(info, indent=2))
    print(json.dumps(info))


if __name__ == "__main__":
    main()
