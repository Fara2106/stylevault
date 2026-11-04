import { useTranslation } from 'react-i18next';
import Icon from '../common/Icon';
import './DayStrip.css';

/**
 * La giornata in tre fasce (mattina, pomeriggio, sera) sotto la scheda meteo.
 * parts: [{key, temperature, icon, precipProb, past}] da parseForecastPayload;
 * senza dati orari non mostra niente.
 */
export default function DayStrip({ parts }) {
  const { t } = useTranslation();
  if (!parts?.length || parts.every((p) => p.temperature == null)) return null;

  return (
    <div className="day-strip sv-card">
      {parts.map((part) => (
        <div
          key={part.key}
          className={`day-strip__part ${part.past ? 'day-strip__part--past' : ''}`}
        >
          <span className="sv-label">{t(`weather.partTitle.${part.key}`)}</span>
          <Icon name={part.icon || 'cloud'} size={20} strokeWidth={1.3} />
          <span className="day-strip__temp">
            {part.temperature != null ? `${Math.round(part.temperature)}°` : '–'}
          </span>
          {part.precipProb > 0 && (
            <span className="day-strip__rain">
              <Icon name="droplet" size={11} /> {part.precipProb}%
            </span>
          )}
        </div>
      ))}
    </div>
  );
}
