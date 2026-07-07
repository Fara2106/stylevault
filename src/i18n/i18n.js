import i18n from 'i18next';
import { initReactI18next } from 'react-i18next';
import it from './it.json';
import en from './en.json';

const savedLang = localStorage.getItem('sv_settings');
let defaultLang = 'en';
if (savedLang) {
  try { defaultLang = JSON.parse(savedLang).language || 'en'; } catch(e) {}
} else if (navigator.language?.startsWith('it')) {
  defaultLang = 'it';
}

i18n.use(initReactI18next).init({
  resources: { it: { translation: it }, en: { translation: en } },
  lng: defaultLang,
  fallbackLng: 'en',
  interpolation: { escapeValue: false },
});

export default i18n;
