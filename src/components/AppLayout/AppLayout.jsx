import { NavLink, Outlet } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import BottomNav from '../BottomNav/BottomNav';
import Icon from '../common/Icon';
import './AppLayout.css';

/**
 * Layout dell'app autenticata: header editoriale su desktop,
 * BottomNav su mobile, contenuto nelle route figlie.
 */
export default function AppLayout() {
  const { t } = useTranslation();

  const links = [
    { path: '/wardrobe', label: t('nav.wardrobe') },
    { path: '/outfit', label: t('nav.outfit') },
    { path: '/add', label: t('nav.add'), icon: 'plus' },
    { path: '/calendar', label: t('nav.calendar') },
    { path: '/profile', label: t('nav.profile') },
  ];

  return (
    <div className="app-layout">
      <header className="app-header">
        <NavLink to="/wardrobe" className="app-header__brand">
          StyleVault
        </NavLink>
        <nav className="app-header__nav">
          {links.map((link) => (
            <NavLink
              key={link.path}
              to={link.path}
              className={({ isActive }) =>
                `app-header__link ${isActive ? 'app-header__link--active' : ''}`
              }
            >
              {link.icon && <Icon name={link.icon} size={14} />}
              {link.label}
            </NavLink>
          ))}
        </nav>
      </header>

      <main className="app-layout__content">
        <Outlet />
      </main>

      <BottomNav />
    </div>
  );
}
