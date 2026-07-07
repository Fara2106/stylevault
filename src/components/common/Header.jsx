import './Header.css';

export default function Header({ title, subtitle, onBack, action, actionIcon }) {
  return (
    <header className="page-header">
      <div className="page-header__left">
        {onBack && (
          <button className="page-header__back" onClick={onBack}>←</button>
        )}
      </div>
      <div className="page-header__center">
        <h1 className="page-header__title">{title}</h1>
        {subtitle && <p className="page-header__subtitle">{subtitle}</p>}
      </div>
      <div className="page-header__right">
        {action && (
          <button className="page-header__action" onClick={action}>
            {actionIcon || '⚙️'}
          </button>
        )}
      </div>
    </header>
  );
}
