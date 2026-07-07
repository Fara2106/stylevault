import { useSettings } from '../../context/SettingsContext';
import './LanguageSwitch.css';

export default function LanguageSwitch() {
  const { language, setLanguage } = useSettings();

  return (
    <div className="lang-switch">
      <button
        className={`lang-switch__option ${language === 'it' ? 'lang-switch__option--active' : ''}`}
        onClick={() => setLanguage('it')}
      >
        IT
      </button>
      <button
        className={`lang-switch__option ${language === 'en' ? 'lang-switch__option--active' : ''}`}
        onClick={() => setLanguage('en')}
      >
        EN
      </button>
    </div>
  );
}
