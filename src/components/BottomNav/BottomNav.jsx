import { NavLink } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import Icon from '../common/Icon';
import './BottomNav.css';

export default function BottomNav() {
  const { t } = useTranslation();

  const tabs = [
    { path: '/wardrobe', icon: 'wardrobe', label: t('nav.wardrobe') },
    { path: '/outfit', icon: 'sparkle', label: t('nav.outfit') },
    { path: '/add', icon: 'plus', label: t('nav.add'), isCenter: true },
    { path: '/calendar', icon: 'calendar', label: t('nav.calendar') },
    { path: '/profile', icon: 'user', label: t('nav.profile') },
  ];

  return (
    <nav className="bottom-nav">
      {tabs.map((tab) => (
        <NavLink
          key={tab.path}
          to={tab.path}
          className={({ isActive }) =>
            `bottom-nav__tab ${isActive ? 'bottom-nav__tab--active' : ''} ${tab.isCenter ? 'bottom-nav__tab--center' : ''}`
          }
        >
          <span className={`bottom-nav__icon ${tab.isCenter ? 'bottom-nav__icon--center' : ''}`}>
            <Icon name={tab.icon} size={tab.isCenter ? 22 : 21} />
          </span>
          {!tab.isCenter && <span className="bottom-nav__label">{tab.label}</span>}
        </NavLink>
      ))}
    </nav>
  );
}
