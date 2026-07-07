import { useTranslation } from 'react-i18next';
import Icon from '../common/Icon';
import './OutfitCard.css';

/**
 * Card di una proposta outfit.
 * - lockedIds/onToggleLock: blocco dei capi per la rigenerazione parziale
 * - onTryOn: apre la prova sull'avatar
 * - onSave/onWear: salva l'outfit / registralo come indossato
 */
export default function OutfitCard({
  outfit,
  lockedIds = [],
  onToggleLock,
  onSave,
  onWear,
  onTryOn,
  saved = false,
}) {
  const { t } = useTranslation();

  const sections = [
    { key: 'top', label: outfit.bottom ? t('outfit.top') : t('outfit.dress'), item: outfit.top },
    outfit.bottom && { key: 'bottom', label: t('outfit.bottom'), item: outfit.bottom },
    { key: 'shoes', label: t('outfit.shoes'), item: outfit.shoes },
    outfit.outerwear && { key: 'outerwear', label: t('outfit.outerwear'), item: outfit.outerwear },
  ].filter(Boolean);

  return (
    <div className="outfit-card sv-card">
      <div className="outfit-card__head">
        <div className="outfit-card__score">
          <span className="outfit-card__score-num">{outfit.score}</span>
          <span className="sv-label">{t('outfit.outfitScore')}</span>
        </div>
        <div className="outfit-card__metrics">
          <div className="outfit-card__metric">
            <span className="outfit-card__metric-value">{outfit.weatherMatch}%</span>
            <span className="sv-label">{t('outfit.weatherMatch')}</span>
          </div>
          <div className="outfit-card__metric">
            <span className="outfit-card__metric-value">{outfit.colorHarmony}%</span>
            <span className="sv-label">{t('outfit.colorMatch')}</span>
          </div>
        </div>
      </div>

      <div className="outfit-card__items">
        {sections.map(({ key, label, item }) => {
          const locked = lockedIds.includes(item.id);
          return (
            <div key={key} className="outfit-card__item">
              <img src={item.photo} alt={item.name} className="outfit-card__thumb" />
              <div className="outfit-card__item-info">
                <span className="sv-label">{label}</span>
                <span className="outfit-card__item-name">{item.name}</span>
              </div>
              {onToggleLock && (
                <button
                  className={`outfit-card__lock ${locked ? 'outfit-card__lock--active' : ''}`}
                  onClick={() => onToggleLock(item.id)}
                  title={locked ? t('outfit.unlockItem') : t('outfit.lockItem')}
                >
                  <Icon name={locked ? 'lock' : 'unlock'} size={15} />
                </button>
              )}
            </div>
          );
        })}

        {outfit.accessories?.length > 0 && (
          <div className="outfit-card__accessories">
            <span className="sv-label">{t('outfit.accessoriesLabel')}</span>
            <div className="outfit-card__acc-list">
              {outfit.accessories.map((acc) => (
                <img
                  key={acc.id}
                  src={acc.photo}
                  alt={acc.name}
                  className="outfit-card__acc-thumb"
                  title={acc.name}
                />
              ))}
            </div>
          </div>
        )}
      </div>

      <div className="outfit-card__actions">
        {onTryOn && (
          <button className="outfit-card__action" onClick={() => onTryOn(outfit)}>
            <Icon name="user" size={15} />
            {t('outfit.tryOn')}
          </button>
        )}
        {onSave && (
          <button
            className={`outfit-card__action ${saved ? 'outfit-card__action--done' : ''}`}
            onClick={() => !saved && onSave(outfit)}
          >
            <Icon name={saved ? 'check' : 'heart'} size={15} />
            {saved ? t('outfit.saved') : t('common.save')}
          </button>
        )}
        {onWear && (
          <button
            className="outfit-card__action outfit-card__action--primary"
            onClick={() => onWear(outfit)}
          >
            <Icon name="check" size={15} />
            {t('outfit.wearThis')}
          </button>
        )}
      </div>
    </div>
  );
}
