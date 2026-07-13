import { HttpError } from '../../shared/httpError.js';
import { UUID_RE } from '../../shared/validation.js';

const ITEM_KINDS = ['service', 'product', 'package'];
const PAYMENT_METHODS = ['cash', 'pix', 'debit_card', 'credit_card', 'other'];

// Keys are the package's component service_id, values the professional_id
// who performed that component (docs/PLANEJAMENTO_COMISSOES.md §4.4/§6 — a
// package can involve more than one professional). Keys are normalized to
// lowercase because checkout_close matches them against service_id::text,
// which Postgres always renders lowercase.
function validateProfessionalsMap(value, index) {
  if (value === null || typeof value !== 'object' || Array.isArray(value)) {
    throw HttpError.badRequest(
      'invalid_items',
      `items[${index}].professionals must be an object mapping service_id to professional_id`,
    );
  }
  const entries = Object.entries(value);
  if (entries.length === 0) {
    throw HttpError.badRequest('invalid_items', `items[${index}].professionals must not be empty`);
  }
  const normalized = {};
  for (const [serviceId, professionalId] of entries) {
    if (!UUID_RE.test(serviceId)) {
      throw HttpError.badRequest('invalid_items', `items[${index}].professionals has a key that is not a uuid`);
    }
    if (typeof professionalId !== 'string' || !UUID_RE.test(professionalId)) {
      throw HttpError.badRequest('invalid_items', `items[${index}].professionals.${serviceId} must be a uuid`);
    }
    normalized[serviceId.toLowerCase()] = professionalId;
  }
  return normalized;
}

function validateCheckoutItem(item, index) {
  if (item === null || typeof item !== 'object' || Array.isArray(item)) {
    throw HttpError.badRequest('invalid_items', `items[${index}] must be an object`);
  }
  if (!ITEM_KINDS.includes(item.kind)) {
    throw HttpError.badRequest('invalid_items', `items[${index}].kind must be one of: ${ITEM_KINDS.join(', ')}`);
  }
  if (typeof item.id !== 'string' || !UUID_RE.test(item.id)) {
    throw HttpError.badRequest('invalid_items', `items[${index}].id must be a uuid`);
  }
  if (!Number.isInteger(item.quantity) || item.quantity <= 0) {
    throw HttpError.badRequest('invalid_items', `items[${index}].quantity must be a positive integer`);
  }

  if (item.kind === 'service') {
    if (typeof item.professional_id !== 'string' || !UUID_RE.test(item.professional_id)) {
      throw HttpError.badRequest('invalid_items', `items[${index}].professional_id is required for service items`);
    }
    return { kind: item.kind, id: item.id, quantity: item.quantity, professional_id: item.professional_id };
  }

  if (item.kind === 'package') {
    // Selling two identical packages is two items in the payload, each
    // expanding independently — avoids deciding how to duplicate a
    // professional assignment map across multiple units of the same bundle.
    if (item.quantity !== 1) {
      throw HttpError.badRequest('invalid_items', `items[${index}].quantity must be 1 for package items`);
    }
    const professionals = validateProfessionalsMap(item.professionals, index);
    return { kind: item.kind, id: item.id, quantity: item.quantity, professionals };
  }

  return { kind: item.kind, id: item.id, quantity: item.quantity };
}

function validateCheckoutPayment(payment, index) {
  if (payment === null || typeof payment !== 'object' || Array.isArray(payment)) {
    throw HttpError.badRequest('invalid_payments', `payments[${index}] must be an object`);
  }
  if (!PAYMENT_METHODS.includes(payment.method)) {
    throw HttpError.badRequest(
      'invalid_payments',
      `payments[${index}].method must be one of: ${PAYMENT_METHODS.join(', ')}`,
    );
  }
  if (!Number.isInteger(payment.amount_cents) || payment.amount_cents <= 0) {
    throw HttpError.badRequest('invalid_payments', `payments[${index}].amount_cents must be a positive integer`);
  }
  return { method: payment.method, amount_cents: payment.amount_cents };
}

export function validateCheckoutPayload(body) {
  if (body === null || typeof body !== 'object' || Array.isArray(body)) {
    throw HttpError.badRequest('invalid_payload', 'payload must be a JSON object');
  }

  const allowed = new Set(['client_id', 'items', 'payments']);
  const unknown = Object.keys(body).filter((key) => !allowed.has(key));
  if (unknown.length > 0) {
    throw HttpError.badRequest('unknown_fields', 'payload has unsupported fields', { fields: unknown });
  }

  if (body.client_id !== undefined && body.client_id !== null) {
    if (typeof body.client_id !== 'string' || !UUID_RE.test(body.client_id)) {
      throw HttpError.badRequest('invalid_client_id', 'client_id must be a uuid or null');
    }
  }

  if (!Array.isArray(body.items) || body.items.length === 0) {
    throw HttpError.badRequest('invalid_items', 'items must be a non-empty array');
  }
  const items = body.items.map(validateCheckoutItem);

  if (!Array.isArray(body.payments) || body.payments.length === 0) {
    throw HttpError.badRequest('invalid_payments', 'payments must be a non-empty array');
  }
  const payments = body.payments.map(validateCheckoutPayment);

  return { client_id: body.client_id ?? null, items, payments };
}
