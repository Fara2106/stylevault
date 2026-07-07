import { useTranslation } from 'react-i18next';
import './Button.css';

export default function Button({ children, variant = 'primary', size = 'md', onClick, disabled, fullWidth, icon, loading, type = 'button', className = '' }) {
  return (
    <button
      type={type}
      className={`btn btn--${variant} btn--${size} ${fullWidth ? 'btn--full' : ''} ${loading ? 'btn--loading' : ''} ${className}`}
      onClick={onClick}
      disabled={disabled || loading}
    >
      {loading && <span className="btn__spinner" />}
      {icon && !loading && <span className="btn__icon">{icon}</span>}
      {children && <span className="btn__text">{children}</span>}
    </button>
  );
}
