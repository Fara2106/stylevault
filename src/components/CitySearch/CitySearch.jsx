import { useState, useEffect, useRef } from 'react';
import { useTranslation } from 'react-i18next';
import Icon from '../common/Icon';
import { searchCities } from '../../services/weather';
import './CitySearch.css';

/**
 * Ricerca città con geocoding Open-Meteo (debounce 350ms).
 * value: città selezionata {name, latitude, longitude, country?, region?}
 * onSelect(city): callback alla scelta.
 */
export default function CitySearch({ value, onSelect, compact = false }) {
  const { t, i18n } = useTranslation();
  const [query, setQuery] = useState('');
  const [results, setResults] = useState([]);
  const [open, setOpen] = useState(false);
  const [searching, setSearching] = useState(false);
  const [noResults, setNoResults] = useState(false);
  const boxRef = useRef(null);

  // Chiudi il dropdown cliccando fuori
  useEffect(() => {
    const onClickOutside = (e) => {
      if (boxRef.current && !boxRef.current.contains(e.target)) setOpen(false);
    };
    document.addEventListener('mousedown', onClickOutside);
    return () => document.removeEventListener('mousedown', onClickOutside);
  }, []);

  // Ricerca con debounce
  useEffect(() => {
    if (query.trim().length < 2) {
      setResults([]);
      setNoResults(false);
      return;
    }
    setSearching(true);
    const timer = setTimeout(async () => {
      try {
        const cities = await searchCities(query.trim(), i18n.language);
        setResults(cities);
        setNoResults(cities.length === 0);
        setOpen(true);
      } catch {
        setResults([]);
        setNoResults(true);
      } finally {
        setSearching(false);
      }
    }, 350);
    return () => clearTimeout(timer);
  }, [query, i18n.language]);

  const pick = (city) => {
    onSelect(city);
    setQuery('');
    setResults([]);
    setOpen(false);
  };

  return (
    <div className={`city-search ${compact ? 'city-search--compact' : ''}`} ref={boxRef}>
      <div className="city-search__field">
        <Icon name="mapPin" size={16} />
        <input
          type="text"
          value={query}
          placeholder={value?.name || t('outfit.searchCity')}
          onChange={(e) => setQuery(e.target.value)}
          onFocus={() => results.length > 0 && setOpen(true)}
        />
        {searching && <span className="city-search__spinner" />}
      </div>

      {open && (results.length > 0 || noResults) && (
        <ul className="city-search__results sv-card">
          {results.map((city) => (
            <li key={city.id}>
              <button onClick={() => pick(city)}>
                <strong>{city.name}</strong>
                <span>
                  {[city.region, city.country].filter(Boolean).join(', ')}
                </span>
              </button>
            </li>
          ))}
          {noResults && (
            <li className="city-search__empty">{t('outfit.cityNotFound')}</li>
          )}
        </ul>
      )}
    </div>
  );
}
