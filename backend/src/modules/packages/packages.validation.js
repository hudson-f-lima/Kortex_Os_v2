import { HttpError } from '../../shared/httpError.js';
import { UUID_RE, validateId, validateMoneyCents, validateRequiredString } from '../../shared/validation.js';

export const validatePackageId = validateId;

function validatePackageItem(item, index) {
  if (item === null || typeof item !== 'object' || Array.isArray(item)) {
    throw HttpError.badRequest('invalid_items', `items[${index}] must be an object`);
  }
  if (typeof item.service_id !== 'string' || !UUID_RE.test(item.service_id)) {
    throw HttpError.badRequest('invalid_items', `items[${index}].service_id must be a uuid`);
  }
  if (item.quantity !== undefined && (!Number.isInteger(item.quantity) || item.quantity <= 0)) {
    throw HttpError.badRequest('invalid_items', `items[${index}].quantity must be a positive integer`);
  }
  return { service_id: item.service_id, quantity: item.quantity ?? 1 };
}

function validateItems(items) {
  if (!Array.isArray(items) || items.length === 0) {
    throw HttpError.badRequest('invalid_items', 'items must be a non-empty array');
  }
  return items.map(validatePackageItem);
}

const CREATE_FIELDS = new Set(['name', 'price_cents', 'items']);

export function validateCreatePackagePayload(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }
  const unknown = Object.keys(body).filter((key) => !CREATE_FIELDS.has(key));
  if (unknown.length > 0) {
    throw HttpError.badRequest('unknown_fields', 'payload has unsupported fields', { fields: unknown });
  }

  return {
    name: validateRequiredString(body.name, 'name', { min: 1, max: 160 }),
    price_cents: validateMoneyCents(body.price_cents, 'price_cents'),
    items: validateItems(body.items),
  };
}

const UPDATE_FIELDS = new Set(['name', 'price_cents', 'active', 'items']);

export function validateUpdatePackagePayload(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }
  const unknown = Object.keys(body).filter((key) => !UPDATE_FIELDS.has(key));
  if (unknown.length > 0) {
    throw HttpError.badRequest('unknown_fields', 'payload has unsupported fields', { fields: unknown });
  }

  const patch = {};
  if (body.name !== undefined) {
    patch.name = validateRequiredString(body.name, 'name', { min: 1, max: 160 });
  }
  if (body.price_cents !== undefined) {
    patch.price_cents = validateMoneyCents(body.price_cents, 'price_cents');
  }
  if (body.active !== undefined) {
    if (typeof body.active !== 'boolean') {
      throw HttpError.badRequest('invalid_active', 'active must be a boolean');
    }
    patch.active = body.active;
  }
  if (body.items !== undefined) {
    patch.items = validateItems(body.items);
  }
  if (Object.keys(patch).length === 0) {
    throw HttpError.badRequest('empty_payload', 'at least one field must be provided');
  }
  return patch;
}
