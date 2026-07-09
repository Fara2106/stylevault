import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { isSupabaseEnabled } from '../../services/supabaseClient';
import { useWardrobe } from '../../context/WardrobeContext';
import Icon from '../common/Icon';
import './StatusNotice.css';

const DISMISS_KEY = 'sv_local_notice_dismissed';

/**
 * Avvisi di stato sopra il guardaroba.
 * - Cloud non raggiungibile (es. progetto Supabase in pausa dopo inattività):
 *   invita ad avvisare Lorenzo; i dati sono al sicuro.
 * - Modalità locale (demo, senza cloud): i dati vivono solo nel browser e
 *   Safari/iOS può cancellarli dopo ~7 giorni senza visite. Chiudibile.
 */
export default function StatusNotice() {
  const { t } = useTranslation();
  const { cloudOffline } = useWardrobe();
  const [dismissed, setDismissed] = useState(
    () => localStorage.getItem(DISMISS_KEY) === '1'
  );

  if (isSupabaseEnabled) {
    if (!cloudOffline) return null;
    return (
      <div className="status-notice status-notice--alert" role="alert">
        <p className="status-notice__text">{t('app.cloudPausedNotice')}</p>
      </div>
    );
  }

  if (dismissed) return null;

  const dismiss = () => {
    try {
      localStorage.setItem(DISMISS_KEY, '1');
    } catch {
      /* quota piena: pazienza, riapparirà */
    }
    setDismissed(true);
  };

  return (
    <div className="status-notice" role="note">
      <p className="status-notice__text">{t('app.localNotice')}</p>
      <button
        type="button"
        className="status-notice__close"
        onClick={dismiss}
        aria-label={t('common.close')}
      >
        <Icon name="close" size={16} />
      </button>
    </div>
  );
}
