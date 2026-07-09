import { useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useWardrobe } from '../../context/WardrobeContext';
import ClothingCard from '../../components/ClothingCard/ClothingCard';
import StatusNotice from '../../components/StatusNotice/StatusNotice';
import CategoryFilter from '../../components/CategoryFilter/CategoryFilter';
import Icon from '../../components/common/Icon';
import { Button } from '../../components/common';
import { getCategoryList } from '../../utils/categories';
import './WardrobePage.css';

export default function WardrobePage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const {
    items,
    wishlist,
    toggleFavorite,
    moveWishlistToWardrobe,
    removeFromWishlist,
  } = useWardrobe();

  const [tab, setTab] = useState('wardrobe'); // 'wardrobe' | 'wishlist'
  const [category, setCategory] = useState('all');
  const [search, setSearch] = useState('');
  const [onlyFavorites, setOnlyFavorites] = useState(false);

  const filtered = useMemo(() => {
    let list = items;
    if (category !== 'all') list = list.filter((i) => i.category === category);
    if (onlyFavorites) list = list.filter((i) => i.favorite);
    if (search.trim()) {
      const q = search.trim().toLowerCase();
      list = list.filter(
        (i) =>
          i.name.toLowerCase().includes(q) ||
          (i.brand || '').toLowerCase().includes(q)
      );
    }
    return list;
  }, [items, category, search, onlyFavorites]);

  return (
    <div className="sv-page wardrobe">
      <StatusNotice />
      <header className="wardrobe__head">
        <div>
          <h1 className="wardrobe__title">
            {tab === 'wardrobe' ? t('wardrobe.title') : t('wishlist.title')}
          </h1>
          <p className="sv-label">
            {tab === 'wardrobe'
              ? t('wardrobe.subtitle', { count: items.length })
              : t('wishlist.subtitle')}
          </p>
        </div>
        <div className="wardrobe__tabs">
          <button
            className={`wardrobe__tab ${tab === 'wardrobe' ? 'wardrobe__tab--active' : ''}`}
            onClick={() => setTab('wardrobe')}
          >
            {t('wardrobe.tabWardrobe')}
          </button>
          <button
            className={`wardrobe__tab ${tab === 'wishlist' ? 'wardrobe__tab--active' : ''}`}
            onClick={() => setTab('wishlist')}
          >
            {t('wardrobe.tabWishlist')}
            {wishlist.length > 0 && (
              <span className="wardrobe__tab-count">{wishlist.length}</span>
            )}
          </button>
        </div>
      </header>

      {tab === 'wardrobe' ? (
        <>
          <div className="wardrobe__toolbar">
            <div className="wardrobe__search">
              <Icon name="search" size={16} />
              <input
                type="text"
                value={search}
                onChange={(e) => setSearch(e.target.value)}
                placeholder={t('wardrobe.searchPlaceholder')}
              />
            </div>
            <button
              className={`wardrobe__fav-filter ${onlyFavorites ? 'wardrobe__fav-filter--active' : ''}`}
              onClick={() => setOnlyFavorites(!onlyFavorites)}
              title={t('common.favorites')}
            >
              <Icon name="heart" size={16} />
            </button>
          </div>

          <CategoryFilter
            categories={getCategoryList()}
            activeCategory={category}
            onChange={setCategory}
          />

          {filtered.length === 0 ? (
            <div className="sv-empty">
              <p className="sv-empty__title">
                {items.length === 0 ? t('wardrobe.emptyState') : t('common.noResults')}
              </p>
              {items.length === 0 && (
                <Button onClick={() => navigate('/add')}>
                  {t('wardrobe.emptyAction')}
                </Button>
              )}
            </div>
          ) : (
            <div className="wardrobe__grid">
              {filtered.map((item) => (
                <ClothingCard
                  key={item.id}
                  item={item}
                  onFavorite={toggleFavorite}
                  onClick={() => navigate(`/wardrobe/${item.id}`)}
                />
              ))}
            </div>
          )}
        </>
      ) : (
        <>
          {wishlist.length === 0 ? (
            <div className="sv-empty">
              <p className="sv-empty__title">{t('wishlist.emptyState')}</p>
              <Button onClick={() => navigate('/add?dest=wishlist')}>
                {t('wishlist.emptyAction')}
              </Button>
            </div>
          ) : (
            <div className="wardrobe__grid">
              {wishlist.map((item) => (
                <div key={item.id} className="wishlist-card">
                  <ClothingCard item={item} />
                  <div className="wishlist-card__actions">
                    {item.sourceUrl && (
                      <a
                        href={item.sourceUrl}
                        target="_blank"
                        rel="noopener noreferrer"
                        className="wishlist-card__action"
                        title={t('wishlist.openLink')}
                      >
                        <Icon name="external" size={14} />
                      </a>
                    )}
                    <button
                      className="wishlist-card__action wishlist-card__action--primary"
                      onClick={() => moveWishlistToWardrobe(item.id)}
                      title={t('wishlist.moveToWardrobe')}
                    >
                      <Icon name="check" size={14} />
                      {t('wishlist.bought')}
                    </button>
                    <button
                      className="wishlist-card__action"
                      onClick={() => removeFromWishlist(item.id)}
                      title={t('common.delete')}
                    >
                      <Icon name="trash" size={14} />
                    </button>
                  </div>
                </div>
              ))}
            </div>
          )}
        </>
      )}
    </div>
  );
}
