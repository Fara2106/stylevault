"""Task 2/4 della prova tecnica: confronta ogni modello Core ML col riferimento
PyTorch del passo 0 (out/reference). PASSA se coseno ≥ soglia e nessun NaN.

uso: python -I verify_components.py [--models out/coreml-fp16] [--min-cos 0.999] [--only Denoiser ...]
                                    [--units CPU_AND_GPU]  (col Neural Engine il Mac si ferma sul Denoiser)
"""
import argparse
import sys
from pathlib import Path

import numpy as np

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402
from components import FEATURES, SPECS  # noqa: E402

REF = common.OUT / "reference"


def cosine(a: np.ndarray, b: np.ndarray) -> float:
    a, b = a.astype(np.float64).ravel(), b.astype(np.float64).ravel()
    return float(a @ b / (np.linalg.norm(a) * np.linalg.norm(b) + 1e-12))


def reference(spec) -> tuple[dict, dict]:
    """Ingressi e uscite attese del modello, presi dagli .npz del Task 1."""
    ins_npz = np.load(REF / f"step0_{spec.ref_in}_in.npz")
    outs_npz = np.load(REF / f"step0_{spec.ref_out}_out.npz")
    ins = {name: spec.slice_in(name, ins_npz[key]).astype(spec.input_dtype(name)) for name, key in spec.inputs.items()}
    outs = {name: spec.slice_out(name, outs_npz[key]) for name, key in spec.outputs.items()}
    return ins, outs


def main():
    import coremltools as ct

    a = argparse.ArgumentParser()
    a.add_argument("--models", default=str(common.OUT / "coreml-fp16"))
    a.add_argument("--min-cos", type=float, default=0.999)
    a.add_argument("--only", nargs="*", default=None)
    a.add_argument("--units", default="ALL", choices=["ALL", "CPU_AND_NE", "CPU_AND_GPU", "CPU_ONLY"])
    args = a.parse_args()

    found = [s for s in SPECS if (Path(args.models) / f"{s.name}.mlpackage").exists()
             and (not args.only or s.name in args.only)]
    print(f"{len(found)} pezzi trovati in {args.models}")
    failed = 0
    for spec in found:
        model = ct.models.MLModel(str(Path(args.models) / f"{spec.name}.mlpackage"),
                                  compute_units=getattr(ct.ComputeUnit, args.units))
        ins, expected = reference(spec)
        got = model.predict(ins)
        worst = min(cosine(got[n], expected[n]) for n in expected)
        nan = any(np.isnan(got[n]).any() for n in expected)
        maxerr = max(float(np.abs(got[n] - expected[n]).max()) for n in expected)
        ok = worst >= args.min_cos and not nan
        failed += not ok
        print(f"{'PASSA' if ok else 'NON PASSA'}  {spec.name:16s} coseno min {worst:.5f}  "
              f"errore max {maxerr:.4g}  NaN {nan}", flush=True)
        if spec.name.startswith("Denoiser") and spec.name != "DenoiserGarment":
            # Le 28 feature del capo devono restare nell'ordine giusto: scambiandone
            # due il risultato deve cambiare (altrimenti il confronto non le vede)
            swapped = dict(ins)
            swapped[FEATURES[0]], swapped[FEATURES[1]] = ins[FEATURES[1]], ins[FEATURES[0]]
            cos_swap = cosine(model.predict(swapped)["noise_pred"], expected["noise_pred"])
            print(f"       controllo ordine feature: scambiando 0 e 1 il coseno scende a {cos_swap:.5f}")
    print("tutti PASSANO" if found and not failed else f"{failed} NON PASSANO" if found else "nessun modello")


if __name__ == "__main__":
    main()
