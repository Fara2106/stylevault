import { NavLink, useLocation } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import './BottomNav.css';

export default function BottomNav() {
  const { t } = useTranslation();
  const location = useLocation();

  const tabs = [
    { path: '/wardrobe', icon: '👗', label: t('nav.wardrobe') },
    { path: '/outfit', icon: '✨', label: t('nav.outfit') },
    { path: '/add', icon: '+', label: t('nav.add'), isCenter: true },
    { path: '/calendar', icon: '📅', label: t('nav.calendar') },
    { path: '/wishlist', icon: '💫', label: t('nav.wishlist') },
  ];

  return (
    <nav className="bottom-nav">
      {tabs.map(tab => (
        <NavLink
          key={tab.path}
          to={tab.path}
          className={({ isActive }) => `bottom-nav__tab ${isActive ? 'bottom-nav__tab--active' : ''} ${tab.isCenter ? 'bottom-nav__tab--center' : ''}`}
        >
          <span className={`bottom-nav__icon ${tab.isCenter ? 'bottom-nav__icon--center' : ''}`}>
            {tab.icon}
          </span>
          {!tab.isCenter && <span className="bottom-nav__label">{tab.label}</span>}
        </NavLink>
      ))}
    </nav>
  );
}
