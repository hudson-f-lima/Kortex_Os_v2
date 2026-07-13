// Helpers de data para a grade da Agenda. Sem lib externa (nenhuma
// disponível em package.json) — cálculos simples o bastante para não
// justificar uma dependência nova.

export const SLOT_MINUTES = 30;
export const DAY_START_HOUR = 7;
export const DAY_END_HOUR = 21;

export function startOfDay(date) {
  const result = new Date(date);
  result.setHours(0, 0, 0, 0);
  return result;
}

export function addDays(date, amount) {
  const result = new Date(date);
  result.setDate(result.getDate() + amount);
  return result;
}

export function addMinutes(date, amount) {
  return new Date(date.getTime() + amount * 60000);
}

// Segunda-feira como início de semana (padrão de agenda comercial no Brasil).
export function startOfWeek(date) {
  const result = startOfDay(date);
  const day = result.getDay();
  const diff = day === 0 ? -6 : 1 - day;
  return addDays(result, diff);
}

export function dateKey(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  return `${year}-${month}-${day}`;
}

export function formatTime(date) {
  return date.toLocaleTimeString('pt-BR', { hour: '2-digit', minute: '2-digit' });
}

export function formatDayLabel(date) {
  return date.toLocaleDateString('pt-BR', { weekday: 'short', day: '2-digit', month: '2-digit' });
}

export function formatDateHeading(date) {
  return date.toLocaleDateString('pt-BR', { weekday: 'long', day: '2-digit', month: 'long', year: 'numeric' });
}

// [from, to) do dia, para usar em GET /appointments?from&to.
export function dayRange(date) {
  const from = startOfDay(date);
  const to = addDays(from, 1);
  return { from: from.toISOString(), to: to.toISOString() };
}

// [from, to) da semana (segunda a domingo).
export function weekRange(date) {
  const from = startOfWeek(date);
  const to = addDays(from, 7);
  return { from: from.toISOString(), to: to.toISOString() };
}

export function weekDays(date) {
  const start = startOfWeek(date);
  return Array.from({ length: 7 }, (_, index) => addDays(start, index));
}

// Slots de horário do dia (grade), em intervalos de SLOT_MINUTES entre
// DAY_START_HOUR e DAY_END_HOUR. Horário comercial fixo — não existe ainda
// uma entidade de turno/expediente por profissional no schema (ver
// docs/PWA_PLANEJAMENTO.md §2.1/§8), então isto é um piso fixo do MVP.
export function daySlots(date) {
  const base = startOfDay(date);
  const totalSlots = ((DAY_END_HOUR - DAY_START_HOUR) * 60) / SLOT_MINUTES;
  return Array.from({ length: totalSlots }, (_, index) => addMinutes(base, DAY_START_HOUR * 60 + index * SLOT_MINUTES));
}

export function slotIndexForTime(date, referenceDay) {
  const base = startOfDay(referenceDay);
  const minutesFromDayStart = (date.getTime() - base.getTime()) / 60000 - DAY_START_HOUR * 60;
  return Math.floor(minutesFromDayStart / SLOT_MINUTES);
}

export function totalSlots() {
  return ((DAY_END_HOUR - DAY_START_HOUR) * 60) / SLOT_MINUTES;
}

// Formata um Date local para o valor esperado por <input type="datetime-local">.
export function toDateTimeLocalValue(date) {
  const year = date.getFullYear();
  const month = String(date.getMonth() + 1).padStart(2, '0');
  const day = String(date.getDate()).padStart(2, '0');
  const hours = String(date.getHours()).padStart(2, '0');
  const minutes = String(date.getMinutes()).padStart(2, '0');
  return `${year}-${month}-${day}T${hours}:${minutes}`;
}

export function fromDateTimeLocalValue(value) {
  const date = new Date(value);
  return Number.isNaN(date.getTime()) ? null : date;
}
