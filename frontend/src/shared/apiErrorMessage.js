import { ApiError } from './apiClient.js';

export const OFFLINE_FALLBACK = 'Sem conexão. Verifique sua internet e tente novamente.';
export const GENERIC_FALLBACK = 'Erro inesperado. Tente novamente.';
export const FORBIDDEN_MESSAGE = 'Seu papel não tem permissão para esta ação.';

// Consolida o esqueleto (if ApiError ... else fallback) antes duplicado em
// ~20 arquivos, sem colapsar os mapeamentos extras (403/409/código de
// negócio) que já são reais e distintos em alguns fluxos — cada chamador
// injeta só o que precisa via `statuses`/`codes`.
export function messageForError(err, { fallback = GENERIC_FALLBACK, statuses = {}, codes = {} } = {}) {
  if (err instanceof ApiError) {
    if (statuses[err.status]) return statuses[err.status];
    if (codes[err.code]) return codes[err.code];
    return err.message;
  }
  return fallback;
}
