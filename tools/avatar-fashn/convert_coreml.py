"""Converte il trasformatore di FASHN VTON in Core ML (un passo di denoising, batch 1).

Uso: FASHN_SPIKE=<cartella> python convert_coreml.py
Scrive out/coreml-fp16/FashnTryOn.mlpackage. Il passo senza condizioni della
guida (CFG) usa lo stesso modello con ingressi a zero e categoria 0, come fa
apply_conditional_dropout nel codice originale.
"""
import sys

import coremltools as ct
import numpy as np
import torch
from einops import rearrange
from torch import nn

import common


def pack_rope(pe):
    """Dalle matrici di rotazione a [cos, sin]: 5 dimensioni invece di 6."""
    return torch.stack([pe[..., 0, 0], pe[..., 1, 0]], dim=-1)


def apply_rope_rank5(xq, xk, packed):
    """La stessa rotazione di apply_rope: Core ML non accetta tensori a 6 dimensioni."""
    cos, sin = packed[..., 0], packed[..., 1]

    def rotate(x):
        re, im = x[..., 0::2], x[..., 1::2]
        return torch.stack([cos * re - sin * im, sin * re + cos * im], dim=-1).flatten(-2)

    return rotate(xq), rotate(xk)


def check_rewrites(mmdit, pe):
    """Le due riscritture devono dare gli stessi numeri degli originali."""
    q, k = torch.randn(1, 2, pe.shape[2], pe.shape[3] * 2), torch.randn(1, 2, pe.shape[2], pe.shape[3] * 2)
    a, b = mmdit.apply_rope(q, k, pe), apply_rope_rank5(q, k, pack_rope(pe))
    print("apply_rope, diff max:", max((a[i] - b[i]).abs().max().item() for i in (0, 1)))
    x = torch.randn(1, 3 * 12 * 12, 4, 6)
    y = rearrange(x, "b (c ph pw) h w -> b c (h ph) (w pw)", ph=12, pw=12)
    print("pixel_shuffle, diff max:", (y - torch.pixel_shuffle(x, 12)).abs().max().item())


class OneStep(nn.Module):
    """TryOnModel.forward con posizioni e id precalcolati (sono costanti)."""

    def __init__(self, model):
        super().__init__()
        self.m = model
        h, w = model.input_shape
        g = (h // model.patch_size, w // model.patch_size)
        ids = torch.zeros(g[0], g[1], 3)
        ids[..., 1] += torch.arange(g[0])[:, None]
        ids[..., 2] += torch.arange(g[1])[None, :]
        ids = ids.reshape(1, -1, 3)
        self.raw_pe = model.pe_embedder(ids)
        x_pe = pack_rope(self.raw_pe)
        self.register_buffer("x_pe", x_pe)
        self.register_buffer("pe", torch.cat([x_pe, x_pe], dim=2))  # stessi id per persona e capo
        self.grid = g

    def forward(self, x, times, ca_images, garment_images, person_poses, garment_poses, category):
        m = self.m
        x = torch.cat([x, ca_images, person_poses], dim=1)
        x = m.x_embedder(x)
        img = rearrange(x, "b c h w -> b (h w) c")
        g = torch.cat([garment_images, garment_poses], dim=1)
        g = m.garment_embedder(g)
        txt = rearrange(g, "b c h w -> b (h w) c")
        vec = m.t_embedder(times) + m.y_embedder(category)
        for block in m.x_patch_mixer:
            img = block(img, vec=vec, pe=self.x_pe)
        for block in m.double_blocks:
            img, txt = block(img=img, txt=txt, vec=vec, pe=self.pe)
        img = torch.cat((txt, img), 1)
        for block in m.single_blocks:
            img = block(img, vec=vec, pe=self.pe)
        img = img[:, txt.shape[1]:, ...]
        out = m.final_layer(img, vec)
        out = rearrange(out, "b (h w) c -> b c h w", h=self.grid[0], w=self.grid[1])
        return torch.pixel_shuffle(out, m.patch_size)  # rearrange passerebbe da 6 dimensioni


def main():
    fv = common.import_fashn()
    from fashn_vton.utils import load_checkpoint

    # Su "meta" il modello non occupa memoria: assign=True gli dà direttamente i pesi
    # letti, invece di tenerne due copie da 3,9 GB su un Mac da 16 GB
    with torch.device("meta"):
        model = fv.TryOnModel()
    model.load_state_dict(load_checkpoint(str(common.SPIKE / "weights/model.safetensors")), assign=True)
    model.eval().float()
    step = OneStep(model).eval()
    from fashn_vton import tryon_mmdit as mmdit
    check_rewrites(mmdit, step.raw_pe)
    mmdit.apply_rope = apply_rope_rank5

    d = np.load(common.OUT / "inputs.npz")
    # metà condizionata del batch CFG catturato da reference.py
    names = ["x", "times", "ca_images", "garment_images", "person_poses", "garment_poses"]
    ex = [torch.from_numpy(d[n][:1]).float() for n in names]
    cat = torch.from_numpy(d["garment_categories"][:1]).int()

    with torch.no_grad():
        # OneStep coincide con l'originale: il 4/11 differenza massima 0.0, prima delle
        # due riscritture, che check_rewrites confronta ogni volta con gli originali.
        # Con --check il modello originale userebbe apply_rope già sostituita: gira su
        # OneStep soltanto, per controllare che esca un'immagine senza NaN.
        if "--check" in sys.argv:
            mine = step(*ex, cat.long())
            print("OneStep, NaN:", bool(torch.isnan(mine).any()))
        # check_trace rifarebbe il tracciamento una seconda volta
        traced = torch.jit.trace(step, (*ex, cat.long()), check_trace=False)

    inputs = [ct.TensorType(name=n, shape=t.shape, dtype=np.float16) for n, t in zip(names, ex)]
    inputs.append(ct.TensorType(name="category", shape=(1,), dtype=np.int32))
    mlmodel = ct.convert(
        traced,
        inputs=inputs,
        outputs=[ct.TensorType(name="velocity", dtype=np.float16)],
        minimum_deployment_target=ct.target.iOS18,
        compute_precision=ct.precision.FLOAT16,
        convert_to="mlprogram",
        skip_model_load=True,  # qui serve solo salvarlo: lo carica coreml_pipeline.py
    )
    dest = common.OUT / "coreml-fp16" / "FashnTryOn.mlpackage"
    dest.parent.mkdir(parents=True, exist_ok=True)
    mlmodel.save(str(dest))
    print("salvato", dest)


if __name__ == "__main__":
    main()
