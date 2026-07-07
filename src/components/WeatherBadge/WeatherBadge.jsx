import { useTranslation } from 'react-i18next';
import './WeatherBadge.css';

export default function WeatherBadge({ weather }) {
  const { t } = useTranslation();
  if (!weather) return null;

  const getTempGradient = (temp) => {
    if (temp <= 5) return 'linear-gradient(135deg, #B8D4E3 0%, #9FC5E8 100%)';
    if (temp <= 15) return 'linear-gradient(135deg, #B8E3D4 0%, #A8D5BA 100%)';
    if (temp <= 25) return 'linear-gradient(135deg, #F5D89A 0%, #F0C27F 100%)';
    return 'linear-gradient(135deg, #F2C6C2 0%, #E8A0A0 100%)';
  };

  return (
    <div className="weather-badge" style={{ background: getTempGradient(weather.temperature) }}>
      <div className="weather-badge__main">
        <span className="weather-badge__icon">{weather.icon}</span>
        <span className="weather-badge__temp">{weather.temperature}°</span>
        <div className="weather-badge__info">
          <span className="weather-badge__city">{weather.city}</span>
          <span className="weather-badge__desc">{weather.description}</span>
        </div>
      </div>
      <div className="weather-badge__details">
        <span className="weather-badge__chip">💧 {weather.humidity}%</span>
        <span className="weather-badge__chip">💨 {weather.windSpeed} km/h</span>
        {weather.uvIndex > 0 && <span className="weather-badge__chip">☀️ UV {weather.uvIndex}</span>}
      </div>
    </div>
  );
}
