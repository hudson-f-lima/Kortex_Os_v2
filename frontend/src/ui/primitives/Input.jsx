import React from 'react';
import './Input.css';

export function Input({ 
  label, 
  error, 
  helperText, 
  leftIcon, 
  rightIcon, 
  className = '', 
  id, 
  ...props 
}) {
  const inputId = id || React.useId();
  const isError = Boolean(error);
  
  return (
    <div className={`k-input-wrapper ${className}`}>
      {label && (
        <label htmlFor={inputId} className="k-input__label text-label">
          {label}
        </label>
      )}
      <div className="k-input__container">
        {leftIcon && <span className="k-input__icon k-input__icon--left">{leftIcon}</span>}
        <input 
          id={inputId}
          className={`k-input ${leftIcon ? 'k-input--with-left-icon' : ''} ${rightIcon ? 'k-input--with-right-icon' : ''} ${isError ? 'k-input--error' : ''}`}
          aria-invalid={isError}
          aria-describedby={
            isError ? `${inputId}-error` : helperText ? `${inputId}-helper` : undefined
          }
          {...props}
        />
        {rightIcon && <span className="k-input__icon k-input__icon--right">{rightIcon}</span>}
      </div>
      {isError && (
        <span id={`${inputId}-error`} className="k-input__message k-input__message--error text-supporting">
          {error}
        </span>
      )}
      {!isError && helperText && (
        <span id={`${inputId}-helper`} className="k-input__message text-supporting">
          {helperText}
        </span>
      )}
    </div>
  );
}
