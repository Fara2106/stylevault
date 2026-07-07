import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useProfile } from '../../context/ProfileContext';
import { useSettings } from '../../context/SettingsContext';
import AvatarEditor from '../../components/Avatar/AvatarEditor';
import CitySearch from '../../components/CitySearch/CitySearch';
import { Button } from '../../components/common';
import './OnboardingPage.css';

/**
 * Primo accesso: avatar (con foto riferimento) e città predefinita.
 */
export default function OnboardingPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const {
    avatarConfig,
    setAvatarConfig,
    referencePhoto,
    setReferencePhoto,
    completeOnboarding,
  } = useProfile();
  const { defaultCity, setDefaultCity } = useSettings();
  const [step, setStep] = useState(0);

  const finish = () => {
    completeOnboarding();
    navigate('/wardrobe', { replace: true });
  };

  return (
    <div className="onboarding">
      <header className="onboarding__head">
        <span className="sv-label">
          {step + 1} / 2 — {step === 0 ? t('onboarding.stepAvatar') : t('onboarding.stepCity')}
        </span>
        <h1 className="onboarding__title">{t('onboarding.welcome')}</h1>
        <p className="onboarding__intro">
          {step === 0 ? t('onboarding.stepAvatarHint') : t('onboarding.stepCityHint')}
        </p>
      </header>

      {step === 0 ? (
        <>
          <AvatarEditor
            config={avatarConfig}
            onChange={setAvatarConfig}
            referencePhoto={referencePhoto}
            onReferencePhotoChange={setReferencePhoto}
          />
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
