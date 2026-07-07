import { useTranslation } from 'react-i18next';
import AvatarSvg from './AvatarSvg';
import './Avatar.css';

/**
 * Prova outfit "a collage": la silhouette dell'utente con le foto reali
 * dei capi disposte sugli slot (capospalla, top, bottom, scarpe, accessori).
 * Niente deformazioni: è uno styling board, non un try-on fotorealistico.
 */
export default function OutfitOnAvatar({ outfit, avatarConfig }) {
  const { t } = useTranslation();
  if (!outfit) return null;

  const slots = [
    outfit.outerwear && {
      key: 'outerwear',
      item: outfit.outerwear,
      className: 'tryon__slot--outerwear',
      label: t('outfit.outerwear'),
    },
    outfit.top && {
      key: 'top',
      item: outfit.top,
      className: 'tryon__slot--top',
      label: outfit.bottom ? t('outfit.top') : t('outfit.dress'),
    },
    outfit.bottom && {
      key: 'bottom',
      item: outfit.bottom,
      className: 'tryon__slot--bottom',
      label: t('outfit.bottom'),
    },
    outfit.shoes && {
      key: 'shoes',
      item: outfit.shoes,
      className: 'tryon__slot--shoes',
      label: t('outfit.shoes'),
    },
  ].filter(Boolean);

  return (
    <div className="tryon">
      <div className="tryon__stage">
        <div className="tryon__figure">
          <AvatarSvg config={avatarConfig} height={420} />
        </div>

        {slots.map(({ key, item, className, label }) => (
          <figure key={key} className={`tryon__slot ${className}`}>
            <img src={item.photo} alt={item.name} title={item.name} />
            <figcaption>{label}</figcaption>
          </figure>
        ))}

        {outfit.accessories?.length > 0 && (
          <div className="tryon__accessories">
            {outfit.accessories.map((acc) => (
              <figure key={acc.id} className="tryon__slot tryon__slot--accessory">
                <img src={acc.photo} alt={acc.name} title={acc.name} />
              </figure>
            ))}
          </div>
        )}
      </div>
    </div>
  );
}
