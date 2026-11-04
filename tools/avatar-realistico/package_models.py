"""Impacchetta i modelli Core ML a 6 bit e il tokenizzatore per la Release
(un .aar per modello), con models-manifest.json e MODELS-LICENSE.md.

Non importa Mobile_VTON.

uso: python -I package_models.py WEIGHTS
uscita: out/release/
"""
import argparse
import hashlib
import json
import shutil
import subprocess
import tempfile
from pathlib import Path

HERE = Path(__file__).resolve().parent
OUT = HERE / "out"
REL = OUT / "release"
MODELS = ["TextEncoder", "TextEncoder2", "ImageEncoder", "VAEEncoder", "DenoiserGarment", "Denoiser", "VAEDecoder"]


def archive(src: Path, dst: Path):
    dst.unlink(missing_ok=True)
    subprocess.run(["/usr/bin/aa", "archive", "-d", str(src), "-o", str(dst)], check=True)


def sha256(path: Path) -> str:
    h = hashlib.sha256()
    with open(path, "rb") as f:
        while chunk := f.read(1 << 20):
            h.update(chunk)
    return h.hexdigest()


def main():
    a = argparse.ArgumentParser()
    a.add_argument("weights")
    args = a.parse_args()
    mancanti = [n for n in MODELS if not (OUT / "coreml-6bit" / f"{n}.mlpackage").is_dir()]
    if mancanti:
        raise SystemExit(f"Mancano in out/coreml-6bit/: {', '.join(m + '.mlpackage' for m in mancanti)}")
    shutil.rmtree(REL, ignore_errors=True)
    REL.mkdir(parents=True)
    for name in MODELS:
        archive(OUT / "coreml-6bit" / f"{name}.mlpackage", REL / f"{name}.aar")
    with tempfile.TemporaryDirectory() as tmp:
        for f in ("vocab.json", "merges.txt"):
            shutil.copyfile(Path(args.weights) / "tokenizer" / f, Path(tmp) / f)
        archive(Path(tmp), REL / "Tokenizer.aar")
    shutil.copyfile(HERE / "MODELS-LICENSE.md", REL / "MODELS-LICENSE.md")
    files = []
    for p in sorted(REL.glob("*.aar")):
        files.append({"name": p.name, "bytes": p.stat().st_size, "sha256": sha256(p)})
    (REL / "models-manifest.json").write_text(json.dumps({"version": 1, "files": files}, indent=1) + "\n")
    for f in files:
        print(f"{f['name']:24} {f['bytes'] / 1e6:9.1f} MB")
    print(f"totale {sum(f['bytes'] for f in files) / 1e9:.2f} GB in {REL}")


if __name__ == "__main__":
    main()
