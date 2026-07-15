export function validateCapability(data) {
  const errors = {};

  if (!data.professional_id) {
    errors.professional_id = 'Professional ID is required';
  } else if (typeof data.professional_id !== 'string') {
    errors.professional_id = 'Professional ID must be a string';
  }

  if (!data.service_id) {
    errors.service_id = 'Service ID is required';
  } else if (typeof data.service_id !== 'string') {
    errors.service_id = 'Service ID must be a string';
  }

  // duration_override_minutes: optional, but if provided, must be valid
  if (data.duration_override_minutes !== null && data.duration_override_minutes !== undefined) {
    const duration = Number(data.duration_override_minutes);
    if (!Number.isInteger(duration) || duration < 5 || duration > 1440) {
      errors.duration_override_minutes = 'Duration must be between 5 and 1440 minutes';
    }
  }

  // buffer_before_min: optional (default 0), must be valid
  if (data.buffer_before_min !== null && data.buffer_before_min !== undefined) {
    const buffer = Number(data.buffer_before_min);
    if (!Number.isInteger(buffer) || buffer < 0 || buffer > 480) {
      errors.buffer_before_min = 'Buffer before must be between 0 and 480 minutes';
    }
  }

  // buffer_after_min: optional (default 0), must be valid
  if (data.buffer_after_min !== null && data.buffer_after_min !== undefined) {
    const buffer = Number(data.buffer_after_min);
    if (!Number.isInteger(buffer) || buffer < 0 || buffer > 480) {
      errors.buffer_after_min = 'Buffer after must be between 0 and 480 minutes';
    }
  }

  // price_override_cents: optional, but if provided, must be valid (centavos inteiros)
  if (data.price_override_cents !== null && data.price_override_cents !== undefined) {
    const price = Number(data.price_override_cents);
    if (!Number.isInteger(price) || price < 0) {
      errors.price_override_cents = 'Price must be a non-negative integer (cents)';
    }
  }

  // active: optional (default true), must be boolean
  if (data.active !== null && data.active !== undefined && typeof data.active !== 'boolean') {
    errors.active = 'Active must be a boolean';
  }

  return {
    valid: Object.keys(errors).length === 0,
    errors,
  };
}
