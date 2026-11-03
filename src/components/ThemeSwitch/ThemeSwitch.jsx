import { useTranslation } from 'react-i18next';
import { useSettings } from '../../context/SettingsContext';
// Stesso selettore segmentato di IT/EN: le due righe del Profilo si somigliano
import '../LanguageSwitch/LanguageSwitch.css';

const OPTIONS = ['light', 'dark', 'system'];
const LABEL_KEYS = { light: 'profile.themeLight', dark: 'profile.themeDark', system: 'profile.themeSystem' };

export default function ThemeSwitch() {
  const { t } = useTranslation();
  const { theme, setTheme } = useSettings();

  return (
    <div className="lang-switch" role="group" aria-label={t('profile.theme')}>
      {OPTIONS.map((option) => (
        <button
          key={option}
          type="button"
          aria-pressed={theme === option}
          className={`lang-switch__option ${theme === option ? 'lang-switch__option--active' : ''}`}
          onClick={() => setTheme(option)}
        >
          {t(LABEL_KEYS[option])}
        </button>
      ))}
    </div>
  );
}
