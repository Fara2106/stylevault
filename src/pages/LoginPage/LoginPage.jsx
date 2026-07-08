import { useState } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../../context/AuthContext';
import { Button, Input } from '../../components/common';
import LanguageSwitch from '../../components/LanguageSwitch/LanguageSwitch';
import './LoginPage.css';

export default function LoginPage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { login, register, loginWithGoogle, isLoading, isCloud } = useAuth();

  const [mode, setMode] = useState('login'); // 'login' | 'register'
  const [name, setName] = useState('');
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [error, setError] = useState('');
  const [info, setInfo] = useState('');

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setInfo('');
    const result =
      mode === 'login'
        ? await login(email, password)
        : await register(name, email, password);
    if (result.success && result.needsConfirmation) {
      setInfo(t('auth.checkEmail'));
    } else if (result.success) {
      navigate('/wardrobe', { replace: true });
    } else {
      setError(result.error);
    }
  };

  const handleGoogle = async () => {
    setError('');
    const result = await loginWithGoogle();
    if (!result.success && result.error !== 'not-available') setError(result.error);
  };

  return (
    <div className="login-page">
      <div className="login-page__lang">
        <LanguageSwitch />
      </div>

      <div className="login-page__brand">
        <span className="login-page__eyebrow sv-label">Est. 2026</span>
        <h1 className="login-page__wordmark">StyleVault</h1>
        <p className="login-page__tagline">{t('app.tagline')}</p>
      </div>

      <form className="login-page__form" onSubmit={handleSubmit}>
        <h2 className="login-page__title">
          {mode === 'login' ? t('auth.loginTitle') : t('auth.registerTitle')}
        </h2>
        <p className="login-page__subtitle">
          {mode === 'login' ? t('auth.loginSubtitle') : t('auth.registerSubtitle')}
        </p>

        {mode === 'register' && (
          <Input
            label={t('auth.name')}
            value={name}
            onChange={(e) => setName(e.target.value)}
            name="name"
            required
          />
        )}
        <Input
          label={t('auth.email')}
          type="email"
          value={email}
          onChange={(e) => setEmail(e.target.value)}
          name="email"
          required
        />
        <Input
          label={t('auth.password')}
          type="password"
          value={password}
          onChange={(e) => setPassword(e.target.value)}
          name="password"
          required
        />

        {error && <p className="login-page__error">{error}</p>}
        {info && <p className="login-page__info">{info}</p>}

        <Button type="submit" fullWidth size="lg" loading={isLoading}>
          {mode === 'login' ? t('auth.login') : t('auth.register')}
        </Button>

        {isCloud ? (
          <Button
            type="button"
            variant="secondary"
            fullWidth
            size="lg"
            className="login-page__google"
            onClick={handleGoogle}
          >
            {t('auth.google')}
          </Button>
        ) : (
          <p className="login-page__google-note">{t('auth.googleSoon')}</p>
        )}

        <div className="sv-divider">
          <span className="sv-label">{t('common.or')}</span>
        </div>

        <button
          type="button"
          className="login-page__switch"
          onClick={() => {
            setMode(mode === 'login' ? 'register' : 'login');
            setError('');
          }}
        >
          {mode === 'login' ? t('auth.noAccount') : t('auth.hasAccount')}{' '}
          <strong>{mode === 'login' ? t('auth.register') : t('auth.login')}</strong>
        </button>
      </form>
    </div>
  );
}
