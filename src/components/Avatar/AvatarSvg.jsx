import { useId } from 'react';
import {
  getSkinHex,
  getHairHex,
  getBodyWidthFactor,
} from '../../utils/avatarOptions';
import { garmentLayers } from '../../utils/tryonComposer';

/**
 * Sagome degli indumenti nel sistema di coordinate del corpo (viewBox 200x400):
 * ogni capo è una o più path che ricalcano la silhouette leggermente allargata,
 * e un riquadro `box` in cui viene ritagliata la foto reale del capo.
 */
const GARMENT_SHAPES = {
  top: {
    paths: [
      'M100 62 C82 62 66 69 64 80 C61 97 73 116 75 136 C75.5 145 80 150 100 150 C120 150 124.5 145 125 136 C127 116 139 97 136 80 C134 69 118 62 100 62 Z',
      'M66 78 C58 88 56 102 55.5 114 C55.4 119 63 120 64 115 C65.5 104 68 92 71 86 Z',
      'M134 78 C142 88 144 102 144.5 114 C144.6 119 137 120 136 115 C134.5 104 132 92 129 86 Z',
    ],
    box: { x: 50, y: 58, width: 100, height: 96 },
  },
  dress: {
    paths: [
      'M100 62 C82 62 66 69 64 80 C61 97 71 116 73 138 C74.5 168 66 226 60 288 C59.3 296 63 300 70 300 L130 300 C137 300 140.7 296 140 288 C134 226 125.5 168 127 138 C129 116 139 97 136 80 C134 69 118 62 100 62 Z',
      'M66 78 C58 88 56 102 55.5 114 C55.4 119 63 120 64 115 C65.5 104 68 92 71 86 Z',
      'M134 78 C142 88 144 102 144.5 114 C144.6 119 137 120 136 115 C134.5 104 132 92 129 86 Z',
    ],
    box: { x: 54, y: 58, width: 92, height: 246 },
  },
  bottom: {
    paths: [
      'M78 130 C76 150 72 168 70 186 C68.5 198 73 206 78 209 C82 246 86 288 88 322 C89 338 90 352 90.5 360 L98.5 360 L98.5 216 L101.5 216 L101.5 360 L109.5 360 C110 352 111 338 112 322 C114 288 118 246 122 209 C127 206 131.5 198 130 186 C128 168 124 150 122 130 Z',
    ],
    box: { x: 66, y: 126, width: 68, height: 238 },
  },
  shoes: {
    paths: [
      'M81 365 a11 9 0 1 0 22 0 a11 9 0 1 0 -22 0 Z',
      'M97 365 a11 9 0 1 0 22 0 a11 9 0 1 0 -22 0 Z',
    ],
    box: { x: 78, y: 352, width: 44, height: 26 },
  },
  outerwear: {
    paths: [
      'M97 60 C80 59 63 66 60 78 C56 96 67 118 68 142 C69 166 63 186 62 196 C61.4 203 65 207 72 207 L97 207 Z',
      'M103 60 C120 59 137 66 140 78 C144 96 133 118 132 142 C131 166 137 186 138 196 C138.6 203 135 207 128 207 L103 207 Z',
      'M61 78 C53 90 51 114 50 138 C49.5 152 48 166 47 178 C46.6 186 55 187 56 181 C58 167 60 151 61.5 137 C63 119 65 99 68 88 Z',
      'M139 78 C147 90 149 114 150 138 C150.5 152 152 166 153 178 C153.4 186 145 187 144 181 C142 167 140 151 138.5 137 C137 119 135 99 132 88 Z',
    ],
    box: { x: 42, y: 54, width: 116, height: 157 },
  },
};

/**
 * Riquadri di ancoraggio per gli indumenti scontornati (foto trasparente).
 * Coordinate nel viewBox 200×400.
 */
const GARMENT_ANCHORS = {
  top:       { x: 48, y: 60,  width: 104, height: 100 },
  dress:     { x: 50, y: 60,  width: 100, height: 240 },
  // Il capo si adatta senza essere tagliato (`meet`), quindi la scala la decide
  // il lato più stretto. Con un riquadro largo 76 i pantaloni si fermavano a
  // metà polpaccio: era la larghezza a strozzarli, non l'altezza. A 96 arrivano
  // alla caviglia (i piedi stanno a y = 368).
  bottom:    { x: 52, y: 128, width: 96,  height: 232 },
  outerwear: { x: 40, y: 56,  width: 120, height: 155 },
  shoes:     { x: 74, y: 350, width: 52,  height: 30 },
};

/**
 * Silhouette stilizzata da figurino di moda, parametrica.
 * Corporatura: scala orizzontale del corpo (la testa resta fissa).
 * viewBox 200x400, esportata con height richiesta.
 * Con `outfit` la figura viene vestita: le foto dei capi riempiono
 * le sagome degli indumenti (vedi garmentLayers in tryonComposer).
 */
export default function AvatarSvg({ config, outfit, textures, height = 320, className = '' }) {
  const skin = getSkinHex(config?.skinTone);
  const hair = getHairHex(config?.hairColor);
  const w = getBodyWidthFactor(config?.bodyShape);
  const style = config?.hairStyle || 'medium';
  const uid = useId();
  const layers = garmentLayers(outfit);

  const renderGarment = ({ kind, item }) => {
    const shape = GARMENT_SHAPES[kind];
    if (!shape) return null;
    const texture = textures?.[item.id];

    // Capo scontornato: si appoggia sul corpo intero, senza ritagli.
    if (texture?.textureUrl) {
      return (
        <image
          key={kind}
          href={texture.textureUrl}
          {...GARMENT_ANCHORS[kind]}
          preserveAspectRatio="xMidYMin meet"
        />
      );
    }

    // Ripiego: la sagoma dell'indumento in tinta unita.
    const clipId = `${uid}-${kind}`;
    const fill = texture?.colorHex || '#cfc7bb';
    return (
      <g key={kind}>
        <clipPath id={clipId}>
          {shape.paths.map((d, i) => (
            <path key={i} d={d} />
          ))}
        </clipPath>
        <g clipPath={`url(#${clipId})`}>
          <rect {...shape.box} fill={fill} />
        </g>
        {shape.paths.map((d, i) => (
          <path key={`o${i}`} d={d} fill="none" stroke="rgba(26, 26, 26, 0.18)" strokeWidth="1" />
        ))}
      </g>
    );
  };

  return (
    <svg
      viewBox="0 0 200 400"
      height={height}
      width={height / 2}
      className={className}
      role="img"
      aria-label="avatar"
    >
      {/* Capelli lunghi: dietro al corpo */}
      {style === 'long' && (
        <>
          <path
            d="M78 26 C66 66 69 108 77 138 C81 144 88 143 89 137 C85 108 84 68 88 38 Z"
            fill={hair}
          />
          <path
            d="M122 26 C134 66 131 108 123 138 C119 144 112 143 111 137 C115 108 116 68 112 38 Z"
            fill={hair}
          />
        </>
      )}

      {/* Corpo (scalato in larghezza attorno all'asse centrale) */}
      <g transform={`translate(100 0) scale(${w} 1) translate(-100 0)`}>
        {/* collo */}
        <rect x="95" y="52" width="10" height="18" rx="4" fill={skin} />
        {/* torso a clessidra morbida */}
        <path
          d="M100 66 C84 66 70 72 68 82 C65 98 75 116 77 134 C79 152 72 168 70 184 C68 197 78 206 100 206 C122 206 132 197 130 184 C128 168 121 152 123 134 C125 116 135 98 132 82 C130 72 116 66 100 66 Z"
          fill={skin}
        />
        {/* braccia */}
        <path
          d="M68 82 C59 94 57 118 56 140 C55.5 155 54 170 53 182 C52.6 189 60 190 61 184 C63 170 65 155 66.5 140 C68 122 70 102 73 90 Z"
          fill={skin}
        />
        <path
          d="M132 82 C141 94 143 118 144 140 C144.5 155 146 170 147 182 C147.4 189 140 190 139 184 C137 170 135 155 133.5 140 C132 122 130 102 127 90 Z"
          fill={skin}
        />
        {/* gambe */}
        <path
          d="M79 202 C81 242 85 282 87 320 C88 336 89 352 90 362 L98 362 C98 348 98 330 98 316 C98 278 99 240 99 206 Z"
          fill={skin}
        />
        <path
          d="M121 202 C119 242 115 282 113 320 C112 336 111 352 110 362 L102 362 C102 348 102 330 102 316 C102 278 101 240 101 206 Z"
          fill={skin}
        />
        {/* piedi */}
        <ellipse cx="92" cy="368" rx="9" ry="5" fill={skin} />
        <ellipse cx="108" cy="368" rx="9" ry="5" fill={skin} />

        {/* Indumenti: dentro il gruppo scalato, così seguono la corporatura */}
        {layers.map(renderGarment)}
      </g>

      {/* Testa (non scalata) */}
      <ellipse cx="100" cy="36" rx="17" ry="21" fill={skin} />

      {/* Capigliature */}
      {style !== 'bald' && (
        <path
          d="M82 36 C79 12 90 6 100 6 C110 6 121 12 118 36 C113 20 107 16 100 16 C93 16 87 20 82 36 Z"
          fill={hair}
        />
      )}
      {(style === 'medium' || style === 'long') && (
        <>
          <path
            d="M82 30 C78 40 77 52 81 62 C84 64 88 62 88 58 C86 48 85 38 86 32 Z"
            fill={hair}
          />
          <path
            d="M118 30 C122 40 123 52 119 62 C116 64 112 62 112 58 C114 48 115 38 114 32 Z"
            fill={hair}
          />
        </>
      )}
      {style === 'bun' && <circle cx="100" cy="7" r="9" fill={hair} />}
      {style === 'curly' && (
        <>
          <circle cx="87" cy="14" r="10" fill={hair} />
          <circle cx="100" cy="9" r="11" fill={hair} />
          <circle cx="113" cy="14" r="10" fill={hair} />
          <circle cx="81" cy="26" r="8" fill={hair} />
          <circle cx="119" cy="26" r="8" fill={hair} />
        </>
      )}
    </svg>
  );
}
