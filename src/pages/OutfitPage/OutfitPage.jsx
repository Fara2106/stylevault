import { useState, useEffect, useMemo, useCallback } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useWardrobe } from '../../context/WardrobeContext';
import { useSettings } from '../../context/SettingsContext';
import WeatherBadge from '../../components/WeatherBadge/WeatherBadge';
import OutfitCard from '../../components/OutfitCard/OutfitCard';
import CitySearch from '../../components/CitySearch/CitySearch';
import { Button, Icon } from '../../components/common';
import { fetchForecastWithCache } from '../../services/weather';
import { generateOutfits } from '../../utils/outfitAlgorithm';
import { getOutfitAdvice } from '../../utils/outfitAdvice';
import { OCCASIONS } from '../../utils/categories';
import './OutfitPage.css';

const FALLBACK_CITY = { name: 'Milano', latitude: 45.4642, longitude: 9.19 };

const todayISO = () => new Date().toISOString().split('T')[0];

const addDaysISO = (n) => {
  const d = new Date();
  d.setDate(d.getDate() + n);
  return d.toISOString().split('T')[0];
};

const outfitItems = (outfit) =>
  [outfit.top, outfit.bottom, outfit.shoes, outfit.outerwear, ...(outfit.accessories || [])]
    .filter(Boolean);

export default function OutfitPage() {
  const { t, i18n } = useTranslation();
  const navigate = useNavigate();
  const { items, outfitHistory, saveOutfit, savedOutfits, logOutfit } = useWardrobe();
  const { defaultCity } = useSettings();

  const initialCity =
    defaultCity && typeof defaultCity === 'object' && defaultCity.latitude != null
      ? defaultCity
      : FALLBACK_CITY;

  const [city, setCity] = useState(initialCity);
  const [forecast, setForecast] = useState(null); // {days, stale, fetchedAt}
  const [weatherError, setWeatherError] = useState(false);
  const [manual, setManual] = useState({ temperature: 20, rain: false });
  const [dayIndex, setDayIndex] = useState(0);
  const [occasion, setOccasion] = useState('all');
  const [outfits, setOutfits] = useState([]);
  const [lockedIds, setLockedIds] = useState([]);
  const [savedFlags, setSavedFlags] = useState({});
  const [wornMsg, setWornMsg] = useState('');

  // Previsione al cambio città
  useEffect(() => {
    let alive = true;
    setWeatherError(false);
    setForecast(null);
    fetchForecastWithCache(city)
      .then((result) => alive && setForecast(result))
      .catch(() => alive && setWeatherError(true));
    return () => {
      alive = false;
    };
  }, [city]);

  // Meteo del giorno selezionato (reale o manuale)
  const dayWeather = useMemo(() => {
    if (forecast?.days?.[dayIndex]) return forecast.days[dayIndex];
    if (weatherError) {
      return {
        city: city.name,
        date: addDaysISO(dayIndex),
        temperature: Number(manual.temperature),
        tMin: null,
        tMax: null,
        windSpeed: 0,
        uvIndex: 0,
        precipProb: null,
        rain: manual.rain,
        snow: false,
        icon: manual.rain ? 'rain' : 'sun',
        descriptionKey: manual.rain ? 'weather.rainy' : 'weather.clear',
      };
    }
    return null;
  }, [forecast, dayIndex, weatherError, manual, city.name]);

  // Storico "indossato" per penalità ripetizione e consigli
  const recentWear = useMemo(
    () =>
      outfitHistory
        .filter((log) => log.worn !== false)
        .flatMap((log) =>
          outfitItems(log.outfit).map((item) => ({ itemId: item.id, date: log.date }))
        ),
    [outfitHistory]
  );

  const lockedItems = useMemo(
    () => items.filter((i) => lockedIds.includes(i.id)),
    [items, lockedIds]
  );

  const generate = useCallback(() => {
    if (!dayWeather) return;
    const generated = generateOutfits(items, dayWeather, occasion, 3, {
      lockedItems,
      recentWear,
      referenceDate: dayWeather.date,
    });
    setOutfits(generated);
    setSavedFlags({});
    setWornMsg('');
  }, [items, dayWeather, occasion, lockedItems, recentWear]);

  // Prima generazione automatica quando il meteo è pronto
  useEffect(() => {
    if (dayWeather && outfits.length === 0 && items.length > 0) generate();
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [dayWeather]);

  const toggleLock = (itemId) => {
    setLockedIds((prev) =>
      prev.includes(itemId) ? prev.filter((id) => id !== itemId) : [...prev, itemId]
    );
  };

  const handleSave = (outfit) => {
    saveOutfit({ ...outfit, occasion });
    setSavedFlags((prev) => ({ ...prev, [outfit.id]: true }));
  };

  const handleWear = (outfit) => {
    const date = dayWeather?.date || todayISO();
    logOutfit(outfit, date, { worn: date <= todayISO() });
    setWornMsg(t('outfit.wornToday', { date }));
  };

  const handleTryOn = (outfit) => {
    navigate('/tryon', { state: { outfit } });
  };

  // Etichette dei giorni (Oggi, Domani, poi giorno della settimana)
  const dayLabels = useMemo(() => {
    const fmt = new Intl.DateTimeFormat(i18n.language, {
      weekday: 'short',
      day: 'numeric',
    });
    return Array.from({ length: 7 }, (_, i) => {
      if (i === 0) return t('outfit.today');
      if (i === 1) return t('outfit.tomorrow');
      const d = new Date();
      d.setDate(d.getDate() + i);
      return fmt.format(d);
    });
  }, [i18n.language, t]);

  return (
    <div className="sv-page outfit-page">
      <header className="outfit-page__head">
        <h1 className="outfit-page__title">{t('outfit.title')}</h1>
        <p className="outfit-page__subtitle">{t('outfit.subtitle')}</p>
      </header>

      <div className="outfit-page__controls">
        <CitySearch value={city} onSelect={setCity} compact />

        <div className="outfit-page__days">
          {dayLabels.map((label, i) => (
            <button
              key={i}
              className={`outfit-page__day ${dayIndex === i ? 'outfit-page__day--active' : ''}`}
              onClick={() => {
                setDayIndex(i);
                setOutfits([]);
              }}
            >
              {label}
            </button>
          ))}
        </div>

        <div className="outfit-page__occasions">
          <button
            className={`outfit-page__day ${occasion === 'all' ? 'outfit-page__day--active' : ''}`}
            onClick={() => {
              setOccasion('all');
              setOutfits([]);
            }}
          >
            {t('common.all')}
          </button>
          {OCCASIONS.map((o) => (
            <button
              key={o.id}
              className={`outfit-page__day ${occasion === o.id ? 'outfit-page__day--active' : ''}`}
              onClick={() => {
                setOccasion(o.id);
                setOutfits([]);
              }}
            >
              {t(o.labelKey)}
            </button>
          ))}
        </div>
      </div>

      {/* Meteo */}
      {dayWeather && !weatherError && (
        <WeatherBadge
          weather={dayWeather}
          stale={forecast?.stale}
          staleTime={
            forecast?.fetchedAt
              ? new Date(forecast.fetchedAt).toLocaleTimeString(i18n.language, {
                  hour: '2-digit',
                  minute: '2-digit',
                })
              : ''
          }
        />
      )}
      {weatherError && (
        <div className="outfit-page__manual sv-card">
          <p className="outfit-page__manual-title">{t('outfit.manualWeather')}</p>
          <div className="outfit-page__manual-row">
            <label>
              <span className="sv-label">{t('outfit.manualTemp')}</span>
              <input
                type="number"
                value={manual.temperature}
                onChange={(e) =>
                  setManual((m) => ({ ...m, temperature: e.target.value }))
                }
              />
            </label>
            <label className="outfit-page__manual-rain">
              <input
                type="checkbox"
                checked={manual.rain}
                onChange={(e) => setManual((m) => ({ ...m, rain: e.target.checked }))}
              />
              <span>{t('outfit.manualRain')}</span>
            </label>
          </div>
        </div>
      )}
      {!dayWeather && !weatherError && (
        <p className="outfit-page__loading">{t('common.loading')}</p>
      )}

      {/* Generazione */}
      <div className="outfit-page__generate">
        <Button
          size="lg"
          fullWidth
          icon={<Icon name="sparkle" size={16} />}
          onClick={generate}
          disabled={!dayWeather || items.length === 0}
        >
          {outfits.length > 0 ? t('outfit.regenerate') : t('outfit.generateOutfit')}
        </Button>
        {lockedIds.length > 0 && (
          <p className="outfit-page__lock-hint">
            <Icon name="lock" size={12} /> {t('outfit.regenerateHint')}
          </p>
        )}
        {wornMsg && <p className="outfit-page__worn-msg">{wornMsg}</p>}
      </div>

      {/* Risultati */}
      {outfits.length === 0 && items.length > 0 && dayWeather && (
        <div className="sv-empty">
          <p className="sv-empty__title">{t('outfit.noOutfits')}</p>
          <p>{t('outfit.noItemsForOutfit')}</p>
        </div>
      )}
      {items.length === 0 && (
        <div className="sv-empty">
          <p className="sv-empty__title">{t('wardrobe.emptyState')}</p>
          <Button onClick={() => navigate('/add')}>{t('wardrobe.emptyAction')}</Button>
        </div>
      )}

      <div className="outfit-page__results">
        {outfits.map((outfit) => {
          const advice = dayWeather
            ? getOutfitAdvice(outfit, dayWeather, { recentWear, occasion })
            : [];
          return (
            <div key={outfit.id} className="outfit-page__result">
              <OutfitCard
                outfit={outfit}
                lockedIds={lockedIds}
                onToggleLock={toggleLock}
                onSave={handleSave}
                onWear={handleWear}
                onTryOn={handleTryOn}
                saved={!!savedFlags[outfit.id]}
              />
              {advice.length > 0 && (
                <div className="outfit-page__advice">
                  <span className="sv-label">{t('outfit.adviceTitle')}</span>
                  <ul>
                    {advice.slice(0, 4).map((a, i) => (
                      <li key={i}>{t(a.key, a.params)}</li>
                    ))}
                  </ul>
                </div>
              )}
            </div>
          );
        })}
      </div>

      {savedOutfits.length > 0 && (
        <p className="outfit-page__saved-count sv-label">
          {t('profile.totalOutfits')}: {savedOutfits.length}
        </p>
      )}
    </div>
  );
}
