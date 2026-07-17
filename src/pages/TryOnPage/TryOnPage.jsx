import { useState, useRef, useEffect } from 'react';
import { useLocation, useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useProfile } from '../../context/ProfileContext';
import { useWardrobe } from '../../context/WardrobeContext';
import ModelTryOn from '../../components/Avatar/ModelTryOn';
import { Header, Button, Modal, Icon } from '../../components/common';
import { CLOTHING_COLORS } from '../../utils/categories';
import { resizeImageFile } from '../../utils/imageUtils';
import { buildTryOnPrompt } from '../../utils/tryOnPrompt';
import {
  emptyOutfit,
  normalizeOutfit,
  outfitFromItem,
  applyItem,
  removeFromSlot,
  slotCategories,
  outfitHasItems,
  MAX_ACCESSORIES,
} from '../../utils/tryonComposer';
import './TryOnPage.css';

const outfitItems = (outfit) =>
  [outfit.top, outfit.bottom, outfit.shoes, outfit.outerwear, ...(outfit.accessories || [])]
    .filter(Boolean);

/**
 * Prova outfit. Si può partire da un outfit già pronto (via location.state,
 * dalla pagina Outfit/Calendario) o da un singolo capo (dal Dettaglio): la
 * riga di slot in cima è sempre cliccabile e apre il guardaroba filtrato per
 * categoria, per completare o cambiare l'outfit prima di vederlo addosso.
 */
export default function TryOnPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { state } = useLocation();
  const { referencePhoto, setReferencePhoto } = useProfile();
  const { items: wardrobeItems, saveOutfit } = useWardrobe();

  const [outfit, setOutfit] = useState(() => {
    if (state?.outfit) return normalizeOutfit(state.outfit);
    if (state?.item) return outfitFromItem(state.item);
    return emptyOutfit();
  });
  const [pickerSlot, setPickerSlot] = useState(null);
  const [saved, setSaved] = useState(false);

  // Due modalità di prova, entrambe gratuite: "Su di te" (foto vera, capi
  // scontornati nelle sue proporzioni) e "Prompt AI" (prompt da incollare in
  // ChatGPT/Gemini). "Su di te" è la modalità predefinita.
  const [mode, setMode] = useState('model');

  const fileInputRef = useRef(null);

  const handlePhotoFile = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    if (!file) return;
    try {
      const dataUrl = await resizeImageFile(file, 1024, 0.85);
      setReferencePhoto(dataUrl);
    } catch {
      // Ridimensionamento fallito: la foto di riferimento resta quella precedente.
    }
  };

  const items = outfitItems(outfit);
  const paletteIds = [...new Set(items.flatMap((i) => i.colors || []))];
  const paletteHex = (id) => CLOTHING_COLORS.find((c) => c.id === id)?.hex || '#ccc';
  const hasWishlistItems = items.some((i) => i.fromWishlist);

  // Slot dell'outfit: capospalla, top/abito, bottom, scarpe. Ogni slot è
  // cliccabile (pieno o vuoto) per aprire il picker filtrato per categoria.
  const slotDefs = [
    { key: 'outerwear', item: outfit.outerwear, label: t('outfit.outerwear') },
    {
      key: 'top',
      item: outfit.top,
      label:
        outfit.top && !outfit.bottom && outfit.top.category === 'dresses'
          ? t('outfit.dress')
          : t('outfit.top'),
    },
    { key: 'bottom', item: outfit.bottom, label: t('outfit.bottom') },
    { key: 'shoes', item: outfit.shoes, label: t('outfit.shoes') },
  ];

  // Scheda "Prompt AI": nessuna chiamata di rete. Il prompt (inglese) si
  // rigenera quando cambiano i capi dell'outfit; resta editabile a mano.
  const itemsKey = items.map((i) => i.id).join(',');
  const [promptText, setPromptText] = useState(() => buildTryOnPrompt(items));
  const [promptCopied, setPromptCopied] = useState(false);

  useEffect(() => {
    setPromptText(buildTryOnPrompt(items));
    setPromptCopied(false);
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [itemsKey]);

  const handleCopyPrompt = async () => {
    try {
      await navigator.clipboard.writeText(promptText);
      setPromptCopied(true);
    } catch {
      // Clipboard non disponibile (browser vecchio, contesto non sicuro): il
      // testo resta comunque selezionabile a mano nella textarea.
      setPromptCopied(false);
    }
  };

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

      {/* Composizione dell'outfit: uno slot per tipo di capo, sempre visibile
          (indipendente dalla scheda scelta sotto). Cliccare uno slot pieno o
          vuoto apre il guardaroba filtrato per quella categoria. */}
      <div className="tryon-page__slots">
        {slotDefs.map(({ key, item, label }) =>
          item ? (
            <div key={key} className="tryon-page__slot">
              <button
                type="button"
                className="tryon-page__slot-pick"
                onClick={() => setPickerSlot(key)}
                aria-label={`${label}: ${item.name}`}
              >
                <img src={item.photo} alt={item.name} title={item.name} />
              </button>
              <button
                type="button"
                className="tryon-page__slot-remove"
                onClick={() => handleRemove(key, item.id)}
                aria-label={`${t('common.remove')} ${item.name}`}
              >
                <Icon name="close" size={11} />
              </button>
              <span className="tryon-page__slot-label sv-label">{label}</span>
            </div>
          ) : (
            <button
              key={key}
              type="button"
              className="tryon-page__slot tryon-page__slot--empty"
              onClick={() => setPickerSlot(key)}
            >
              <Icon name="plus" size={16} />
              <span>{label}</span>
            </button>
          )
        )}

        <div className="tryon-page__slot-accessories">
          {outfit.accessories.map((acc) => (
            <div key={acc.id} className="tryon-page__slot tryon-page__slot--accessory">
              <button
                type="button"
                className="tryon-page__slot-pick"
                onClick={() => setPickerSlot('accessories')}
                aria-label={acc.name}
              >
                <img src={acc.photo} alt={acc.name} title={acc.name} />
              </button>
              <button
                type="button"
                className="tryon-page__slot-remove"
                onClick={() => handleRemove('accessories', acc.id)}
                aria-label={`${t('common.remove')} ${acc.name}`}
              >
                <Icon name="close" size={11} />
              </button>
            </div>
          ))}
          {outfit.accessories.length < MAX_ACCESSORIES && (
            <button
              type="button"
              className="tryon-page__slot tryon-page__slot--empty tryon-page__slot--accessory"
              onClick={() => setPickerSlot('accessories')}
              aria-label={t('outfit.accessoriesLabel')}
              title={t('outfit.accessoriesLabel')}
            >
              <Icon name="plus" size={14} />
            </button>
          )}
        </div>
      </div>

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

      {/* Scelta della modalità di prova */}
      <div className="tryon-page__modes" role="tablist">
        <button
          type="button"
          role="tab"
          aria-selected={mode === 'model'}
          className={`tryon-page__mode ${mode === 'model' ? 'tryon-page__mode--active' : ''}`}
          onClick={() => setMode('model')}
        >
          {t('tryon.modeModel')}
        </button>
        <button
          type="button"
          role="tab"
          aria-selected={mode === 'photo'}
          className={`tryon-page__mode ${mode === 'photo' ? 'tryon-page__mode--active' : ''}`}
          onClick={() => setMode('photo')}
        >
          {t('tryon.modePhoto')}
        </button>
      </div>

      {/* "Su di te": la persona della foto, scontornata e vestita coi capi
          scontornati nelle sue proporzioni. Gratis, tutto on-device. */}
      {mode === 'model' && (
        <section className="tryon-page__photo">
          <p className="tryon-page__photo-intro">{t('tryon.modelIntro')}</p>

          {!outfitHasItems(outfit) ? (
            <p className="tryon-page__photo-note">{t('tryon.photoNoOutfit')}</p>
          ) : !referencePhoto ? (
            <>
              <p className="tryon-page__photo-note">{t('tryon.modelNeedsPhoto')}</p>
              <Button
                fullWidth
                variant="secondary"
                icon={<Icon name="camera" size={15} />}
                onClick={() => fileInputRef.current?.click()}
              >
                {t('tryon.photoUpload')}
              </Button>
            </>
          ) : (
            <>
              <ModelTryOn outfit={outfit} referencePhoto={referencePhoto} />
              <div className="tryon-page__actions">
                <Button
                  fullWidth
                  variant="secondary"
                  icon={<Icon name="camera" size={14} />}
                  onClick={() => fileInputRef.current?.click()}
                >
                  {t('tryon.photoChange')}
                </Button>
              </div>
            </>
          )}
        </section>
      )}

      {/* Prompt AI: l'app genera il testo del prompt (inglese, zero rete),
          Mary lo copia in ChatGPT/Gemini insieme alla sua foto e a quelle
          dei capi. Nessuna chiave, nessuna chiamata da qui. */}
      {mode === 'photo' && (
        <section className="tryon-page__prompt">
          <p className="tryon-page__photo-intro">{t('tryon.promptIntro')}</p>

          {!outfitHasItems(outfit) ? (
            <p className="tryon-page__photo-note">{t('tryon.photoNoOutfit')}</p>
          ) : (
            <>
              <ol className="tryon-page__prompt-steps">
                <li>{t('tryon.promptStep1')}</li>
                <li>{t('tryon.promptStep2')}</li>
                <li>{t('tryon.promptStep3')}</li>
                <li>{t('tryon.promptStep4')}</li>
              </ol>

              <div className="tryon-page__prompt-links">
                <a
                  className="tryon-page__prompt-link"
                  href="https://chatgpt.com/"
                  target="_blank"
                  rel="noopener"
                >
                  <Icon name="external" size={14} />
                  {t('tryon.promptOpenChatgpt')}
                </a>
                <a
                  className="tryon-page__prompt-link"
                  href="https://gemini.google.com/"
                  target="_blank"
                  rel="noopener"
                >
                  <Icon name="external" size={14} />
                  {t('tryon.promptOpenGemini')}
                </a>
              </div>

              <div className="tryon-page__prompt-garments">
                <span className="sv-label">{t('tryon.promptGarments')}</span>
                <div className="tryon-page__prompt-garments-row">
                  {items.map((item, i) => {
                    const isLocal = item.photo?.startsWith('data:');
                    return (
                      <a
                        key={item.id}
                        className="tryon-page__prompt-garment"
                        href={item.photo}
                        title={item.name}
                        {...(isLocal
                          ? { download: `${item.name || 'capo'}.jpg` }
                          : { target: '_blank', rel: 'noopener' })}
                      >
                        <img src={item.photo} alt={item.name} />
                        <span>{i + 2}</span>
                      </a>
                    );
                  })}
                </div>
              </div>

              <label className="tryon-page__prompt-label sv-label" htmlFor="tryon-prompt-text">
                {t('tryon.promptTitle')}
              </label>
              <textarea
                id="tryon-prompt-text"
                className="tryon-page__prompt-textarea"
                value={promptText}
                onChange={(e) => {
                  setPromptText(e.target.value);
                  setPromptCopied(false);
                }}
                rows={10}
              />
              <Button
                fullWidth
                variant="secondary"
                icon={promptCopied ? <Icon name="check" size={14} /> : undefined}
                onClick={handleCopyPrompt}
              >
                {promptCopied ? t('tryon.promptCopied') : t('tryon.promptCopy')}
              </Button>
            </>
          )}
        </section>
      )}

      {/* Input foto condiviso fra "Su di te" e la scheda AI */}
      <input
        ref={fileInputRef}
        type="file"
        accept="image/*"
        hidden
        onChange={handlePhotoFile}
      />


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
