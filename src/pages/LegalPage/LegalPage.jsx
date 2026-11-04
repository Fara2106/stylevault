import { Link } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import LanguageSwitch from '../../components/LanguageSwitch/LanguageSwitch';
import { legalText, UPDATED } from './legalContent';
import './LegalPage.css';

/**
 * Pagine pubbliche (senza login) di Privacy, Supporto ed Eliminazione
 * account: i loro indirizzi vanno in App Store Connect.
 * @param {{kind: 'privacy'|'support'|'deletion'}} props
 */
export default function LegalPage({ kind }) {
  const { i18n } = useTranslation();
  const text = legalText(i18n.language);
  const page = text[kind];

  return (
    <main className="legal-page">
      <div className="legal-page__top">
        <Link to="/" className="legal-page__brand">
          StyleVault
        </Link>
        <LanguageSwitch />
      </div>
      <h1 className="legal-page__title">{page.title}</h1>
      <p className="legal-page__intro">{page.intro}</p>
      {page.sections.map((section) => (
        <section key={section.h} className="legal-page__section">
          <h2>{section.h}</h2>
          {section.p.map((paragraph) => (
            <p key={paragraph}>{paragraph}</p>
          ))}
        </section>
      ))}
      <p className="legal-page__updated">
        {text.updatedLabel}: {UPDATED}
      </p>
      <nav className="legal-page__nav">
        <Link to="/privacy">{legalText(i18n.language).privacy.title}</Link>
        <Link to="/supporto">{legalText(i18n.language).support.title}</Link>
        <Link to="/elimina-account">{legalText(i18n.language).deletion.title}</Link>
        <Link to="/">{text.back}</Link>
      </nav>
    </main>
  );
}
