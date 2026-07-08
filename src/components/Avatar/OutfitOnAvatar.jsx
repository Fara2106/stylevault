import { useTranslation } from 'react-i18next';
import AvatarSvg from './AvatarSvg';
import { Icon } from '../common';
import { MAX_ACCESSORIES } from '../../utils/tryonComposer';
import './Avatar.css';

/**
 * Prova outfit "a collage": la silhouette dell'utente con le foto reali
 * dei capi disposte sugli slot (capospalla, top, bottom, scarpe, accessori).
 * Niente deformazioni: è uno styling board, non un try-on fotorealistico.
 *
 * Con `onSlotClick` diventa interattivo: gli slot vuoti mostrano un "+"
 * e ogni capo ha una ✕ per toglierlo (serve anche `onRemove`).
 */
export default function OutfitOnAvatar({ outfit, avatarConfig, onSlotClick, onRemove }) {
  const { t } = useTranslation();
  const interactive = typeof onSlotClick === 'function';
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
      <div className="tryon__stage">
        <div className="tryon__figure">
          <AvatarSvg config={avatarConfig} height={420} />
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
