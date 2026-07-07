import { CLOTHING_COLORS } from '../../utils/categories';
import Icon from '../common/Icon';
import './ClothingCard.css';

export default function ClothingCard({ item, onFavorite, onClick }) {
  const getColorHex = (colorId) => {
    const found = CLOTHING_COLORS.find((c) => c.id === colorId);
    return found ? found.hex : '#ccc';
  };

  return (
    <div className="clothing-card" onClick={() => onClick?.(item)}>
      <div className="clothing-card__image-wrap">
        <img
          src={item.photo}
          alt={item.name}
          className="clothing-card__image"
          loading="lazy"
        />
        {onFavorite && (
          <button
            className={`clothing-card__fav ${item.favorite ? 'clothing-card__fav--active' : ''}`}
            onClick={(e) => {
              e.stopPropagation();
              onFavorite(item.id);
            }}
            aria-label="favorite"
          >
            <Icon name="heart" size={16} strokeWidth={item.favorite ? 0 : 1.5} />
          </button>
        )}
      </div>
      <div className="clothing-card__info">
        <h3 className="clothing-card__name">{item.name}</h3>
        {item.brand && <p className="clothing-card__brand">{item.brand}</p>}
        <div className="clothing-card__colors">
          {item.colors?.map((color, i) => (
            <span
              key={i}
              className="clothing-card__color-dot"
              style={{ backgroundColor: getColorHex(color) }}
            />
          ))}
        </div>
      </div>
    </div>
  );
}
