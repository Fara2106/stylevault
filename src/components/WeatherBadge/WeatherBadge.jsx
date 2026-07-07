import { useTranslation } from 'react-i18next';
import Icon from '../common/Icon';
import './WeatherBadge.css';

/**
 * Scheda meteo del giorno selezionato.
 * weather: { city, tMin, tMax, temperature, windSpeed, humidity,
 *            precipProb, icon (nome Icon), descriptionKey }
 * stale: true se i dati vengono dalla cache (mostra l'avviso).
 */
export default function WeatherBadge({ weather, stale = false, staleTime = '' }) {
  const { t } = useTranslation();
  if (!weather) return null;

  const hasRange = weather.tMin != null && weather.tMax != null;

  return (
    <div className="weather-badge sv-card">
      <div className="weather-badge__main">
        <span className="weather-badge__icon">
          <Icon name={weather.icon || 'sun'} size={30} strokeWidth={1.2} />
        </span>
        <span className="weather-badge__temp">
          {Math.round(weather.temperature)}°
        </span>
        <div className="weather-badge__info">
          <span className="weather-badge__city">{weather.city}</span>
          <span className="weather-badge__desc">
            {weather.descriptionKey ? t(weather.descriptionKey) : weather.description}
          </span>
        </div>
      </div>
      <div className="weather-badge__details">
        {hasRange && (
          <span className="weather-badge__chip">
            {Math.round(weather.tMin)}° / {Math.round(weather.tMax)}°
          </span>
        )}
        {weather.precipProb != null && (
          <span className="weather-badge__chip">
            <Icon name="droplet" size={12} /> {weather.precipProb}%
          </span>
        )}
        {weather.windSpeed != null && (
          <span className="weather-badge__chip">
            <Icon name="wind" size={12} /> {Math.round(weather.windSpeed)} km/h
          </span>
        )}
      </div>
      {stale && (
        <p className="weather-badge__stale">{t('weather.staleNotice', { time: staleTime })}</p>
      )}
    </div>
  );
}
