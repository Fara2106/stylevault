import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../../context/AuthContext';
import { Button, Icon, Input } from '../common';
import { MIN_PASSWORD_LENGTH } from '../../utils/passwordChange';
import './ChangePassword.css';

/**
 * "Cambia password" nel Profilo: un pulsante che apre i due campi (nuova e
 * ripetuta). Funziona nel sito e nell'app, che hanno la stessa sessione.
 */
export default function ChangePassword() {
  const { t } = useTranslation();
  const { user, changePassword } = useAuth();
  const [open, setOpen] = useState(false);
  const [password, setPassword] = useState('');
  const [confirm, setConfirm] = useState('');
  const [error, setError] = useState('');
  const [saving, setSaving] = useState(false);
  const [done, setDone] = useState(false);

  const reset = () => {
    setPassword('');
    setConfirm('');
    setError('');
  };

  const handleSubmit = async (e) => {
    e.preventDefault();
    setError('');
    setSaving(true);
    const result = await changePassword(password, confirm);
    setSaving(false);
    if (result.success) {
      reset();
      setOpen(false);
      setDone(true);
    } else {
      setError(t(`auth.errors.${result.error}`, { defaultValue: result.error }));
    }
  };

  if (!open) {
    return (
      <div className="change-password">
        <Button
          fullWidth
          variant="secondary"
          icon={<Icon name="lock" size={15} />}
          onClick={() => {
            setDone(false);
            setOpen(true);
          }}
        >
          {t('profile.changePassword')}
        </Button>
        {done && (
          <p className="change-password__done" role="status">
            {t('profile.passwordChanged')}
          </p>
        )}
      </div>
    );
  }

  return (
    <form className="change-password change-password--open sv-card" onSubmit={handleSubmit}>
      {/* Per il portachiavi/gestore password: aggiorna la voce giusta */}
      <input
        type="email"
        name="username"
        autoComplete="username"
        value={user?.email || ''}
        readOnly
        hidden
      />
      <Input
        label={t('profile.newPassword')}
        type="password"
        name="new-password"
        autoComplete="new-password"
        minLength={MIN_PASSWORD_LENGTH}
        value={password}
        onChange={(e) => setPassword(e.target.value)}
        required
      />
      <Input
        label={t('profile.confirmPassword')}
        type="password"
        name="confirm-password"
        autoComplete="new-password"
        minLength={MIN_PASSWORD_LENGTH}
        value={confirm}
        onChange={(e) => setConfirm(e.target.value)}
        required
      />
      {error && (
        <p className="change-password__error" role="alert">
          {error}
        </p>
      )}
      <div className="change-password__actions">
        <Button
          type="button"
          variant="ghost"
          onClick={() => {
            reset();
            setOpen(false);
          }}
        >
          {t('common.cancel')}
        </Button>
        <Button type="submit" loading={saving}>
          {t('common.save')}
        </Button>
      </div>
    </form>
  );
}
