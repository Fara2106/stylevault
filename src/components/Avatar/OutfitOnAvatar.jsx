import { lazy, Suspense, useCallback, useEffect, useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import AvatarSvg from './AvatarSvg';
import Avatar3DBoundary from './Avatar3DBoundary';
import { Icon } from '../common';
import { MAX_ACCESSORIES } from '../../utils/tryonComposer';
import { loadGarmentTexture } from '../../utils/garmentImage';
import { hasWebGL } from '../../utils/webgl';
import './Avatar.css';

const Avatar3D = lazy(() => import('./Avatar3D'));

const RENDER_KEY = 'sv_avatar_render';

const readRenderMode = () => {
  if (!hasWebGL()) return 'flat';
  try {
    return localStorage.getItem(RENDER_KEY) === 'flat' ? 'flat' : '3d';
  } catch {
    return '3d';
  }
};

const outfitItems = (outfit) =>
  [outfit.top, outfit.bottom, outfit.shoes, outfit.outerwear].filter(Boolean);

/**
 * Prova outfit sull'avatar: la silhouette dell'utente viene vestita con le
 * foto reali dei capi, ritagliate nelle sagome degli indumenti (in AvatarSvg).
 * Le card intorno alla figura sono i controlli degli slot (capospalla, top,
 * bottom, scarpe, accessori) e mostrano etichetta e anteprima.
 *
 * Con `onSlotClick` diventa interattivo: gli slot vuoti mostrano un "+"
 * e ogni capo ha una ✕ per toglierlo (serve anche `onRemove`).
 */
export default function OutfitOnAvatar({ outfit, avatarConfig, onSlotClick, onRemove }) {
  const { t } = useTranslation();
  const interactive = typeof onSlotClick === 'function';

  const webgl = hasWebGL();
  const [renderMode, setRenderMode] = useState(readRenderMode);
  const [textures, setTextures] = useState({});
  // Una volta caduti in piatto per un guasto del 3D (renderer non creabile o
  // context perso a metà sessione), il bottone 3D resta disabilitato: è una
  // via sola, niente retry automatici in loop. Solo stato di sessione: non va
  // in localStorage, un refresh riparte da zero.
  const [webglBroken, setWebglBroken] = useState(false);
  const disabled3d = !webgl || webglBroken;

  const chooseMode = (mode) => {
    setRenderMode(mode);
    try {
      localStorage.setItem(RENDER_KEY, mode);
    } catch {
      /* modalità privata: la preferenza vale solo per questa sessione */
    }
  };

  // Chiamato da Avatar3D (renderer non creabile, context perso) o
  // dall'ErrorBoundary (qualunque altro throw a runtime nell'albero 3D):
  // stessa rete, stesso ripiego. Non tocca localStorage di proposito, per non
  // spacciare un guasto per una preferenza dell'utente.
  const handleUnavailable = useCallback(() => {
    setWebglBroken(true);
    setRenderMode('flat');
  }, []);

  // Le texture si calcolano una volta per capo e si riusano finché l'outfit non
  // cambia. Cache per id: ad ogni aggiunta/rimozione si ricalcola solo il capo
  // nuovo, non l'intero outfit (ogni ricalcolo ridecodifica la foto ed è ~100-200ms
  // di thread principale).
  const textureCacheRef = useRef(new Map());
  const itemsKey = outfitItems(outfit || {})
    .map((i) => i.id)
    .join(',');

  useEffect(() => {
    let cancelled = false;
    const items = outfitItems(outfit || {});
    const cache = textureCacheRef.current;
    const pending = items.filter((item) => !cache.has(item.id));

    Promise.all(pending.map((item) => loadGarmentTexture(item).then((t) => cache.set(item.id, t)))).then(
      () => {
        if (cancelled) return;
        const next = {};
        for (const item of items) next[item.id] = cache.get(item.id);
        setTextures(next);
      }
    );
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [itemsKey]);

  if (!outfit) return null;

  const slots = [
    {
      key: 'outerwear',
      item: outfit.outerwear,
      className: 'tryon__slot--outerwear',
      label: t('outfit.outerwear'),
    },
    {
      key: 'top',
      item: outfit.top,
      className: 'tryon__slot--top',
      label:
        outfit.top && !outfit.bottom && outfit.top.category === 'dresses'
          ? t('outfit.dress')
          : t('outfit.top'),
    },
    {
      key: 'bottom',
      item: outfit.bottom,
      className: 'tryon__slot--bottom',
      label: t('outfit.bottom'),
    },
    {
      key: 'shoes',
      item: outfit.shoes,
      className: 'tryon__slot--shoes',
      label: t('outfit.shoes'),
    },
  ].filter((slot) => slot.item || interactive);

  const accessories = outfit.accessories || [];

  const renderFilled = ({ key, item, className, label }) => (
    <figure key={key} className={`tryon__slot ${className}`}>
      {interactive ? (
        <>
          <button
            type="button"
            className="tryon__slot-pick"
            onClick={() => onSlotClick(key)}
            aria-label={`${label}: ${item.name}`}
          >
            <img src={item.photo} alt={item.name} title={item.name} />
          </button>
          <button
            type="button"
            className="tryon__slot-remove"
            onClick={() => onRemove(key, item.id)}
            aria-label={`${t('common.remove')} ${item.name}`}
          >
            <Icon name="close" size={11} />
          </button>
        </>
      ) : (
        <img src={item.photo} alt={item.name} title={item.name} />
      )}
      <figcaption>{label}</figcaption>
    </figure>
  );

  const renderEmpty = ({ key, className, label }) => (
    <button
      key={key}
      type="button"
      className={`tryon__slot tryon__slot--empty ${className}`}
      onClick={() => onSlotClick(key)}
    >
      <Icon name="plus" size={16} />
      <span>{label}</span>
    </button>
  );

  return (
    <div className="tryon">
      <div className="tryon__render">
        <div className="tryon__render-tabs" role="group">
          <button
            type="button"
            className={`tryon__render-tab ${renderMode === '3d' ? 'tryon__render-tab--active' : ''}`}
            onClick={() => chooseMode('3d')}
            disabled={disabled3d}
            aria-pressed={renderMode === '3d'}
          >
            {t('avatar.render3d')}
          </button>
          <button
            type="button"
            className={`tryon__render-tab ${renderMode === 'flat' ? 'tryon__render-tab--active' : ''}`}
            onClick={() => chooseMode('flat')}
            aria-pressed={renderMode === 'flat'}
          >
            {t('avatar.renderFlat')}
          </button>
        </div>
        <p className="tryon__render-hint sv-label">
          {disabled3d
            ? t('avatar.renderNoWebgl')
            : renderMode === '3d'
              ? t('avatar.render3dHint')
              : t('avatar.renderFlatHint')}
        </p>
      </div>
      <div className="tryon__stage">
        <div className="tryon__figure">
          {renderMode === '3d' && !disabled3d ? (
            <Avatar3DBoundary onUnavailable={handleUnavailable}>
              <Suspense fallback={<p className="tryon__loading sv-label">{t('avatar.renderLoading')}</p>}>
                <Avatar3D
                  config={avatarConfig}
                  outfit={outfit}
                  textures={textures}
                  height={420}
                  onUnavailable={handleUnavailable}
                />
              </Suspense>
            </Avatar3DBoundary>
          ) : (
            <AvatarSvg
              config={avatarConfig}
              outfit={outfit}
              textures={textures}
              height={420}
            />
          )}
        </div>

        {slots.map((slot) => (slot.item ? renderFilled(slot) : renderEmpty(slot)))}

        {(accessories.length > 0 || interactive) && (
          <div className="tryon__accessories">
            {accessories.map((acc) =>
              interactive ? (
                <figure key={acc.id} className="tryon__slot tryon__slot--accessory">
                  <button
                    type="button"
                    className="tryon__slot-pick"
                    onClick={() => onSlotClick('accessories')}
                    aria-label={acc.name}
                  >
                    <img src={acc.photo} alt={acc.name} title={acc.name} />
                  </button>
                  <button
                    type="button"
                    className="tryon__slot-remove"
                    onClick={() => onRemove('accessories', acc.id)}
                    aria-label={`${t('common.remove')} ${acc.name}`}
                  >
                    <Icon name="close" size={11} />
                  </button>
                </figure>
              ) : (
                <figure key={acc.id} className="tryon__slot tryon__slot--accessory">
                  <img src={acc.photo} alt={acc.name} title={acc.name} />
                </figure>
              )
            )}
            {interactive && accessories.length < MAX_ACCESSORIES && (
              <button
                type="button"
                className="tryon__slot tryon__slot--accessory tryon__slot--empty"
                onClick={() => onSlotClick('accessories')}
                aria-label={t('outfit.accessoriesLabel')}
                title={t('outfit.accessoriesLabel')}
              >
                <Icon name="plus" size={14} />
              </button>
            )}
          </div>
        )}
      </div>
    </div>
  );
}
