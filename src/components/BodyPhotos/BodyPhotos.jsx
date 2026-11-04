import { useRef, useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useProfile } from '../../context/ProfileContext';
import { Button, Icon } from '../common';
import { bodyPhotoSlots } from '../../utils/bodyPhotos';
import { isNativeApp, openNativeBodyPhotos } from '../../utils/nativeBridge';
import { resizeImageFile } from '../../utils/imageUtils';
import './BodyPhotos.css';

const LABEL_KEYS = { front: 'profile.bodyViewFront', side: 'profile.bodyViewSide', back: 'profile.bodyViewBack' };

/**
 * "Le tue foto" nel Profilo: le 3 foto del corpo in miniatura, nel sito e
 * nell'app. Nell'app una foto si rifà con la fotocamera nativa (che controlla
 * posa e persona); nel browser si sceglie un file.
 */
export default function BodyPhotos() {
  const { t } = useTranslation();
  const { referencePhoto, bodyPhotos, setBodyPhoto } = useProfile();
  const inputRef = useRef(null);
  const [pickingView, setPickingView] = useState(null);
  const [savingView, setSavingView] = useState(null);
  const [failed, setFailed] = useState(false);
  const native = isNativeApp();

  const pick = (view) => {
    setFailed(false);
    if (native) {
      openNativeBodyPhotos(view);
      return;
    }
    setPickingView(view);
    inputRef.current?.click();
  };

  const onFile = async (e) => {
    const file = e.target.files?.[0];
    e.target.value = '';
    const view = pickingView;
    if (!file || !view) return;
    setSavingView(view);
    try {
      await setBodyPhoto(view, await resizeImageFile(file, 1600, 0.85));
    } catch {
      setFailed(true);
    } finally {
      setSavingView(null);
    }
  };

  return (
    <section className="body-photos">
      <h2 className="sv-label">{t('profile.bodyPhotosTitle')}</h2>
      <div className="body-photos__grid">
        {bodyPhotoSlots({ referencePhoto, bodyPhotos }).map(({ view, url }) => (
          <button
            key={view}
            type="button"
            className="body-photos__slot"
            onClick={() => pick(view)}
            disabled={Boolean(savingView)}
          >
            <span className="body-photos__frame">
              {url ? (
                <img src={url} alt={t(LABEL_KEYS[view])} loading="lazy" />
              ) : (
                <span className="body-photos__empty">
                  <Icon name="camera" size={18} />
                  {t('profile.bodyPhotoMissing')}
                </span>
              )}
              {savingView === view && (
                <span className="body-photos__saving">{t('profile.bodyPhotoSaving')}</span>
              )}
            </span>
            <span className="body-photos__label">{t(LABEL_KEYS[view])}</span>
          </button>
        ))}
      </div>
      <p className="body-photos__hint">
        {t(native ? 'profile.bodyPhotosHintApp' : 'profile.bodyPhotosHintWeb')}
      </p>
      <p className="body-photos__hint">{t('profile.ownPhotoNotice')}</p>
      {failed && <p className="body-photos__error">{t('profile.bodyPhotoError')}</p>}
      {native && (
        <Button
          fullWidth
          variant="secondary"
          icon={<Icon name="camera" size={15} />}
          onClick={() => openNativeBodyPhotos()}
        >
          {t('profile.retakeBodyPhotos')}
        </Button>
      )}
      <input ref={inputRef} type="file" accept="image/*" hidden onChange={onFile} />
    </section>
  );
}
