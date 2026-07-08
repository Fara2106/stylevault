import { useState, useRef } from 'react';
import { Link, useLocation, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useProfile } from '../../context/ProfileContext';
import { useWardrobe } from '../../context/WardrobeContext';
import OutfitOnAvatar from '../../components/Avatar/OutfitOnAvatar';
import { Header, Button, Modal, Icon } from '../../components/common';
import { CLOTHING_COLORS } from '../../utils/categories';
import { resizeImageFile } from '../../utils/imageUtils';
import { getGeminiKey, generateTryOnPhoto } from '../../services/geminiTryon';
import {
  emptyOutfit,
  normalizeOutfit,
  outfitFromItem,
  applyItem,
  removeFromSlot,
  slotCategories,
  outfitHasItems,
} from '../../utils/tryonComposer';
import './TryOnPage.css';

const outfitItems = (outfit) =>
  [outfit.top, outfit.bottom, outfit.shoes, outfit.outerwear, ...(outfit.accessories || [])]
    .filter(Boolean);

/**
 * Prova outfit sull'avatar. Si può partire da un outfit già pronto
 * (via location.state, dalla pagina Outfit/Calendario) o da zero:
 * ogni slot è cliccabile e apre il guardaroba filtrato per categoria.
 */
export default function TryOnPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { state } = useLocation();
  const { avatarConfig, referencePhoto, setReferencePhoto } = useProfile();
  const { items: wardrobeItems, saveOutfit } = useWardrobe();

  const [outfit, setOutfit] = useState(() => {
    if (state?.outfit) return normalizeOutfit(state.outfit);
    if (state?.item) return outfitFromItem(state.item);
    return emptyOutfit();
  });
  const [pickerSlot, setPickerSlot] = useState(null);
  const [saved, setSaved] = useState(false);

  // Try-on fotografico (Gemini): chiave dell'utente, salvata solo nel browser
  const geminiKey = getGeminiKey();
  const [generating, setGenerating] = useState(false);
  const [photoResult, setPhotoResult] = useState(null);
  const [photoError, setPhotoError] = useState(null);
  const fileInputRef = useRef(null);

  const PHOTO_ERRORS = {
    'invalid-key': 'tryon.photoErrorInvalidKey',
    quota: 'tryon.photoErrorQuota',
    network: 'tryon.photoErrorNetwork',
    'no-image': 'tryon.photoErrorNoImage',
    'person-photo': 'tryon.photoErrorPerson',
    'no-garments': 'tryon.photoErrorGarments',
  };

  const handlePhotoFile = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    try {
      const dataUrl = await resizeImageFile(file, 1024, 0.85);
      setReferencePhoto(dataUrl);
      setPhotoResult(null);
      setPhotoError(null);
    } catch {
      setPhotoError('person-photo');
    }
  };

  const handleGenerate = async () => {
    setGenerating(true);
    setPhotoError(null);
    setPhotoResult(null);
    try {
      const result = await generateTryOnPhoto({
        apiKey: getGeminiKey(),
        personPhoto: referencePhoto,
        items: outfitItems(outfit),
      });
      setPhotoResult(result);
    } catch (err) {
      setPhotoError(err.code || 'network');
    } finally {
      setGenerating(false);
    }
  };

  const items = outfitItems(outfit);
  const paletteIds = [...new Set(items.flatMap((i) => i.colors || []))];
  const paletteHex = (id) => CLOTHING_COLORS.find((c) => c.id === id)?.hex || '#ccc';
  const hasWishlistItems = items.some((i) => i.fromWishlist);

  const pickerItems = pickerSlot
    ? wardrobeItems.filter((i) => slotCategories(pickerSlot).includes(i.category))
    : [];
  const isPicked = (item) =>
    pickerSlot === 'accessories'
      ? outfit.accessories.some((a) => a.id === item.id)
      : outfit[pickerSlot]?.id === item.id;

  const handlePick = (item) => {
    setOutfit((prev) => applyItem(prev, pickerSlot, item));
    setSaved(false);
    // Gli accessori sono multipli: il picker resta aperto per sceglierne altri
    if (pickerSlot !== 'accessories') setPickerSlot(null);
  };

  const handleRemove = (slot, itemId) => {
    setOutfit((prev) => removeFromSlot(prev, slot, itemId));
    setSaved(false);
  };

  const handleSave = () => {
    saveOutfit({ ...outfit, id: undefined });
    setSaved(true);
  };

  return (
    <div className="sv-page tryon-page">
      <Header title={t('tryon.title')} onBack={() => navigate(-1)} />

      <p className="tryon-page__hint sv-label">{t('tryon.hint')}</p>

      {hasWishlistItems && (
        <p className="tryon-page__wishlist-note sv-label">{t('tryon.withWishlist')}</p>
      )}

      <OutfitOnAvatar
        outfit={outfit}
        avatarConfig={avatarConfig}
        onSlotClick={setPickerSlot}
        onRemove={handleRemove}
      />

      {outfitHasItems(outfit) && (
        <div className="tryon-page__actions">
          <Button
            fullWidth
            icon={<Icon name={saved ? 'check' : 'heart'} size={15} />}
            onClick={handleSave}
            disabled={saved}
          >
            {saved ? t('outfit.saved') : t('tryon.saveOutfit')}
          </Button>
        </div>
      )}

      {/* Try-on fotografico con Gemini */}
      {outfitHasItems(outfit) && (
        <section className="tryon-page__photo">
          <h2 className="sv-label">{t('tryon.photoTitle')}</h2>
          <p className="tryon-page__photo-intro">{t('tryon.photoIntro')}</p>

          {!geminiKey ? (
            <p className="tryon-page__photo-note">
              {t('tryon.photoNeedsKey')}{' '}
              <Link to="/profile">{t('tryon.photoSetKey')}</Link>
            </p>
          ) : (
            <>
              {referencePhoto ? (
                <div className="tryon-page__photo-row">
                  <img
                    className="tryon-page__photo-person"
                    src={referencePhoto}
                    alt={t('tryon.photoTitle')}
                  />
                  <div className="tryon-page__photo-controls">
                    <Button
                      fullWidth
                      icon={<Icon name="sparkle" size={15} />}
                      onClick={handleGenerate}
                      loading={generating}
                      disabled={generating}
                    >
                      {generating
                        ? t('tryon.photoGenerating')
                        : t('tryon.photoGenerate')}
                    </Button>
                    <Button
                      fullWidth
                      variant="secondary"
                      icon={<Icon name="camera" size={14} />}
                      onClick={() => fileInputRef.current?.click()}
                      disabled={generating}
                    >
                      {t('tryon.photoChange')}
                    </Button>
                  </div>
                </div>
              ) : (
                <>
                  <p className="tryon-page__photo-note">
                    {t('tryon.photoNeedsPhoto')}
                  </p>
                  <Button
                    fullWidth
                    variant="secondary"
                    icon={<Icon name="camera" size={15} />}
                    onClick={() => fileInputRef.current?.click()}
                  >
                    {t('tryon.photoUpload')}
                  </Button>
                </>
              )}

              {photoError && (
                <p className="tryon-page__photo-error">
                  {t(PHOTO_ERRORS[photoError] || 'tryon.photoErrorNetwork')}
                </p>
              )}

              {photoResult && (
                <figure className="tryon-page__photo-result">
                  <img src={photoResult.image} alt={t('tryon.photoResult')} />
                  <figcaption className="sv-label">
                    {t('tryon.photoResult')}
                  </figcaption>
                  {photoResult.skipped.length > 0 && (
                    <p className="tryon-page__photo-note">
                      {t('tryon.photoSkipped', {
                        names: photoResult.skipped.join(', '),
                      })}
                    </p>
                  )}
                </figure>
              )}
            </>
          )}

          <input
            ref={fileInputRef}
            type="file"
            accept="image/*"
            hidden
            onChange={handlePhotoFile}
          />
        </section>
      )}

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

      <Modal
        isOpen={pickerSlot !== null}
        onClose={() => setPickerSlot(null)}
        title={t('tryon.choose')}
      >
        {pickerItems.length === 0 ? (
          <div className="tryon-page__picker-empty">
            <p>{t('tryon.noItems')}</p>
            <Button variant="secondary" onClick={() => navigate('/add')}>
              {t('wardrobe.addItem')}
            </Button>
          </div>
        ) : (
          <div className="tryon-page__picker">
            {pickerItems.map((item) => (
              <button
                key={item.id}
                type="button"
                className={`tryon-page__picker-item ${
                  isPicked(item) ? 'tryon-page__picker-item--active' : ''
                }`}
                onClick={() => handlePick(item)}
              >
                <img src={item.photo} alt={item.name} />
                <span>{item.name}</span>
                {isPicked(item) && (
                  <i className="tryon-page__picker-check">
                    <Icon name="check" size={12} />
                  </i>
                )}
              </button>
            ))}
          </div>
        )}
      </Modal>
    </div>
  );
}
