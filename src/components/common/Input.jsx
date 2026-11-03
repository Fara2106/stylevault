import { useId, useState } from 'react';
import './Input.css';

/**
 * Campo con etichetta flottante. Le prop extra (autoComplete, inputMode,
 * enterKeyHint…) arrivano al campo: su iPhone servono per l'autocompilazione
 * del Portachiavi / Face ID e per la tastiera giusta.
 */
export default function Input({ label, value, onChange, type = 'text', error, icon, placeholder, disabled, name, required, ...rest }) {
  const [focused, setFocused] = useState(false);
  const fieldId = useId();
  // String(): il prezzo di un capo in modifica arriva come numero (49), e
  // 49.length non esiste → l'etichetta restava sopra il valore.
  const hasValue = value != null && String(value).length > 0;
  const isTextarea = type === 'textarea';
  const Component = isTextarea ? 'textarea' : 'input';

  return (
    <div className={`input-group ${focused ? 'input-group--focused' : ''} ${hasValue ? 'input-group--filled' : ''} ${error ? 'input-group--error' : ''} ${disabled ? 'input-group--disabled' : ''}`}>
      {icon && <span className="input-group__icon">{icon}</span>}
      <Component
        {...rest}
        id={fieldId}
        className={`input-group__field ${icon ? 'input-group__field--with-icon' : ''}`}
        type={isTextarea ? undefined : type}
        value={value}
        onChange={onChange}
        onFocus={() => setFocused(true)}
        onBlur={() => setFocused(false)}
        placeholder={focused ? placeholder : ' '}
        disabled={disabled}
        name={name}
        required={required}
        rows={isTextarea ? 4 : undefined}
      />
      {label && <label htmlFor={fieldId} className={`input-group__label ${icon ? 'input-group__label--with-icon' : ''}`}>{label}{required && ' *'}</label>}
      {error && <span className="input-group__error">{error}</span>}
    </div>
  );
}
