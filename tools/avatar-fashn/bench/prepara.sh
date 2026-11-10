#!/bin/zsh
# Prepara out/bench-payload: il modello compilato per Core ML e gli ingressi catturati (reference.py --mode capture).
# Uso: prepara.sh [6bit|fp16]
set -e
cd "$(dirname "$0")/../out"
kind=${1:-6bit}
rm -rf bench-payload && mkdir -p bench-payload/inputs
xcrun coremlcompiler compile coreml-$kind/FashnTryOn.mlpackage bench-payload
unzip -q -o inputs.npz -d bench-payload/inputs
rm -f bench-payload/inputs/mask.npy
echo $kind > bench-payload/modello.txt
du -sh bench-payload
