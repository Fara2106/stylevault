"""Esporta i casi di prova del tokenizzatore CLIP e l'immagine del capo per i
test Swift dell'app (tokenizzatore BPE e preprocessing di DINOv2).

Non importa Mobile_VTON.

uso: python -I export_tokenizer_cases.py WEIGHTS
uscita: ios/StyleVaultTests/Fixtures/realistic/ con tokenizer-cases.json,
        cloth-pixels.bin (copia di out/bench-inputs/cloth_pixels.bin) e cloth.jpg
"""
import argparse
import json
import shutil
import sys
from pathlib import Path

from PIL import Image

sys.path.insert(0, str(Path(__file__).resolve().parent))
import common  # noqa: E402

FIXTURES = common.ROOT / "ios/StyleVaultTests/Fixtures/realistic"
LONG = " ".join(f"parola{i}" if i % 3 else "knit" for i in range(120))


def main():
    from transformers import CLIPTokenizer

    a = argparse.ArgumentParser()
    a.add_argument("weights")
    args = a.parse_args()
    FIXTURES.mkdir(parents=True, exist_ok=True)
    inputs = common.test_inputs()
    texts = [
        common.NEGATIVE,
        inputs["caption"],
        inputs["caption_cloth"],
        "The item is a light-blue button-up shirt.",
        "The item is a Maglione a trecce più caldo 🧶.",
        LONG,  # 120 parole: va troncata a 77 token
    ]
    toks = [CLIPTokenizer.from_pretrained(args.weights, subfolder=s) for s in ("tokenizer", "tokenizer_2")]
    cases = []
    for text in texts:
        ids, ids2 = (t([text], padding="max_length", max_length=t.model_max_length, truncation=True,
                       return_tensors="np").input_ids[0].tolist() for t in toks)
        assert len(ids) == len(ids2) == 77
        cases.append({"text": text, "ids": ids, "ids2": ids2})
    (FIXTURES / "tokenizer-cases.json").write_text(json.dumps(cases, ensure_ascii=False, indent=1) + "\n")
    shutil.copyfile(common.OUT / "bench-inputs/cloth_pixels.bin", FIXTURES / "cloth-pixels.bin")
    common.fit_3x4(Image.open(common.CLOTH)).save(FIXTURES / "cloth.jpg", quality=95)
    print(f"{len(cases)} casi in {FIXTURES}")


if __name__ == "__main__":
    main()
