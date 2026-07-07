import { useRef } from 'react';
import { useTranslation } from 'react-i18next';
import AvatarSvg from './AvatarSvg';
import Icon from '../common/Icon';
import {
  BODY_SHAPES,
  SKIN_TONES,
  HAIR_COLORS,
  HAIR_STYLES,
} from '../../utils/avatarOptions';
import { resizeImageFile } from '../../utils/imageUtils';
import './Avatar.css';

/**
 * Editor dell'avatar: anteprima live + controlli, con la foto di riferimento
 * dell'utente affiancata (configurazione manuale guidata dalla foto).
 */
export default function AvatarEditor({
  config,
  onChange,
  referencePhoto,
  onReferencePhotoChange,
}) {
  const { t } = useTranslation();
  const fileInputRef = useRef(null);

  const handlePhotoUpload = async (e) => {
    const file = e.target.files?.[0];
    if (!file) return;
    try {
      const dataUrl = await resizeImageFile(file, 600);
      onReferencePhotoChange?.(dataUrl);
    } catch {
      // foto non leggibile: si ignora senza rompere l'editor
    }
    e.target.value = '';
  };

  return (
    <div className="avatar-editor">
      <div className="avatar-editor__preview">
        <div className="avatar-editor__figure sv-card">
          <AvatarSvg config={config} height={300} />
        </div>

        <div className="avatar-editor__reference">
          {referencePhoto ? (
            <>
              <img
                src={referencePhoto}
                alt={t('avatar.referencePhoto')}
                className="avatar-editor__reference-img"
              />
              <button
                className="avatar-editor__reference-remove"
                onClick={() => onReferencePhotoChange?.(null)}
              >
                <Icon name="close" size={13} />
                {t('avatar.removeReference')}
              </button>
            </>
          ) : (
            <button
              className="avatar-editor__reference-upload"
              onClick={() => fileInputRef.current?.click()}
            >
              <Icon name="camera" size={22} />
              <span>{t('avatar.uploadReference')}</span>
              <small>{t('avatar.referenceHint')}</small>
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
      </div>

      <div className="avatar-editor__controls">
        <div className="avatar-editor__group">
          <span className="sv-label">{t('avatar.bodyShape')}</span>
          <div className="avatar-editor__options">
            {BODY_SHAPES.map((shape) => (
              <button
                key={shape.id}
                className={`avatar-editor__chip ${config.bodyShape === shape.id ? 'avatar-editor__chip--active' : ''}`}
                onClick={() => onChange({ bodyShape: shape.id })}
              >
                {t(shape.labelKey)}
              </button>
            ))}
          </div>
        </div>

        <div className="avatar-editor__group">
          <span className="sv-label">{t('avatar.skinTone')}</span>
          <div className="avatar-editor__options">
            {SKIN_TONES.map((tone) => (
              <button
                key={tone.id}
                className={`avatar-editor__swatch ${config.skinTone === tone.id ? 'avatar-editor__swatch--active' : ''}`}
                style={{ backgroundColor: tone.hex }}
                onClick={() => onChange({ skinTone: tone.id })}
                aria-label={tone.id}
              />
            ))}
          </div>
        </div>

        <div className="avatar-editor__group">
          <span className="sv-label">{t('avatar.hairColor')}</span>
          <div className="avatar-editor__options">
            {HAIR_COLORS.map((color) => (
              <button
                key={color.id}
                className={`avatar-editor__swatch ${config.hairColor === color.id ? 'avatar-editor__swatch--active' : ''}`}
                style={{ backgroundColor: color.hex }}
                onClick={() => onChange({ hairColor: color.id })}
                aria-label={color.id}
              />
            ))}
          </div>
        </div>

        <div className="avatar-editor__group">
          <span className="sv-label">{t('avatar.hairStyle')}</span>
          <div className="avatar-editor__options">
            {HAIR_STYLES.map((hairStyle) => (
              <button
                key={hairStyle.id}
                className={`avatar-editor__chip ${config.hairStyle === hairStyle.id ? 'avatar-editor__chip--active' : ''}`}
                onClick={() => onChange({ hairStyle: hairStyle.id })}
              >
                {t(hairStyle.labelKey)}
              </button>
            ))}
          </div>
        </div>
      </div>
    </div>
  );
}
