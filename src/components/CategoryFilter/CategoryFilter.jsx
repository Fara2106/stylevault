import { useTranslation } from 'react-i18next';
import './CategoryFilter.css';

export default function CategoryFilter({ categories, activeCategory, onChange }) {
  const { t } = useTranslation();

  return (
    <div className="category-filter">
      <button
        className={`category-filter__chip ${activeCategory === 'all' ? 'category-filter__chip--active' : ''}`}
        onClick={() => onChange('all')}
      >
        {t('common.all')}
      </button>
      {categories.map(cat => (
        <button
          key={cat.id}
          className={`category-filter__chip ${activeCategory === cat.id ? 'category-filter__chip--active' : ''}`}
          onClick={() => onChange(cat.id)}
        >
          <span className="category-filter__icon">{cat.icon}</span>
          {t(cat.labelKey)}
        </button>
      ))}
    </div>
  );
}
