"""Comprime i pesi del modello Core ML a 6 bit: stessa palette di Mobile-VTON
(tools/avatar-realistico/palettize.py), k-means per gruppi di 16 canali, da iOS 18.

Uso: python palettize.py   (da lanciare con guard.sh; serve scikit-learn)
Scrive out/coreml-6bit/FashnTryOn.mlpackage. Si verifica con coreml_pipeline.py.
"""
import time

import coremltools as ct
import coremltools.optimize.coreml as cto

import common


def size_mb(path) -> float:
    return sum(f.stat().st_size for f in path.rglob("*") if f.is_file()) / 1_048_576


def main():
    before = common.OUT / "coreml-fp16" / "FashnTryOn.mlpackage"
    after = common.OUT / "coreml-6bit" / "FashnTryOn.mlpackage"
    after.parent.mkdir(exist_ok=True)
    config = cto.OptimizationConfig(global_config=cto.OpPalettizerConfig(
        mode="kmeans", nbits=6, granularity="per_grouped_channel", group_size=16, num_kmeans_workers=6))
    t0 = time.time()
    model = ct.models.MLModel(str(before), skip_model_load=True)
    cto.palettize_weights(model, config).save(str(after))
    print(f"{size_mb(before):.0f} MB -> {size_mb(after):.0f} MB ({time.time() - t0:.0f} s)")


if __name__ == "__main__":
    main()
