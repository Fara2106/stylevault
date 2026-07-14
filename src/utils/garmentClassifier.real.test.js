import { describe, it, expect } from 'vitest';
import sharp from 'sharp';
import { fileURLToPath } from 'node:url';
import { classifyGarmentImage } from './garmentClassifier';

// Come AddItemPage: la foto viene ridotta a max 600px prima di classificare.
const load = async (name) => {
  const path = fileURLToPath(new URL(`./__fixtures__/${name}`, import.meta.url));
  const { data, info } = await sharp(path)
    .resize(600, 600, { fit: 'inside', withoutEnlargement: true })
    .ensureAlpha()
    .raw()
    .toBuffer({ resolveWithObject: true });
  return { data: new Uint8ClampedArray(data), width: info.width, height: info.height };
};

// Positivi: screenshot reali (app). Negativi: foto di capi reali (loremflickr).
// NB: gli screenshot dell'app hanno MENO testo/UI di quelli di shopping, quindi
// tarare per beccare questi è conservativo (uno screenshot di shopping scatta
// ancora più facilmente). Vedi __fixtures__/README.md.
const SCREENSHOTS = ['screenshot-app-1.png', 'screenshot-app-2.png'];
const CAPI = ['capo-shirt.jpg', 'capo-jeans.jpg', 'capo-dress.jpg', 'capo-sweater.jpg'];

describe('classifyGarmentImage su immagini vere', () => {
  it.each(SCREENSHOTS)('%s è riconosciuto come screenshot', async (name) => {
    expect((await classifyGarmentImage(await load(name))).verdict).toBe('screenshot');
  });

  it.each(CAPI)('%s (foto di capo) NON è uno screenshot', async (name) => {
    expect((await classifyGarmentImage(await load(name))).verdict).not.toBe('screenshot');
  });
});
