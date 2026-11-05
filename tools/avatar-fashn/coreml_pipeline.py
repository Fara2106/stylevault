"""Generazione intera con il modello Core ML, sugli ingressi catturati da reference.py.

Uso: FASHN_SPIKE=<cartella> python coreml_pipeline.py --model out/coreml-fp16/FashnTryOn.mlpackage
       [--units CPU_AND_GPU|CPU_AND_NE|ALL|CPU_ONLY] [--steps 30] [--reference out/reference-mps-fp16-30.png]
Stessa schedule e stessa guida della pipeline originale (Euler, CFG 1.5, niente
CFG all'ultimo passo). Stampa tempo di caricamento, tempo per passo e PSNR.
"""
import argparse
import json
import time
from pathlib import Path

import coremltools as ct
import numpy as np
from PIL import Image

import common


def psnr(a: np.ndarray, b: np.ndarray) -> float:
    mse = np.mean((a.astype(np.float64) - b.astype(np.float64)) ** 2)
    return float("inf") if mse == 0 else 10 * np.log10(255.0 ** 2 / mse)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--model", required=True)
    ap.add_argument("--units", default="CPU_AND_GPU")
    ap.add_argument("--steps", type=int, default=common.STEPS)
    ap.add_argument("--reference", default=None)
    args = ap.parse_args()

    fv = common.import_fashn()
    from fashn_vton.preprocessing import AspectPreserveResize, ResizePad
    from fashn_vton.utils import get_rf_schedule

    t0 = time.time()
    model = ct.models.MLModel(args.model, compute_units=getattr(ct.ComputeUnit, args.units))
    load_s = time.time() - t0

    d = np.load(common.OUT / "inputs.npz")
    cond = {n: d[n][:1].astype(np.float16) for n in
            ["ca_images", "garment_images", "person_poses", "garment_poses"]}
    uncond = {n: np.zeros_like(v) for n, v in cond.items()}
    cat_c = np.array([int(d["garment_categories"][0])], dtype=np.int32)
    cat_u = np.array([0], dtype=np.int32)

    images = d["x"][:1].astype(np.float32)  # stesso rumore iniziale del riferimento
    timesteps = get_rf_schedule(num_steps=args.steps, mu=1.5)
    step_times = []
    for i, (t_curr, t_prev) in enumerate(zip(timesteps[:-1], timesteps[1:])):
        s = time.time()
        common_in = {"x": images.astype(np.float16), "times": np.array([t_curr], dtype=np.float16)}
        v_c = model.predict({**common_in, **cond, "category": cat_c})["velocity"].astype(np.float32)
        if i >= args.steps - 1:  # skip_cfg_last_n_steps = 1
            v = v_c
        else:
            v_u = model.predict({**common_in, **uncond, "category": cat_u})["velocity"].astype(np.float32)
            v = v_u + common.GUIDANCE * (v_c - v_u)
        images = images + (t_prev - t_curr) * v
        step_times.append(time.time() - s)
        if i == 0:
            print(f"primo passo {step_times[0]:.2f} s", flush=True)

    out = np.clip(images[0], -1, 1)
    out = ((out.transpose(1, 2, 0) + 1) * 127.5).round().astype(np.uint8)

    # Toglie i bordi come la pipeline originale
    h, w = 864, 576
    pre = AspectPreserveResize(target_size=(h, h), mode="fit", backend="pil")
    rp = ResizePad((w, h), backend="opencv")
    rp(np.array(pre(Image.open(common.PERSON).convert("RGB"), allow_upsampling=False)), mem_padding=True)
    img = Image.fromarray(np.array(rp.unpad(out)))

    name = Path(args.model).parent.name + f"-{args.units}-{args.steps}"
    img.save(common.OUT / f"{name}.png")
    info = {"model": args.model, "units": args.units, "load_s": round(load_s, 1),
            "step_s_mean": round(float(np.mean(step_times[1:])), 2), "first_step_s": round(step_times[0], 2),
            "step_s": [round(s, 2) for s in step_times],  # l'ultimo passo è senza CFG: un passaggio solo
            "total_s": round(sum(step_times), 1), "nan": bool(np.isnan(images).any())}
    if args.reference:
        ref = np.array(Image.open(args.reference).convert("RGB"))
        info["psnr_db"] = round(psnr(ref, np.array(img)), 1) if ref.shape == np.array(img).shape else "dimensioni diverse"
    (common.OUT / f"{name}.json").write_text(json.dumps(info, indent=2))
    print(json.dumps(info))


if __name__ == "__main__":
    main()
