import { useState, useMemo } from 'react';
import { useParams, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useWardrobe } from '../../context/WardrobeContext';
import { Header, Button, Modal, Icon } from '../../components/common';
import { CLOTHING_COLORS, CATEGORIES } from '../../utils/categories';
import { slotForItem } from '../../utils/tryonComposer';
import './ItemDetailPage.css';

const outfitItemIds = (outfit) =>
  [outfit.top, outfit.bottom, outfit.shoes, outfit.outerwear, ...(outfit.accessories || [])]
    .filter(Boolean)
    .map((i) => i.id);

export default function ItemDetailPage() {
  const { t } = useTranslation();
  const { itemId } = useParams();
  const navigate = useNavigate();
  const { items, removeItem, toggleFavorite, savedOutfits, outfitHistory } = useWardrobe();
  const [confirmDelete, setConfirmDelete] = useState(false);

  const item = items.find((i) => i.id === itemId);

  const usage = useMemo(() => {
    if (!item) return { inOutfits: 0, wears: [], lastWorn: null };
    const inOutfits = savedOutfits.filter((o) => outfitItemIds(o).includes(item.id)).length;
    const wears = outfitHistory
      .filter((log) => log.worn !== false && outfitItemIds(log.outfit).includes(item.id))
      .map((log) => log.date)
      .sort()
      .reverse();
    return { inOutfits, wears, lastWorn: wears[0] || null };
  }, [item, savedOutfits, outfitHistory]);

  if (!item) {
    return (
      <div className="sv-page">
        <Header title={t('itemDetail.title')} onBack={() => navigate('/wardrobe')} />
        <div className="sv-empty">
          <p className="sv-empty__title">{t('common.noResults')}</p>
        </div>
      </div>
    );
  }

  const colorHex = (id) => CLOTHING_COLORS.find((c) => c.id === id)?.hex || '#ccc';
  const subLabelKey = CATEGORIES[item.category]?.subcategories.find(
    (s) => s.id === item.subcategory
  )?.labelKey;

  const facts = [
    { label: t('addItem.category'), value: t(`categories.${item.category}`) },
    subLabelKey && { label: t('addItem.subcategory'), value: t(subLabelKey) },
    item.brand && { label: t('addItem.brand'), value: item.brand },
    item.size && { label: t('addItem.size'), value: item.size },
    { label: t('addItem.season'), value: t(`seasons.${item.season || 'all'}`) },
    { label: t('addItem.occasion'), value: t(`occasions.${item.occasion || 'casual'}`) },
    item.warmthLevel > 0 && {
      label: t('addItem.warmth'),
      value: t(`addItem.warmthLevels.${item.warmthLevel}`),
    },
    item.price != null && item.price !== '' && {
      label: t('addItem.price'),
      value: `€ ${item.price}`,
    },
  ].filter(Boolean);

  return (
    <div className="sv-page item-detail">
      <Header
        title={t('itemDetail.title')}
        onBack={() => navigate('/wardrobe')}
        action={() => navigate(`/add?edit=${item.id}`)}
        actionIcon={<Icon name="edit" size={18} />}
      />

      <div className="item-detail__layout">
        <div className="item-detail__photo-wrap">
          <img src={item.photo} alt={item.name} className="item-detail__photo" />
          <button
            className={`item-detail__fav ${item.favorite ? 'item-detail__fav--active' : ''}`}
            onClick={() => toggleFavorite(item.id)}
          >
            <Icon name="heart" size={18} />
          </button>
        </div>

        <div className="item-detail__info">
          <h2 className="item-detail__name">{item.name}</h2>
          {item.brand && <p className="item-detail__brand sv-label">{item.brand}</p>}

          <div className="item-detail__colors">
            {item.colors?.map((c) => (
              <span key={c} className="item-detail__color">
                <i style={{ backgroundColor: colorHex(c) }} />
                {t(`colors.${c}`)}
              </span>
            ))}
          </div>

          <dl className="item-detail__facts">
            {facts.map((f) => (
              <div key={f.label} className="item-detail__fact">
                <dt className="sv-label">{f.label}</dt>
                <dd>{f.value}</dd>
              </div>
            ))}
          </dl>

          <div className="item-detail__usage sv-card">
            <p>
              <Icon name="sparkle" size={14} />
              {t('itemDetail.inOutfits', { count: usage.inOutfits })}
            </p>
            <p>
              <Icon name="calendar" size={14} />
              {usage.wears.length > 0
                ? `${t('itemDetail.timesWorn', { count: usage.wears.length })} — ${t('itemDetail.lastWorn', { date: usage.lastWorn })}`
                : t('itemDetail.neverWorn')}
            </p>
          </div>

          {item.sourceUrl && (
            <a
              className="item-detail__shop"
              href={item.sourceUrl}
              target="_blank"
              rel="noopener noreferrer"
            >
              <Icon name="external" size={15} />
              {t('itemDetail.openShop')}
            </a>
          )}

          {slotForItem(item) && (
            <Button
              fullWidth
              icon={<Icon name="user" size={15} />}
              onClick={() => navigate('/tryon', { state: { item } })}
              className="item-detail__tryon"
            >
              {t('itemDetail.tryOn')}
            </Button>
          )}

          <div className="item-detail__actions">
            <Button variant="secondary" icon={<Icon name="edit" size={15} />} onClick={() => navigate(`/add?edit=${item.id}`)}>
              {t('common.edit')}
            </Button>
            <Button variant="danger" icon={<Icon name="trash" size={15} />} onClick={() => setConfirmDelete(true)}>
              {t('itemDetail.deleteItem')}
            </Button>
          </div>
        </div>
      </div>

      <Modal
        isOpen={confirmDelete}
        onClose={() => setConfirmDelete(false)}
        title={t('itemDetail.deleteItem')}
        footer={
          <>
            <Button variant="ghost" onClick={() => setConfirmDelete(false)}>
              {t('common.cancel')}
            </Button>
            <Button
              variant="danger"
              onClick={() => {
                removeItem(item.id);
                navigate('/wardrobe');
              }}
            >
              {t('common.delete')}
            </Button>
          </>
        }
      >
        <p>{t('wardrobe.deleteConfirm')}</p>
      </Modal>
    </div>
  );
}
