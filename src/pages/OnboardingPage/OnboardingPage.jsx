import { useRef, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useProfile } from '../../context/ProfileContext';
import { useSettings } from '../../context/SettingsContext';
import CitySearch from '../../components/CitySearch/CitySearch';
import { Button, Icon } from '../../components/common';
import { resizeImageFile } from '../../utils/imageUtils';
import './OnboardingPage.css';

/**
 * Primo accesso: foto di riferimento (facoltativa, per "Su di te") e città
 * predefinita.
 */
export default function OnboardingPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { referencePhoto, setReferencePhoto, completeOnboarding } = useProfile();
  const { defaultCity, setDefaultCity } = useSettings();
  const [step, setStep] = useState(0);
  const fileInputRef = useRef(null);

  const finish = () => {
    completeOnboarding();
    navigate('/wardrobe', { replace: true });
  };

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

  return (
    <div className="onboarding">
      <header className="onboarding__head">
        <span className="sv-label">
          {step + 1} / 2 — {step === 0 ? t('onboarding.stepPhoto') : t('onboarding.stepCity')}
        </span>
        <h1 className="onboarding__title">{t('onboarding.welcome')}</h1>
        <p className="onboarding__intro">
          {step === 0 ? t('onboarding.stepPhotoHint') : t('onboarding.stepCityHint')}
        </p>
      </header>

      {step === 0 ? (
        <>
          <div className="onboarding__photo">
            {referencePhoto ? (
              <>
                <img
                  src={referencePhoto}
                  alt={t('avatar.referencePhoto')}
                  className="onboarding__photo-preview"
                />
                <button
                  type="button"
                  className="onboarding__photo-remove"
                  onClick={() => setReferencePhoto(null)}
                >
                  <Icon name="close" size={13} />
                  {t('avatar.removeReference')}
                </button>
              </>
            ) : (
              <button
                type="button"
                className="onboarding__photo-upload"
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
              hidden
              onChange={handlePhotoFile}
            />
          </div>
          <div className="onboarding__actions">
            <Button size="lg" fullWidth onClick={() => setStep(1)}>
              {t('common.next')}
            </Button>
          </div>
        </>
      ) : (
        <>
          <div className="onboarding__city">
            <CitySearch value={defaultCity} onSelect={setDefaultCity} />
            {defaultCity?.name && (
              <p className="onboarding__city-current">
                <span className="sv-label">{t('profile.defaultCity')}</span>
                <strong>
                  {defaultCity.name}
                  {defaultCity.country ? `, ${defaultCity.country}` : ''}
                </strong>
              </p>
            )}
          </div>
          <div className="onboarding__actions">
            <Button variant="secondary" size="lg" onClick={() => setStep(0)}>
              {t('common.back')}
            </Button>
            <Button size="lg" fullWidth onClick={finish}>
              {t('onboarding.finish')}
            </Button>
          </div>
        </>
      )}
    </div>
  );
}
