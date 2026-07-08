import { useState, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useAuth } from '../../context/AuthContext';
import { useProfile } from '../../context/ProfileContext';
import { useSettings } from '../../context/SettingsContext';
import { useWardrobe } from '../../context/WardrobeContext';
import AvatarSvg from '../../components/Avatar/AvatarSvg';
import AvatarEditor from '../../components/Avatar/AvatarEditor';
import CitySearch from '../../components/CitySearch/CitySearch';
import LanguageSwitch from '../../components/LanguageSwitch/LanguageSwitch';
import { Button, Modal, Icon } from '../../components/common';
import { CLOTHING_COLORS } from '../../utils/categories';
import { getGeminiKey, setGeminiKey } from '../../services/geminiTryon';
import {
  getMostWorn,
  getLeastWorn,
  getCategoryBreakdown,
  getColorBreakdown,
  getCostPerWear,
} from '../../utils/statistics';
import './ProfilePage.css';

export default function ProfilePage() {
  const { t } = useTranslation();
  const navigate = useNavigate();
  const { user, logout } = useAuth();
  const {
    avatarConfig,
    setAvatarConfig,
    referencePhoto,
    setReferencePhoto,
  } = useProfile();
  const { defaultCity, setDefaultCity } = useSettings();
  const { items, savedOutfits, outfitHistory } = useWardrobe();

  const [avatarOpen, setAvatarOpen] = useState(false);
  const [keyInput, setKeyInput] = useState('');
  const [keySaved, setKeySaved] = useState(() => Boolean(getGeminiKey()));

  const saveKey = () => {
    if (!keyInput.trim()) return;
    setGeminiKey(keyInput);
    setKeyInput('');
    setKeySaved(true);
  };

  const removeKey = () => {
    setGeminiKey('');
    setKeySaved(false);
  };

  const wornCount = outfitHistory.filter((l) => l.worn !== false).length;
  const favCount = items.filter((i) => i.favorite).length;

  const stats = useMemo(
    () => ({
      mostWorn: getMostWorn(items, outfitHistory, 5),
      leastWorn: getLeastWorn(items, outfitHistory, 5),
      byCategory: getCategoryBreakdown(items),
      byColor: getColorBreakdown(items).slice(0, 8),
      costPerWear: getCostPerWear(items, outfitHistory, 5),
    }),
    [items, outfitHistory]
  );

  const hasWearData = wornCount > 0;
  const colorHex = (id) => CLOTHING_COLORS.find((c) => c.id === id)?.hex || '#ccc';
  const maxCategoryCount = stats.byCategory[0]?.count || 1;

  return (
    <div className="sv-page profile-page">
      {/* Intestazione con avatar */}
      <header className="profile-page__head">
        <button className="profile-page__avatar" onClick={() => setAvatarOpen(true)}>
          <AvatarSvg config={avatarConfig} height={130} />
          <span className="profile-page__avatar-edit">
            <Icon name="edit" size={12} /> {t('profile.editAvatar')}
          </span>
        </button>
        <div>
          <h1 className="profile-page__name">{user?.name}</h1>
          <p className="profile-page__email">{user?.email}</p>
        </div>
      </header>

      {/* Numeri chiave */}
      <div className="profile-page__counters">
        <div className="profile-page__counter sv-card">
          <strong>{items.length}</strong>
          <span className="sv-label">{t('profile.totalItems')}</span>
        </div>
        <div className="profile-page__counter sv-card">
          <strong>{wornCount}</strong>
          <span className="sv-label">{t('profile.totalOutfits')}</span>
        </div>
        <div className="profile-page__counter sv-card">
          <strong>{favCount}</strong>
          <span className="sv-label">{t('profile.favoriteItems')}</span>
        </div>
      </div>

      {/* Impostazioni */}
      <section className="profile-page__section">
        <h2 className="sv-label">{t('profile.settings')}</h2>
        <div className="profile-page__setting">
          <span>{t('profile.defaultCity')}</span>
          <div className="profile-page__setting-control">
            <CitySearch value={defaultCity} onSelect={setDefaultCity} compact />
          </div>
        </div>
        <div className="profile-page__setting">
          <span>{t('profile.language')}</span>
          <LanguageSwitch />
        </div>
      </section>

      {/* Try-on fotografico: chiave API Gemini, solo su questo browser */}
      <section className="profile-page__section">
        <h2 className="sv-label">{t('profile.aiSection')}</h2>
        <p className="profile-page__ai-help">
          {t('profile.aiKeyHelp')}{' '}
          <a
            href="https://aistudio.google.com/apikey"
            target="_blank"
            rel="noreferrer"
            className="profile-page__ai-link"
          >
            aistudio.google.com/apikey <Icon name="external" size={11} />
          </a>
        </p>
        {keySaved ? (
          <div className="profile-page__ai-row">
            <span className="profile-page__ai-saved">
              <Icon name="check" size={14} /> {t('profile.aiKeySaved')}
            </span>
            <Button variant="secondary" size="sm" onClick={removeKey}>
              {t('profile.aiKeyRemove')}
            </Button>
          </div>
        ) : (
          <div className="profile-page__ai-row">
            <input
              type="password"
              className="profile-page__ai-input"
              placeholder={t('profile.aiKeyPlaceholder')}
              aria-label={t('profile.aiKeyLabel')}
              value={keyInput}
              onChange={(e) => setKeyInput(e.target.value)}
            />
            <Button size="sm" onClick={saveKey} disabled={!keyInput.trim()}>
              {t('profile.aiKeySave')}
            </Button>
          </div>
        )}
      </section>

      {/* Statistiche */}
      <section className="profile-page__section">
        <h2 className="sv-label">{t('profile.stats')}</h2>

        {!hasWearData && items.length === 0 ? (
          <p className="profile-page__no-stats">{t('profile.statsNoData')}</p>
        ) : (
          <>
            {stats.byCategory.length > 0 && (
              <div className="profile-page__stat-block">
                <h3>{t('profile.statsByCategory')}</h3>
                {stats.byCategory.map(({ category, count }) => (
                  <div key={category} className="profile-page__bar-row">
                    <span className="profile-page__bar-label">
                      {t(`categories.${category}`)}
                    </span>
                    <div className="profile-page__bar">
                      <i style={{ width: `${(count / maxCategoryCount) * 100}%` }} />
                    </div>
                    <span className="profile-page__bar-count">{count}</span>
                  </div>
                ))}
              </div>
            )}

            {stats.byColor.length > 0 && (
              <div className="profile-page__stat-block">
                <h3>{t('profile.statsByColor')}</h3>
                <div className="profile-page__color-row">
                  {stats.byColor.map(({ color, count }) => (
                    <span key={color} className="profile-page__color-chip">
                      <i style={{ backgroundColor: colorHex(color) }} />
                      {t(`colors.${color}`)} · {count}
                    </span>
                  ))}
                </div>
              </div>
            )}

            {hasWearData ? (
              <>
                {stats.mostWorn.length > 0 && (
                  <div className="profile-page__stat-block">
                    <h3>{t('profile.statsMostWorn')}</h3>
                    <ul className="profile-page__item-list">
                      {stats.mostWorn.map(({ item, count }) => (
                        <li key={item.id} onClick={() => navigate(`/wardrobe/${item.id}`)}>
                          <img src={item.photo} alt={item.name} />
                          <span>{item.name}</span>
                          <em>{t('profile.statsWears', { count })}</em>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}

                {stats.leastWorn.length > 0 && (
                  <div className="profile-page__stat-block">
                    <h3>{t('profile.statsLeastWorn')}</h3>
                    <ul className="profile-page__item-list">
                      {stats.leastWorn.map(({ item, count }) => (
                        <li key={item.id} onClick={() => navigate(`/wardrobe/${item.id}`)}>
                          <img src={item.photo} alt={item.name} />
                          <span>{item.name}</span>
                          <em>
                            {count === 0
                              ? t('profile.statsNever')
                              : t('profile.statsWears', { count })}
                          </em>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}

                {stats.costPerWear.length > 0 && (
                  <div className="profile-page__stat-block">
                    <h3>{t('profile.statsCostPerWear')}</h3>
                    <ul className="profile-page__item-list">
                      {stats.costPerWear.map(({ item, costPerWear, count }) => (
                        <li key={item.id} onClick={() => navigate(`/wardrobe/${item.id}`)}>
                          <img src={item.photo} alt={item.name} />
                          <span>{item.name}</span>
                          <em>
                            € {costPerWear.toFixed(2)} ·{' '}
                            {t('profile.statsWears', { count })}
                          </em>
                        </li>
                      ))}
                    </ul>
                  </div>
                )}
              </>
            ) : (
              <p className="profile-page__no-stats">{t('profile.statsNoData')}</p>
            )}
          </>
        )}
      </section>

      <div className="profile-page__footer">
        <p className="sv-label">
          {t('profile.version')} 0.1 · {savedOutfits.length} outfit
        </p>
        <Button variant="danger" icon={<Icon name="logout" size={15} />} onClick={logout}>
          {t('auth.logout')}
        </Button>
      </div>

      {/* Editor avatar */}
      <Modal
        isOpen={avatarOpen}
        onClose={() => setAvatarOpen(false)}
        title={t('avatar.title')}
        footer={
          <Button onClick={() => setAvatarOpen(false)}>{t('common.done')}</Button>
        }
      >
        <AvatarEditor
          config={avatarConfig}
          onChange={setAvatarConfig}
          referencePhoto={referencePhoto}
          onReferencePhotoChange={setReferencePhoto}
        />
      </Modal>
    </div>
  );
}
