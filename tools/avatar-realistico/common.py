"""Pezzi comuni agli script della prova tecnica: caricamento di Mobile-VTON e
coppia di prova fissa (persona + maglione). Vedi README.md."""
import json
import sys
from pathlib import Path

import torch
from PIL import Image, ImageOps
from torchvision import transforms

ROOT = Path(__file__).resolve().parents[2]
OUT = Path(__file__).resolve().parent / "out"

W, H = 768, 1024
STEPS = 10
SEED = 42
GUIDANCE = 2.5
SHIFT = 3.0
PERSON = ROOT / "ios/build/foto-corpo-test/1-davanti.jpg"
CLOTH = ROOT / "ios/StyleVaultTests/Fixtures/maglione.jpg"
DESC = ("The item is a cream white cable-knit crew neck sweater with long sleeves, "
        "ribbed cuffs and hem, made of a soft chunky wool knit.")
NEGATIVE = ("deformed, distorted, disfigured, poorly drawn, bad anatomy, wrong anatomy, extra limb, "
            "missing limb, floating limbs, mutated hands and fingers, disconnected limbs, mutation, "
            "mutated, ugly, disgusting, blurry, amputation, NSFW")

_norm = transforms.Compose([transforms.ToTensor(), transforms.Normalize([0.5], [0.5])])


def fit_3x4(img: Image.Image) -> Image.Image:
    """Porta a 3:4 768×1024 aggiungendo bianco, come le foto di VITON-HD."""
    return ImageOps.pad(img.convert("RGB"), (W, H), color=(255, 255, 255))


def test_inputs() -> dict:
    """La coppia di prova fissa, già nel formato del modello."""
    person = fit_3x4(Image.open(PERSON))
    cloth = fit_3x4(Image.open(CLOTH))
    return {
        "person": person,
        "cloth": cloth,
        "caption": "Replace the upper body with " + " ".join(DESC.split()[1:]),
        "caption_cloth": DESC,
    }


def load_pipeline(repo: str, weights: str, dtype: torch.dtype, device: str):
    """Mobile-VTON come in inference.py del repo, su un solo dispositivo."""
    sys.path.insert(0, repo)
    from diffusers import FlowMatchEulerDiscreteScheduler
    from diffusers.models.autoencoders import AutoencoderKL
    from transformers import AutoImageProcessor, AutoModel, CLIPTextModelWithProjection, CLIPTokenizer
    from Mobile_VTON.models.autoencoders.vae import Decoder
    from Mobile_VTON.models.unets.unet_2d_condition_tryon import UNet2DConditionModel as UnetTryon
    from Mobile_VTON.models.unets.unet_2d_condition_garment import UNet2DConditionModel as UnetGarment
    from Mobile_VTON.pipelines.tryon_pipeline_full_cat import T2IMobilePipelineV1_3_NotLoadingT5_Decoder as Pipe

    vd = Decoder(**json.load(open(f"{weights}/vae_decoder/decoder.json")))
    vd.load_state_dict(torch.load(f"{weights}/vae_decoder/decoder.pt", map_location="cpu", weights_only=True),
                       strict=True)
    parts = dict(
        vae=AutoencoderKL.from_pretrained(weights, subfolder="vae"),
        text_encoder=CLIPTextModelWithProjection.from_pretrained(weights, subfolder="text_encoder"),
        text_encoder_2=CLIPTextModelWithProjection.from_pretrained(weights, subfolder="text_encoder_2"),
        image_encoder=AutoModel.from_pretrained(weights, subfolder="image_encoder"),
        denoiser=UnetTryon.from_pretrained(weights, subfolder="denoiser"),
        denoiser_garment=UnetGarment.from_pretrained(weights, subfolder="denoiser_garment"),
    )
    for m in parts.values():
        m.to(device, dtype=dtype).eval().requires_grad_(False)
    vd.to(device, dtype=torch.float32).eval().requires_grad_(False)
    pipe = Pipe(vae_decoder=vd, scheduler=FlowMatchEulerDiscreteScheduler(num_train_timesteps=1000, shift=SHIFT),
                tokenizer=CLIPTokenizer.from_pretrained(weights, subfolder="tokenizer"),
                tokenizer_2=CLIPTokenizer.from_pretrained(weights, subfolder="tokenizer_2"), **parts)
    pipe.image_processor_dino = AutoImageProcessor.from_pretrained(f"{weights}/image_encoder")
    return pipe


def generate(pipe, inputs: dict, device: str, steps: int = STEPS) -> Image.Image:
    """Una generazione completa, con gli stessi parametri di inference.py."""
    device = torch.device(device)  # la pipeline legge device.type
    gen = torch.Generator(device="cpu").manual_seed(SEED)
    with torch.no_grad():
        pe, npe, ppe, nppe = pipe.encode_prompt(prompt=[inputs["caption"]], prompt_2=[inputs["caption"]],
                                                num_images_per_prompt=1, do_classifier_free_guidance=True,
                                                negative_prompt=[NEGATIVE], device=device)
        pec, npec, _, _ = pipe.encode_prompt(prompt=[inputs["caption_cloth"]], prompt_2=[inputs["caption_cloth"]],
                                             num_images_per_prompt=1, do_classifier_free_guidance=False,
                                             negative_prompt=[NEGATIVE], device=device)
        ip = pipe.image_processor_dino(images=inputs["cloth"], return_tensors="pt").pixel_values
        return pipe(prompt_embeds=pe, negative_prompt_embeds=npe, pooled_prompt_embeds=ppe,
                    negative_pooled_prompt_embeds=nppe, num_inference_steps=steps, generator=gen,
                    height=H, width=W, guidance_scale=GUIDANCE, text_embeds_cloth=pec,
                    negative_text_embeds_cloth=npec, cloth=_norm(inputs["cloth"]).unsqueeze(0).to(device),
                    image=((_norm(inputs["person"]).unsqueeze(0) + 1) / 2).to(device),
                    ip_adapter_image=ip.to(device), device=device)[0][0]
