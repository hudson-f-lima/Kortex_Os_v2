const REDACTED_KEYS = new Set(['token', 'authorization', 'apikey', 'service_role_key', 'password']);

function sanitize(meta) {
  const out = {};
  for (const [key, value] of Object.entries(meta ?? {})) {
    out[key] = REDACTED_KEYS.has(key.toLowerCase()) ? '[redacted]' : value;
  }
  return out;
}

function log(level, msg, meta) {
  const entry = { level, msg, time: new Date().toISOString(), ...sanitize(meta) };
  const line = JSON.stringify(entry);
  if (level === 'error') {
    console.error(line);
  } else {
    console.log(line);
  }
}

export const logger = {
  info: (msg, meta) => log('info', msg, meta),
  warn: (msg, meta) => log('warn', msg, meta),
  error: (msg, meta) => log('error', msg, meta),
};
