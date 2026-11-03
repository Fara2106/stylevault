import { useMemo, useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { Header, Button, Input, Icon } from '../../components/common';
import {
  FEEDBACK_MIN,
  FEEDBACK_MAX,
  canSendFeedback,
  currentDeviceInfo,
  findSensitive,
  sendFeedback,
} from '../../services/feedback';
import '../../components/LanguageSwitch/LanguageSwitch.css';
import './FeedbackPage.css';

const KINDS = ['bug', 'idea'];
const KIND_KEYS = { bug: 'feedback.kindBug', idea: 'feedback.kindIdea' };
const MESSAGE_KEYS = { bug: 'feedback.messageBug', idea: 'feedback.messageIdea' };
const HINT_KEYS = { bug: 'feedback.messageBugHint', idea: 'feedback.messageIdeaHint' };
const SENSITIVE_KEYS = {
  email: 'feedback.sensitiveEmail',
  number: 'feedback.sensitiveNumber',
  iban: 'feedback.sensitiveIban',
};
const ERROR_KEYS = {
  'feedback-limit': 'feedback.errorLimit',
  'feedback-unavailable': 'feedback.errorUnavailable',
};
const INFO_KEYS = {
  source: 'feedback.infoSource',
  appVersion: 'feedback.infoAppVersion',
  osVersion: 'feedback.infoOsVersion',
  model: 'feedback.infoModel',
  language: 'feedback.infoLanguage',
  userAgent: 'feedback.infoUserAgent',
};

/**
 * Segnalazioni di difetti e idee: arrivano per email a Lorenzo (Edge
 * Function send-feedback). L'avviso sui contenuti sensibili sta in alto e
 * l'utente vede esattamente quali info tecniche partono con il testo.
 */
export default function FeedbackPage() {
  const { t, i18n } = useTranslation();
  const navigate = useNavigate();
  const [kind, setKind] = useState('bug');
  const [message, setMessage] = useState('');
  const [status, setStatus] = useState('idle'); // idle | sending | sent
  const [error, setError] = useState(null);

  const info = useMemo(() => currentDeviceInfo(i18n.language), [i18n.language]);
  const sensitive = findSensitive(message);
  const length = message.trim().length;
  const fieldError = sensitive.length
    ? t('feedback.sensitive', { what: sensitive.map((s) => t(SENSITIVE_KEYS[s])).join(', ') })
    : null;

  const submit = async (event) => {
    event.preventDefault();
    if (!canSendFeedback(message)) return;
    setStatus('sending');
    setError(null);
    try {
      await sendFeedback({ kind, message, info });
      setStatus('sent');
      setMessage('');
    } catch (err) {
      setStatus('idle');
      setError(t(ERROR_KEYS[err.message] || 'feedback.errorFailed'));
    }
  };

  if (status === 'sent') {
    return (
      <div className="sv-page feedback-page">
        <Header title={t('feedback.title')} onBack={() => navigate('/profile')} />
        <div className="feedback-page__sent sv-card" role="status">
          <Icon name="check" size={28} />
          <h2>{t('feedback.sentTitle')}</h2>
          <p>{t('feedback.sentText')}</p>
          <Button fullWidth onClick={() => navigate('/profile')}>
            {t('feedback.backToProfile')}
          </Button>
          <Button fullWidth variant="secondary" onClick={() => setStatus('idle')}>
            {t('feedback.sendAnother')}
          </Button>
        </div>
      </div>
    );
  }

  return (
    <div className="sv-page feedback-page">
      <Header title={t('feedback.title')} onBack={() => navigate(-1)} />
      <p className="feedback-page__intro">{t('feedback.intro')}</p>

      <div className="feedback-page__warning" role="note">
        <Icon name="lock" size={18} />
        <div>
          <strong>{t('feedback.warningTitle')}</strong>
          <p>{t('feedback.warningText')}</p>
        </div>
      </div>

      <form className="feedback-page__form" onSubmit={submit}>
        <div className="feedback-page__kind">
          <span className="sv-label">{t('feedback.kindLabel')}</span>
          <div className="lang-switch" role="group" aria-label={t('feedback.kindLabel')}>
            {KINDS.map((option) => (
              <button
                key={option}
                type="button"
                aria-pressed={kind === option}
                className={`lang-switch__option ${kind === option ? 'lang-switch__option--active' : ''}`}
                onClick={() => setKind(option)}
              >
                {t(KIND_KEYS[option])}
              </button>
            ))}
          </div>
        </div>

        <Input
          type="textarea"
          label={t(MESSAGE_KEYS[kind])}
          placeholder={t(HINT_KEYS[kind])}
          value={message}
          onChange={(e) => setMessage(e.target.value.slice(0, FEEDBACK_MAX))}
          error={fieldError}
          maxLength={FEEDBACK_MAX}
          autoComplete="off"
        />
        <p className="feedback-page__count sv-label">
          {length > 0 && length < FEEDBACK_MIN
            ? t('feedback.tooShort', { min: FEEDBACK_MIN })
            : t('feedback.count', { count: length, max: FEEDBACK_MAX })}
        </p>

        <details className="feedback-page__info">
          <summary>{t('feedback.infoTitle')}</summary>
          <p>{t('feedback.infoNote')}</p>
          <dl>
            {Object.entries(info).map(([field, value]) => (
              <div key={field}>
                <dt>{t(INFO_KEYS[field])}</dt>
                <dd>{value}</dd>
              </div>
            ))}
          </dl>
        </details>

        {error && (
          <p className="feedback-page__error" role="alert">
            {error}
          </p>
        )}

        <Button
          type="submit"
          fullWidth
          loading={status === 'sending'}
          disabled={!canSendFeedback(message)}
        >
          {status === 'sending' ? t('feedback.sending') : t('feedback.send')}
        </Button>
      </form>
    </div>
  );
}
