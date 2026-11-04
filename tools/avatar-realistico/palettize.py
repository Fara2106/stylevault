"""Task 4 della prova tecnica: comprime i pesi dei modelli Core ML fp16 a 6 bit
(palette k-means per gruppi di canali, supportata da iOS 18). Stessi nomi e
interfacce: si verifica con verify_components.py e coreml_pipeline.py.

Non importa Mobile_VTON: solo coremltools.

uso: python -I palettize.py [--src out/coreml-fp16] [--nbits 6] [--only Denoiser ...]
uscita: out/coreml-<nbits>bit/<Nome>.mlpackage e dimensione totale
"""
import argparse
import shutil
import subprocess
import sys
import time
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402
from components import SPECS  # noqa: E402

MIN_MB = 50  # i pezzi più piccoli si copiano così come sono


def size_mb(path: Path) -> float:
    return sum(f.stat().st_size for f in path.rglob("*") if f.is_file()) / 1_048_576


def main():
    import coremltools as ct
    import coremltools.optimize.coreml as cto

    a = argparse.ArgumentParser()
    a.add_argument("--src", default=str(common.OUT / "coreml-fp16"))
    a.add_argument("--nbits", type=int, default=6)
    a.add_argument("--only", nargs="*", default=None)
    args = a.parse_args()
    src = Path(args.src)
    dst = common.OUT / f"coreml-{args.nbits}bit"
    dst.mkdir(parents=True, exist_ok=True)

    names = [s.name for s in SPECS if not args.only or s.name in args.only]
    if len(names) > 1:
        # coremltools 9 chiude il suo pool k-means dopo un paio di modelli
        # ("Pool not running"): un processo per modello
        for name in names:
            subprocess.run([sys.executable, "-I", "-u", __file__, "--src", str(src),
                            "--nbits", str(args.nbits), "--only", name], check=True)
        total = subprocess.run(["du", "-sh", str(dst)], capture_output=True, text=True).stdout.split()[0]
        print(f"totale {dst.name}: {total}")
        return

    config = cto.OptimizationConfig(global_config=cto.OpPalettizerConfig(
        mode="kmeans", nbits=args.nbits, granularity="per_grouped_channel", group_size=16,
        num_kmeans_workers=8))
    for spec in SPECS:
        if args.only and spec.name not in args.only:
            continue
        before = src / f"{spec.name}.mlpackage"
        after = dst / f"{spec.name}.mlpackage"
        if after.exists():
            shutil.rmtree(after)
        t0 = time.time()
        if size_mb(before) < MIN_MB:
            shutil.copytree(before, after)
        else:
            model = ct.models.MLModel(str(before), skip_model_load=True)
            cto.palettize_weights(model, config).save(str(after))
        print(f"{spec.name:16s} {size_mb(before):7.0f} MB → {size_mb(after):6.0f} MB  ({time.time() - t0:.0f} s)",
              flush=True)


if __name__ == "__main__":
    main()
