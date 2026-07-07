import { useLocation, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useProfile } from '../../context/ProfileContext';
import OutfitOnAvatar from '../../components/Avatar/OutfitOnAvatar';
import { Header, Button } from '../../components/common';
import { CLOTHING_COLORS } from '../../utils/categories';
import './TryOnPage.css';

const outfitItems = (outfit) =>
  [outfit.top, outfit.bottom, outfit.shoes, outfit.outerwear, ...(outfit.accessories || [])]
    .filter(Boolean);

/**
 * Prova outfit sull'avatar. L'outfit arriva via location.state
 * (dalla pagina Outfit, dal Calendario o dalla Wishlist).
 */
export default function TryOnPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { state } = useLocation();
  const { avatarConfig } = useProfile();

  const outfit = state?.outfit;

  if (!outfit) {
    return (
      <div className="sv-page">
        <Header title={t('tryon.title')} onBack={() => navigate(-1)} />
        <div className="sv-empty">
          <p className="sv-empty__title">{t('tryon.empty')}</p>
          <Button onClick={() => navigate('/outfit')}>{t('outfit.generateOutfit')}</Button>
        </div>
      </div>
    );
  }

  const items = outfitItems(outfit);
  const paletteIds = [...new Set(items.flatMap((i) => i.colors || []))];
  const paletteHex = (id) => CLOTHING_COLORS.find((c) => c.id === id)?.hex || '#ccc';
  const hasWishlistItems = items.some((i) => i.fromWishlist);

  return (
    <div className="sv-page tryon-page">
      <Header title={t('tryon.title')} onBack={() => navigate(-1)} />

      {hasWishlistItems && (
        <p className="tryon-page__wishlist-note sv-label">{t('tryon.withWishlist')}</p>
      )}

      <OutfitOnAvatar outfit={outfit} avatarConfig={avatarConfig} />

      {paletteIds.length > 0 && (
        <div className="tryon-page__palette">
          <span className="sv-label">{t('tryon.palette')}</span>
          <div className="tryon-page__palette-row">
            {paletteIds.map((id) => (
              <span
                key={id}
                className="tryon-page__palette-dot"
                style={{ backgroundColor: paletteHex(id) }}
                title={t(`colors.${id}`)}
              />
            ))}
          </div>
        </div>
      )}

      <ul className="tryon-page__list">
        {items.map((item) => (
          <li key={item.id}>
            <img src={item.photo} alt={item.name} />
            <div>
              <strong>{item.name}</strong>
              {item.brand && <span>{item.brand}</span>}
            </div>
          </li>
        ))}
      </ul>
    </div>
  );
}
