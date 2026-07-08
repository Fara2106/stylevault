import { useState, useEffect, useMemo } from 'react';
import { useNavigate } from 'react-router-dom';
import { useTranslation } from 'react-i18next';
import { useWardrobe } from '../../context/WardrobeContext';
import { useSettings } from '../../context/SettingsContext';
import { Button, Modal, Icon } from '../../components/common';
import { fetchForecastWithCache } from '../../services/weather';
import './CalendarPage.css';

const toISO = (d) => {
  const pad = (n) => String(n).padStart(2, '0');
  return `${d.getFullYear()}-${pad(d.getMonth() + 1)}-${pad(d.getDate())}`;
};

const todayISO = () => toISO(new Date());

const outfitItems = (outfit) =>
  [outfit.top, outfit.bottom, outfit.shoes, outfit.outerwear, ...(outfit.accessories || [])]
    .filter(Boolean);

/** Matrice del mese: settimane che iniziano il lunedì. */
function monthMatrix(year, month) {
  const first = new Date(year, month, 1);
  const startOffset = (first.getDay() + 6) % 7; // lun=0
  const daysInMonth = new Date(year, month + 1, 0).getDate();
  const cells = [];
  for (let i = 0; i < startOffset; i++) cells.push(null);
  for (let d = 1; d <= daysInMonth; d++) cells.push(new Date(year, month, d));
  while (cells.length % 7 !== 0) cells.push(null);
  const weeks = [];
  for (let i = 0; i < cells.length; i += 7) weeks.push(cells.slice(i, i + 7));
  return weeks;
}

export default function CalendarPage() {
  const { t, i18n } = useTranslation();
  const navigate = useNavigate();
  const { outfitHistory, savedOutfits, logOutfit, updateOutfitLog, removeOutfitLog } =
    useWardrobe();
  const { defaultCity } = useSettings();

  const now = new Date();
  const [year, setYear] = useState(now.getFullYear());
  const [month, setMonth] = useState(now.getMonth());
  const [selectedDate, setSelectedDate] = useState(todayISO());
  const [pickerOpen, setPickerOpen] = useState(false);
  const [forecastDays, setForecastDays] = useState([]);

  // Previsione per la città predefinita (per mostrare il meteo accanto ai giorni futuri)
  useEffect(() => {
    if (defaultCity?.latitude == null) return;
    fetchForecastWithCache(defaultCity)
      .then((r) => setForecastDays(r.days))
      .catch(() => setForecastDays([]));
  }, [defaultCity]);

  const entriesByDate = useMemo(() => {
    const map = new Map();
    for (const log of outfitHistory) {
      if (!map.has(log.date)) map.set(log.date, []);
      map.get(log.date).push(log);
    }
    return map;
  }, [outfitHistory]);

  const weeks = useMemo(() => monthMatrix(year, month), [year, month]);

  const monthLabel = new Intl.DateTimeFormat(i18n.language, {
    month: 'long',
    year: 'numeric',
  }).format(new Date(year, month, 1));

  const weekdayLabels = useMemo(() => {
    const fmt = new Intl.DateTimeFormat(i18n.language, { weekday: 'narrow' });
    // 2026-01-05 è un lunedì
    return Array.from({ length: 7 }, (_, i) => fmt.format(new Date(2026, 0, 5 + i)));
  }, [i18n.language]);

  const changeMonth = (delta) => {
    const d = new Date(year, month + delta, 1);
    setYear(d.getFullYear());
    setMonth(d.getMonth());
  };

  const dayEntries = entriesByDate.get(selectedDate) || [];
  const dayForecast = forecastDays.find((d) => d.date === selectedDate);

  /** Avviso ripetizione: stesso capo indossato nei 7 giorni precedenti la data. */
  const repeatWarningFor = (entry) => {
    const ids = new Set(outfitItems(entry.outfit).map((i) => i.id));
    const ref = new Date(selectedDate);
    const hit = outfitHistory
      .filter((log) => log.id !== entry.id && log.date !== selectedDate)
      .filter((log) => {
        const diff = (ref - new Date(log.date)) / 86400000;
        return diff > 0 && diff <= 7;
      })
      .find((log) => outfitItems(log.outfit).some((i) => ids.has(i.id)));
    return hit ? hit.date : null;
  };

  const assignOutfit = (outfit) => {
    logOutfit(outfit, selectedDate, { worn: selectedDate <= todayISO() });
    setPickerOpen(false);
  };

  return (
    <div className="sv-page calendar-page">
      <header className="calendar-page__head">
        <h1 className="calendar-page__title">{t('calendar.title')}</h1>
        <p className="calendar-page__subtitle">{t('calendar.subtitle')}</p>
      </header>

      <div className="calendar-page__month sv-card">
        <div className="calendar-page__month-nav">
          <button onClick={() => changeMonth(-1)} aria-label="prev">
            <Icon name="back" size={16} />
          </button>
          <span className="calendar-page__month-label">{monthLabel}</span>
          <button
            onClick={() => changeMonth(1)}
            aria-label="next"
            className="calendar-page__next"
          >
            <Icon name="back" size={16} />
          </button>
        </div>

        <div className="calendar-page__grid">
          {weekdayLabels.map((w, i) => (
            <span key={`w${i}`} className="calendar-page__weekday sv-label">
              {w}
            </span>
          ))}
          {weeks.flat().map((date, i) => {
            if (!date) return <span key={i} />;
            const iso = toISO(date);
            const entries = entriesByDate.get(iso) || [];
            const isToday = iso === todayISO();
            const isSelected = iso === selectedDate;
            return (
              <button
                key={i}
                className={`calendar-page__day ${isSelected ? 'calendar-page__day--selected' : ''} ${isToday ? 'calendar-page__day--today' : ''}`}
                onClick={() => setSelectedDate(iso)}
              >
                {date.getDate()}
                {entries.length > 0 && (
                  <span
                    className={`calendar-page__dot ${entries.some((e) => e.worn !== false) ? 'calendar-page__dot--worn' : ''}`}
                  />
                )}
              </button>
            );
          })}
        </div>
      </div>

      {/* Dettaglio giorno */}
      <section className="calendar-page__detail">
        <div className="calendar-page__detail-head">
          <h2 className="calendar-page__detail-title">
            {new Intl.DateTimeFormat(i18n.language, {
              weekday: 'long',
              day: 'numeric',
              month: 'long',
            }).format(new Date(selectedDate))}
          </h2>
          {dayForecast && (
            <span className="calendar-page__forecast">
              <Icon name={dayForecast.icon} size={15} />
              {Math.round(dayForecast.tMin)}° / {Math.round(dayForecast.tMax)}°
            </span>
          )}
        </div>

        {dayEntries.length === 0 ? (
          <p className="calendar-page__empty">{t('calendar.noOutfit')}</p>
        ) : (
          dayEntries.map((entry) => {
            const repeatDate = repeatWarningFor(entry);
            return (
              <div key={entry.id} className="calendar-page__entry sv-card">
                <div className="calendar-page__entry-status">
                  <span
                    className={`calendar-page__badge ${entry.worn !== false ? 'calendar-page__badge--worn' : ''}`}
                  >
                    {entry.worn !== false ? t('calendar.worn') : t('calendar.planned')}
                  </span>
                  {repeatDate && (
                    <span className="calendar-page__warning">
                      {t('calendar.repeatWarning', { date: repeatDate })}
                    </span>
                  )}
                </div>

                <div className="calendar-page__entry-items">
                  {outfitItems(entry.outfit).map((item) => (
                    <img key={item.id} src={item.photo} alt={item.name} title={item.name} />
                  ))}
                </div>

                <div className="calendar-page__entry-actions">
                  {entry.worn === false && (
                    <button onClick={() => updateOutfitLog(entry.id, { worn: true })}>
                      <Icon name="check" size={13} /> {t('calendar.markWorn')}
                    </button>
                  )}
                  <button
                    onClick={() => navigate('/tryon', { state: { outfit: entry.outfit } })}
                  >
                    <Icon name="user" size={13} /> {t('outfit.tryOn')}
                  </button>
                  <button onClick={() => removeOutfitLog(entry.id)}>
                    <Icon name="trash" size={13} /> {t('calendar.removeEntry')}
                  </button>
                </div>
              </div>
            );
          })
        )}

        <Button
          variant="secondary"
          fullWidth
          icon={<Icon name="plus" size={15} />}
          onClick={() => setPickerOpen(true)}
        >
          {t('calendar.assignOutfit')}
        </Button>
      </section>

      {/* Scelta outfit salvato */}
      <Modal
        isOpen={pickerOpen}
        onClose={() => setPickerOpen(false)}
        title={t('calendar.pickOutfit')}
      >
        {savedOutfits.length === 0 ? (
          <p className="calendar-page__empty">{t('calendar.noSavedOutfits')}</p>
        ) : (
          <div className="calendar-page__picker">
            {savedOutfits.map((outfit) => (
              <button
                key={outfit.id}
                className="calendar-page__picker-item"
                onClick={() => assignOutfit(outfit)}
              >
                <div className="calendar-page__picker-thumbs">
                  {outfitItems(outfit)
                    .slice(0, 4)
                    .map((item) => (
                      <img key={item.id} src={item.photo} alt={item.name} />
                    ))}
                </div>
                <span className="sv-label">
                  {[
                    outfit.score != null ? `${t('outfit.outfitScore')} ${outfit.score}` : null,
                    outfit.occasion && outfit.occasion !== 'all'
                      ? t(`occasions.${outfit.occasion}`)
                      : null,
                  ]
                    .filter(Boolean)
                    .join(' · ') || t('calendar.customOutfit')}
                </span>
              </button>
            ))}
          </div>
        )}
      </Modal>
    </div>
  );
}
