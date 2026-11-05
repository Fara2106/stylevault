"""Pezzi comuni della prova tecnica di FASHN VTON v1.5 (Apache 2.0). Vedi README.md.

Il codice di FASHN sta fuori dal repo, in $FASHN_SPIKE/repo, e i pesi in
$FASHN_SPIKE/weights. Il "human parser" di FASHN ha la licenza NVIDIA di
SegFormer (solo ricerca): qui lo sostituisce un finto modulo. Nella modalità
senza maschere e con il capo fotografato da solo ("flat-lay") la pipeline non
usa la sua uscita (preprocessing/agnostic.py: disable_masking restituisce
l'immagine così com'è), quindi il risultato non cambia.
"""
import os
import sys
import types
from pathlib import Path

import numpy as np

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / "out"
SPIKE = Path(os.environ.get("FASHN_SPIKE", ""))

# Stessa coppia di prova di Mobile-VTON (tools/avatar-realistico/common.py)
PERSON = ROOT / "ios/build/foto-corpo-test/1-davanti.jpg"
CLOTH = ROOT / "ios/StyleVaultTests/Fixtures/maglione.jpg"
CATEGORY = "tops"
SEED = 42
STEPS = 30
GUIDANCE = 1.5


class _NoParser:
    """Al posto di FashnHumanParser: maschera vuota, mai letta senza maschere."""

    def __init__(self, *args, **kwargs):
        pass

    def predict(self, img_np):
        return np.zeros(img_np.shape[:2], dtype=np.uint8)


def _install_parser_stub():
    stub = types.ModuleType("fashn_human_parser")
    stub.FashnHumanParser = _NoParser
    stub.CATEGORY_TO_BODY_COVERAGE = {"tops": "upper", "bottoms": "lower", "one-pieces": "full"}
    # Etichette fittizie: servono solo a calcolare indici che senza maschere nessuno legge
    stub.LABELS_TO_IDS = {"top": 1, "bottom": 2}
    stub.BODY_COVERAGE_TO_LABELS = {"upper": ["top"], "lower": ["bottom"], "full": ["top", "bottom"]}
    stub.IDENTITY_LABELS = []
    sys.modules["fashn_human_parser"] = stub


def import_fashn():
    """Rende importabile il pacchetto fashn_vton del repo, senza il parser."""
    if not (SPIKE / "repo/src/fashn_vton").is_dir():
        sys.exit("Imposta FASHN_SPIKE sulla cartella con repo/ e weights/")
    _install_parser_stub()
    sys.path.insert(0, str(SPIKE / "repo/src"))
    import fashn_vton  # noqa: F401
    return fashn_vton
