import React from 'react';
import './Select.css';

export function Select({ 
  label, 
  error, 
  helperText, 
  className = '', 
  id, 
  children,
  ...props 
}) {
  const selectId = id || React.useId();
  const isError = Boolean(error);
  
  return (
    <div className={`k-select-wrapper ${className}`}>
      {label && (
        <label htmlFor={selectId} className="k-select__label text-label">
          {label}
        </label>
      )}
      <div className="k-select__container">
        <select 
          id={selectId}
          className={`k-select ${isError ? 'k-select--error' : ''}`}
          aria-invalid={isError}
          aria-describedby={
            isError ? `${selectId}-error` : helperText ? `${selectId}-helper` : undefined
          }
          {...props}
        >
          {children}
        </select>
        <span className="k-select__chevron" aria-hidden="true">
          <svg width="24" height="24" viewBox="0 0 24 24" fill="none" stroke="currentColor" strokeWidth="2" strokeLinecap="round" strokeLinejoin="round">
            <polyline points="6 9 12 15 18 9"></polyline>
          </svg>
        </span>
      </div>
      {isError && (
        <span id={`${selectId}-error`} className="k-select__message k-select__message--error text-supporting">
          {error}
        </span>
      )}
      {!isError && helperText && (
        <span id={`${selectId}-helper`} className="k-select__message text-supporting">
          {helperText}
        </span>
      )}
    </div>
  );
}
