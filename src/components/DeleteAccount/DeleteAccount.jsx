import { useState } from 'react';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../../context/AuthContext';
import { Button, Modal } from '../common';
import './DeleteAccount.css';

/**
 * "Elimina account" nel Profilo (Apple 5.1.1(v)): conferma esplicita, poi la
 * Edge Function `delete-account` cancella file, dati e utente. Nel sito e
 * nell'app (che chiude anche la sessione nativa).
 */
export default function DeleteAccount() {
  const { t } = useTranslation();
  const { deleteAccount } = useAuth();
  const [open, setOpen] = useState(false);
  const [deleting, setDeleting] = useState(false);
  const [error, setError] = useState('');

  const close = () => {
    if (deleting) return;
    setOpen(false);
    setError('');
  };

  const confirm = async () => {
    setError('');
    setDeleting(true);
    const result = await deleteAccount();
    setDeleting(false);
    if (!result.success) {
      setError(t(`auth.errors.${result.error}`, { defaultValue: t('auth.errors.delete-failed') }));
    }
    // Se riesce l'utente esce: la pagina passa da sola al login
  };

  return (
    <>
      <button type="button" className="delete-account__open" onClick={() => setOpen(true)}>
        {t('profile.deleteAccount')}
      </button>
      <Modal
        isOpen={open}
        onClose={close}
        title={t('profile.deleteAccountTitle')}
        footer={
          <>
            <Button variant="ghost" onClick={close} disabled={deleting}>
              {t('common.cancel')}
            </Button>
            <Button variant="danger" onClick={confirm} loading={deleting}>
              {t('profile.deleteAccountConfirm')}
            </Button>
          </>
        }
      >
        <p className="delete-account__text">{t('profile.deleteAccountText')}</p>
        {error && (
          <p className="delete-account__error" role="alert">
            {error}
          </p>
        )}
      </Modal>
    </>
  );
}
