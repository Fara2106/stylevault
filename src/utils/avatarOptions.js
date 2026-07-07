/**
 * Avatar options for StyleVault.
 * Defines the configurable parameters of the stylized fashion-figure avatar.
 */

export const BODY_SHAPES = [
  { id: 'slim', labelKey: 'avatar.bodyShapes.slim', widthFactor: 0.88 },
  { id: 'average', labelKey: 'avatar.bodyShapes.average', widthFactor: 1 },
  { id: 'athletic', labelKey: 'avatar.bodyShapes.athletic', widthFactor: 1.08 },
  { id: 'curvy', labelKey: 'avatar.bodyShapes.curvy', widthFactor: 1.16 },
  { id: 'plus', labelKey: 'avatar.bodyShapes.plus', widthFactor: 1.28 },
];

export const SKIN_TONES = [
  { id: 'porcelain', hex: '#F6E3D3' },
  { id: 'fair', hex: '#F0D5BD' },
  { id: 'light', hex: '#E3BC9A' },
  { id: 'medium', hex: '#C99A6E' },
  { id: 'tan', hex: '#A97C50' },
  { id: 'deep', hex: '#7D5537' },
  { id: 'rich', hex: '#5C3D26' },
  { id: 'ebony', hex: '#3E2A1B' },
];

export const HAIR_COLORS = [
  { id: 'black', hex: '#241C17' },
  { id: 'darkbrown', hex: '#3D2B1F' },
  { id: 'brown', hex: '#6B4A2F' },
  { id: 'auburn', hex: '#8A4B32' },
  { id: 'blonde', hex: '#C9A227' },
  { id: 'platinum', hex: '#E5D9C0' },
  { id: 'gray', hex: '#9A948E' },
  { id: 'red', hex: '#A34224' },
];

export const HAIR_STYLES = [
  { id: 'short', labelKey: 'avatar.hairStyles.short' },
  { id: 'medium', labelKey: 'avatar.hairStyles.medium' },
  { id: 'long', labelKey: 'avatar.hairStyles.long' },
  { id: 'bun', labelKey: 'avatar.hairStyles.bun' },
  { id: 'curly', labelKey: 'avatar.hairStyles.curly' },
  { id: 'bald', labelKey: 'avatar.hairStyles.bald' },
];

export const DEFAULT_AVATAR_CONFIG = {
  bodyShape: 'average',
  skinTone: 'medium',
  hairColor: 'brown',
  hairStyle: 'medium',
};

export function getSkinHex(skinToneId) {
  return SKIN_TONES.find((s) => s.id === skinToneId)?.hex || SKIN_TONES[3].hex;
}

export function getHairHex(hairColorId) {
  return HAIR_COLORS.find((h) => h.id === hairColorId)?.hex || HAIR_COLORS[2].hex;
}

export function getBodyWidthFactor(bodyShapeId) {
  return BODY_SHAPES.find((b) => b.id === bodyShapeId)?.widthFactor || 1;
}
