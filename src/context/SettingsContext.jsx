import { createContext, useContext, useState, useEffect, useCallback } from 'react';
import i18n from '../i18n/i18n';

const SettingsContext = createContext(null);

const SETTINGS_KEY = 'sv_settings';

/**
 * Detect default language from browser.
 */
function getDefaultLanguage() {
  if (typeof navigator !== 'undefined' && navigator.language?.startsWith('it')) {
    return 'it';
  }
  return 'en';
}

/**
 * Load settings from localStorage.
 */
function loadSettings() {
  try {
    const stored = localStorage.getItem(SETTINGS_KEY);
    if (stored) return JSON.parse(stored);
  } catch (e) {
    console.warn('Failed to load settings:', e);
  }
  return null;
}

/**
 * Default settings.
 */
function getDefaults() {
  return {
    language: getDefaultLanguage(),
    units: 'celsius',
    defaultCity: 'Milano',
    theme: 'light',
  };
}

/**
 * SettingsProvider - manages app settings (language, units, city, theme).
 */
export function SettingsProvider({ children }) {
  const [settings, setSettings] = useState(() => {
    const stored = loadSettings();
    return stored ? { ...getDefaults(), ...stored } : getDefaults();
  });

  // Persist to localStorage on changes
  useEffect(() => {
    try {
      localStorage.setItem(SETTINGS_KEY, JSON.stringify(settings));
    } catch (e) {
      console.warn('Failed to save settings:', e);
    }
  }, [settings]);

  // Sync i18n language
  useEffect(() => {
    if (i18n.language !== settings.language) {
      i18n.changeLanguage(settings.language);
    }
  }, [settings.language]);

  const setLanguage = useCallback((lang) => {
    setSettings((prev) => ({ ...prev, language: lang }));
  }, []);

  const setUnits = useCallback((units) => {
    setSettings((prev) => ({ ...prev, units }));
  }, []);

  const setDefaultCity = useCallback((city) => {
    setSettings((prev) => ({ ...prev, defaultCity: city }));
  }, []);

  const setTheme = useCallback((theme) => {
    setSettings((prev) => ({ ...prev, theme }));
  }, []);

  const value = {
    language: settings.language,
    units: settings.units,
    defaultCity: settings.defaultCity,
    theme: settings.theme,
    setLanguage,
    setUnits,
    setDefaultCity,
    setTheme,
  };

  return (
    <SettingsContext.Provider value={value}>{children}</SettingsContext.Provider>
  );
}

/**
 * Hook to access settings context.
 */
export function useSettings() {
  const context = useContext(SettingsContext);
  if (!context) {
    throw new Error('useSettings must be used within a SettingsProvider');
  }
  return context;
}

export default SettingsContext;
