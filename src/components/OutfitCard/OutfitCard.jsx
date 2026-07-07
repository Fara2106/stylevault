import { useTranslation } from 'react-i18next';
import './OutfitCard.css';

export default function OutfitCard({ outfit, onWear, onApprove, onReject }) {
  const { t } = useTranslation();

  const getScoreClass = (score) => {
    if (score >= 75) return 'score--great';
    if (score >= 50) return 'score--good';
    return 'score--low';
  };

  const sections = [
    { key: 'top', label: t('outfit.top'), item: outfit.top },
    { key: 'bottom', label: t('outfit.bottom'), item: outfit.bottom },
    { key: 'shoes', label: t('outfit.shoes'), item: outfit.shoes },
    outfit.outerwear && { key: 'outerwear', label: t('outfit.outerwear'), item: outfit.outerwear },
  ].filter(Boolean);

  return (
    <div className="outfit-card">
      <div className="outfit-card__score-bar">
        <span className={`outfit-card__score ${getScoreClass(outfit.score)}`}>
          {outfit.score}
        </span>
        <div className="outfit-card__badges">
          <span className="outfit-card__badge">🌤 {outfit.weatherMatch}%</span>
          <span className="outfit-card__badge">🎨 {outfit.colorHarmony}%</span>
        </div>
      </div>

      <div className="outfit-card__items">
        {sections.map(({ key, label, item }) => (
          <div key={key} className="outfit-card__item">
            <img src={item.photo} alt={item.name} className="outfit-card__thumb" />
            <div className="outfit-card__item-info">
              <span className="outfit-card__item-label">{label}</span>
              <span className="outfit-card__item-name">{item.name}</span>
            </div>
          </div>
        ))}
        {outfit.accessories?.length > 0 && (
          <div className="outfit-card__accessories">
            <span className="outfit-card__item-label">{t('outfit.accessoriesLabel')}</span>
            <div className="outfit-card__acc-list">
              {outfit.accessories.map(acc => (
                <img key={acc.id} src={acc.photo} alt={acc.name} className="outfit-card__acc-thumb" title={acc.name} />
              ))}
            </div>
          </div>
        )}
      </div>

      <div className="outfit-card__actions">
        {onReject && (
          <button className="outfit-card__btn outfit-card__btn--reject" onClick={() => onReject(outfit.id)}>✕</button>
        )}
        {onWear && (
          <button className="outfit-card__btn outfit-card__btn--wear" onClick={() => onWear(outfit)}>
            {t('outfit.wearThis')}
          </button>
        )}
        {onApprove && (
          <button className="outfit-card__btn outfit-card__btn--approve" onClick={() => onApprove(outfit)}>✓</button>
        )}
      </div>
    </div>
  );
}
