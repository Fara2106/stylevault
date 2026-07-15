import { useState, useRef, useEffect } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useWardrobe } from '../../context/WardrobeContext';
import { Header, Button, Input, Icon } from '../../components/common';
import {
  CATEGORIES,
  CLOTHING_COLORS,
  SEASONS,
  OCCASIONS,
  getCategoryList,
  getSubcategories,
} from '../../utils/categories';
import { resizeImageFile } from '../../utils/imageUtils';
import { fetchLinkMetadata, isValidHttpUrl } from '../../services/linkMetadata';
import './AddItemPage.css';

const EMPTY_FORM = {
  name: '',
  category: '',
  subcategory: '',
  brand: '',
  size: '',
  colors: [],
  season: 'all',
  occasion: 'casual',
  warmthLevel: 2,
  price: '',
  photo: '',
  sourceUrl: '',
};

export default function AddItemPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const [params] = useSearchParams();
  const { items, addItem, updateItem, addToWishlist } = useWardrobe();
  const fileInputRef = useRef(null);

  const editId = params.get('edit');
  const editingItem = editId ? items.find((i) => i.id === editId) : null;

  const [mode, setMode] = useState('photo'); // 'photo' | 'link'
  const [destination, setDestination] = useState(
    params.get('dest') === 'wishlist' ? 'wishlist' : 'wardrobe'
  );
  const [form, setForm] = useState(EMPTY_FORM);
  const [linkUrl, setLinkUrl] = useState('');
  const [linkState, setLinkState] = useState('idle'); // idle | loading | success | error
  const [errors, setErrors] = useState({});

  // Modalità modifica: precompila dal capo esistente
  useEffect(() => {
    if (editingItem) {
      setForm({
        ...EMPTY_FORM,
        ...editingItem,
        price: editingItem.price ?? '',
      });
      if (editingItem.sourceUrl) setMode('link');
    }
  }, [editingItem]);

  const set = (field, value) => {
    setForm((prev) => ({ ...prev, [field]: value }));
    setErrors((prev) => ({ ...prev, [field]: undefined }));
  };

  const toggleColor = (colorId) => {
    setForm((prev) => ({
      ...prev,
      colors: prev.colors.includes(colorId)
        ? prev.colors.filter((c) => c !== colorId)
        : [...prev.colors, colorId],
    }));
  };

  const handlePhotoUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const dataUrl = await resizeImageFile(file, 600);
      // Niente blocco sugli screenshot: il capo viene aggiunto comunque. Se è uno
      // screenshot, l'avatar lo mostra in tinta unita (rete di sicurezza in
      // loadGarmentTexture) invece della foto grezza, finché il Piano 2 non porta
      // ritaglio + tap-to-cutout per scontornarlo davvero.
      set('photo', dataUrl);
    } catch {
      /* file non leggibile: nessun cambiamento */
    }
    e.target.value = '';
  };

  const analyzeLink = async () => {
    if (!isValidHttpUrl(linkUrl)) return;
    setLinkState('loading');
    set('sourceUrl', linkUrl);
    try {
      const meta = await fetchLinkMetadata(linkUrl);
      setForm((prev) => ({
        ...prev,
        sourceUrl: linkUrl,
        name: prev.name || meta.title,
        photo: prev.photo || meta.image,
        brand: prev.brand || meta.site,
      }));
      setLinkState('success');
    } catch {
      setLinkState('error');
    }
  };

  const validate = () => {
    const next = {};
    if (!form.name.trim()) next.name = t('addItem.nameRequired');
    if (!form.category) next.category = t('addItem.categoryRequired');
    setErrors(next);
    return Object.keys(next).length === 0;
  };

  const handleSave = () => {
    if (!validate()) return;
    const payload = {
      ...form,
      name: form.name.trim(),
      price: form.price === '' ? null : Number(form.price),
      photo:
        form.photo ||
        `https://picsum.photos/seed/${encodeURIComponent(form.name.trim())}/400/533`,
    };

    if (editingItem) {
      updateItem(editingItem.id, payload);
      navigate(`/wardrobe/${editingItem.id}`);
      return;
    }
    if (destination === 'wishlist') {
      addToWishlist(payload);
    } else {
      addItem(payload);
    }
    navigate('/wardrobe');
  };

  const subcategories = form.category ? getSubcategories(form.category) : [];

  return (
    <div className="sv-page add-item">
      <Header
        title={editingItem ? t('common.edit') : t('addItem.title')}
        onBack={() => navigate(-1)}
      />

      {/* Scelta percorso */}
      {!editingItem && (
        <div className="add-item__modes">
          <button
            className={`add-item__mode ${mode === 'photo' ? 'add-item__mode--active' : ''}`}
            onClick={() => setMode('photo')}
          >
            <Icon name="camera" size={18} />
            {t('addItem.photo')}
          </button>
          <button
            className={`add-item__mode ${mode === 'link' ? 'add-item__mode--active' : ''}`}
            onClick={() => setMode('link')}
          >
            <Icon name="link" size={18} />
            {t('addItem.link')}
          </button>
        </div>
      )}

      {/* Sorgente: foto o link */}
      {mode === 'photo' ? (
        <div className="add-item__source">
          {form.photo ? (
            <div className="add-item__preview">
              <img src={form.photo} alt="" />
              <Button
                variant="secondary"
                size="sm"
                onClick={() => fileInputRef.current?.click()}
              >
                {t('addItem.changePhoto')}
              </Button>
            </div>
          ) : (
            <button
              className="add-item__dropzone"
              onClick={() => fileInputRef.current?.click()}
            >
              <Icon name="camera" size={28} strokeWidth={1.2} />
              <strong>{t('addItem.uploadPhoto')}</strong>
              <span>{t('addItem.photoHint')}</span>
            </button>
          )}
          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            className="visually-hidden"
            onChange={handlePhotoUpload}
          />
        </div>
      ) : (
        <div className="add-item__source">
          <div className="add-item__link-row">
            <div className="add-item__link-field">
              <Icon name="link" size={16} />
              <input
                type="url"
                value={linkUrl}
                onChange={(e) => setLinkUrl(e.target.value)}
                placeholder={t('addItem.pasteLink')}
              />
            </div>
            <Button
              onClick={analyzeLink}
              loading={linkState === 'loading'}
              disabled={!isValidHttpUrl(linkUrl)}
            >
              {t('addItem.analyzeLink')}
            </Button>
          </div>
          {linkState === 'loading' && (
            <p className="add-item__link-note">{t('addItem.linkLoading')}</p>
          )}
          {linkState === 'success' && (
            <p className="add-item__link-note add-item__link-note--ok">
              <Icon name="check" size={13} /> {t('addItem.linkSuccess')}
            </p>
          )}
          {linkState === 'error' && (
            <p className="add-item__link-note add-item__link-note--warn">
              {t('addItem.linkError')}
            </p>
          )}
          {form.photo && (
            <div className="add-item__preview">
              <img src={form.photo} alt="" />
            </div>
          )}
        </div>
      )}

      {/* Form */}
      <div className="add-item__form">
        <Input
          label={t('addItem.itemName')}
          value={form.name}
          onChange={(e) => set('name', e.target.value)}
          error={errors.name}
          required
        />

        <div className="add-item__group">
          <span className="sv-label">
            {t('addItem.category')} *
            {errors.category && (
              <em className="add-item__error"> — {errors.category}</em>
            )}
          </span>
          <div className="add-item__chips">
            {getCategoryList().map((cat) => (
              <button
                key={cat.id}
                className={`add-item__chip ${form.category === cat.id ? 'add-item__chip--active' : ''}`}
                onClick={() => {
                  set('category', cat.id);
                  set('subcategory', '');
                }}
              >
                {t(cat.labelKey)}
              </button>
            ))}
          </div>
        </div>

        {subcategories.length > 0 && (
          <div className="add-item__group">
            <span className="sv-label">{t('addItem.subcategory')}</span>
            <div className="add-item__chips">
              {subcategories.map((sub) => (
                <button
                  key={sub.id}
                  className={`add-item__chip ${form.subcategory === sub.id ? 'add-item__chip--active' : ''}`}
                  onClick={() => set('subcategory', sub.id)}
                >
                  {t(sub.labelKey)}
                </button>
              ))}
            </div>
          </div>
        )}

        <div className="add-item__group">
          <span className="sv-label">{t('addItem.colors')}</span>
          <div className="add-item__swatches">
            {CLOTHING_COLORS.map((color) => (
              <button
                key={color.id}
                className={`add-item__swatch ${form.colors.includes(color.id) ? 'add-item__swatch--active' : ''}`}
                style={{ backgroundColor: color.hex }}
                onClick={() => toggleColor(color.id)}
                title={t(color.labelKey)}
                aria-label={t(color.labelKey)}
              />
            ))}
          </div>
        </div>

        <div className="add-item__group">
          <span className="sv-label">{t('addItem.season')}</span>
          <div className="add-item__chips">
            {SEASONS.map((s) => (
              <button
                key={s.id}
                className={`add-item__chip ${form.season === s.id ? 'add-item__chip--active' : ''}`}
                onClick={() => set('season', s.id)}
              >
                {t(s.labelKey)}
              </button>
            ))}
          </div>
        </div>

        <div className="add-item__group">
          <span className="sv-label">{t('addItem.occasion')}</span>
          <div className="add-item__chips">
            {OCCASIONS.map((o) => (
              <button
                key={o.id}
                className={`add-item__chip ${form.occasion === o.id ? 'add-item__chip--active' : ''}`}
                onClick={() => set('occasion', o.id)}
              >
                {t(o.labelKey)}
              </button>
            ))}
          </div>
        </div>

        <div className="add-item__group">
          <span className="sv-label">
            {t('addItem.warmth')} — {t(`addItem.warmthLevels.${form.warmthLevel}`)}
          </span>
          <div className="add-item__warmth">
            {[1, 2, 3, 4, 5].map((level) => (
              <button
                key={level}
                className={`add-item__warmth-dot ${form.warmthLevel >= level ? 'add-item__warmth-dot--active' : ''}`}
                onClick={() => set('warmthLevel', level)}
                aria-label={t(`addItem.warmthLevels.${level}`)}
              />
            ))}
          </div>
        </div>

        <div className="add-item__row">
          <Input
            label={t('addItem.brand')}
            value={form.brand}
            onChange={(e) => set('brand', e.target.value)}
          />
          <Input
            label={t('addItem.size')}
            value={form.size}
            onChange={(e) => set('size', e.target.value)}
          />
        </div>
        <Input
          label={`${t('addItem.price')} (${t('common.optional')})`}
          type="number"
          value={form.price}
          onChange={(e) => set('price', e.target.value)}
        />

        {!editingItem && (
          <div className="add-item__group">
            <span className="sv-label">{t('addItem.destination')}</span>
            <div className="add-item__chips">
              <button
                className={`add-item__chip ${destination === 'wardrobe' ? 'add-item__chip--active' : ''}`}
                onClick={() => setDestination('wardrobe')}
              >
                {t('addItem.toWardrobe')}
              </button>
              <button
                className={`add-item__chip ${destination === 'wishlist' ? 'add-item__chip--active' : ''}`}
                onClick={() => setDestination('wishlist')}
              >
                {t('addItem.toWishlist')}
              </button>
            </div>
          </div>
        )}

        <Button size="lg" fullWidth onClick={handleSave}>
          {t('common.save')}
        </Button>
      </div>
    </div>
  );
}
