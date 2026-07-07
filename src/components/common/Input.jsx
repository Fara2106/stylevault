import { useState } from 'react';
import './Input.css';

export default function Input({ label, value, onChange, type = 'text', error, icon, placeholder, disabled, name, required }) {
  const [focused, setFocused] = useState(false);
  const hasValue = value && value.length > 0;
  const isTextarea = type === 'textarea';
  const Component = isTextarea ? 'textarea' : 'input';

  return (
    <div className={`input-group ${focused ? 'input-group--focused' : ''} ${hasValue ? 'input-group--filled' : ''} ${error ? 'input-group--error' : ''} ${disabled ? 'input-group--disabled' : ''}`}>
      {icon && <span className="input-group__icon">{icon}</span>}
      <Component
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
      {label && <label className={`input-group__label ${icon ? 'input-group__label--with-icon' : ''}`}>{label}{required && ' *'}</label>}
      {error && <span className="input-group__error">{error}</span>}
    </div>
  );
}
