import {
  getSkinHex,
  getHairHex,
  getBodyWidthFactor,
} from '../../utils/avatarOptions';

/**
 * Silhouette stilizzata da figurino di moda, parametrica.
 * Corporatura: scala orizzontale del corpo (la testa resta fissa).
 * viewBox 200x400, esportata con height richiesta.
 */
export default function AvatarSvg({ config, height = 320, className = '' }) {
  const skin = getSkinHex(config?.skinTone);
  const hair = getHairHex(config?.hairColor);
  const w = getBodyWidthFactor(config?.bodyShape);
  const style = config?.hairStyle || 'medium';

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
