import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';
import { addDays, dateRange } from './availability.validation.js';
import { intersectBlocks, subtractIntervalsMs, generateSlotStartsMs } from './availabilitySlotMath.js';

const OCCUPYING_APPOINTMENT_STATUSES = ['scheduled', 'confirmed', 'in_service'];
const SLOT_STEP_MINUTES = 15;

export function createAvailabilityService(supabaseAdmin) {
  async function fetchUnit({ organizationId, unitId }) {
    const { data, error } = await supabaseAdmin
      .from('units')
      .select('id, timezone')
      .eq('organization_id', organizationId)
      .eq('id', unitId)
      .maybeSingle();
    if (error) throw mapPostgresError(error);
    if (!data) throw HttpError.badRequest('invalid_unit_id', 'unitId must reference an existing unit in this organization');
    return data;
  }

  async function resolveDurationMinutes({ organizationId, serviceId, professionalId }) {
    const { data: service, error: serviceError } = await supabaseAdmin
      .from('services')
      .select('id, duration_minutes')
      .eq('organization_id', organizationId)
      .eq('id', serviceId)
      .maybeSingle();
    if (serviceError) throw mapPostgresError(serviceError);
    if (!service) {
      throw HttpError.badRequest('invalid_service_id', 'service_id must reference an existing service in this organization');
    }

    if (!professionalId) return service.duration_minutes;

    // Cascata de override profissional×serviço (nível 1, já REAL — achado §0
    // do Blueprint da Onda 3). Buffer/consumo técnico fica fora desta v1
    // (limitação registrada, Blueprint Onda 4 §3.4 — não bloqueia a aprovação).
    const { data: capability, error: capabilityError } = await supabaseAdmin
      .from('professional_service_capabilities')
      .select('duration_override_minutes')
      .eq('organization_id', organizationId)
      .eq('professional_id', professionalId)
      .eq('service_id', serviceId)
      .maybeSingle();
    if (capabilityError) throw mapPostgresError(capabilityError);
    return capability?.duration_override_minutes ?? service.duration_minutes;
  }

  async function isEligible({ organizationId, professionalId, serviceId }) {
    const { data, error } = await supabaseAdmin.rpc('resolve_eligibility', {
      p_organization_id: organizationId,
      p_professional_id: professionalId,
      p_service_id: serviceId,
    });
    if (error) throw mapPostgresError(error);
    return data?.[0]?.eligible !== false;
  }

  async function resolveCandidateProfessionalIds({ organizationId, unitId, serviceId, professionalId }) {
    if (professionalId) {
      const { data, error } = await supabaseAdmin
        .from('professional_units')
        .select('professional_id')
        .eq('organization_id', organizationId)
        .eq('unit_id', unitId)
        .eq('professional_id', professionalId)
        .eq('active', true)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) {
        throw HttpError.badRequest('invalid_professional_id', 'professional_id must have an active link to this unit');
      }
      // Achado de auditoria pós-implementação (2026-07-29): antes desta
      // correção, mesmo um professional_id explícito com
      // eligibility='DISABLED' (ADR 0010) ainda mostrava slots — a checagem
      // de vínculo à unidade não substitui a checagem de elegibilidade por
      // serviço, são invariantes diferentes.
      if (!(await isEligible({ organizationId, professionalId, serviceId }))) {
        throw HttpError.badRequest('professional_not_eligible', 'professional_id is not eligible for this service');
      }
      return [professionalId];
    }

    const { data, error } = await supabaseAdmin
      .from('professional_units')
      .select('professional_id')
      .eq('organization_id', organizationId)
      .eq('unit_id', unitId)
      .eq('active', true);
    if (error) throw mapPostgresError(error);
    const candidateIds = [...new Set((data ?? []).map((row) => row.professional_id))];

    const eligibilityChecks = await Promise.all(
      candidateIds.map((id) => isEligible({ organizationId, professionalId: id, serviceId })),
    );
    return candidateIds.filter((_, index) => eligibilityChecks[index]);
  }

  async function localTimeToUtc({ timezone, date, localTime }) {
    const { data, error } = await supabaseAdmin.rpc('local_time_to_utc', {
      p_timezone: timezone,
      p_date: date,
      p_local_time: localTime,
    });
    if (error) throw mapPostgresError(error);
    return data;
  }

  async function blocksToUtcIntervals({ timezone, date, blocks }) {
    const intervals = [];
    for (const block of blocks) {
      const [startsAt, endsAt] = await Promise.all([
        localTimeToUtc({ timezone, date, localTime: minutesToHhmm(block.startMinutes) }),
        localTimeToUtc({ timezone, date, localTime: minutesToHhmm(block.endMinutes) }),
      ]);
      intervals.push({ startMs: new Date(startsAt).getTime(), endMs: new Date(endsAt).getTime() });
    }
    return intervals;
  }

  function minutesToHhmm(minutes) {
    const hours = Math.floor(minutes / 60).toString().padStart(2, '0');
    const mins = (minutes % 60).toString().padStart(2, '0');
    return `${hours}:${mins}`;
  }

  // Occupancy source: appointments only. This structurally also covers
  // deposit_holds (Onda 1) — every deposit_holds row requires an
  // appointment_id and has no starts_at/ends_at of its own (verified against
  // supabase/migrations/20260726160000_onda1_deposit_holds_creation.sql), so
  // a hold's time window is always the appointment's own row, already
  // queried here whenever its status is occupying.
  //
  // resource_locks is a genuinely separate, undocumented gap (achado de
  // auditoria pós-implementação, 2026-07-29), not fixed here: no table in
  // this schema maps a service/professional to the resource(s) it requires,
  // so there is no correct way to know which resource_locks should reduce
  // THIS professional's slots without inventing that mapping as an
  // undocumented product decision. Left as an explicit limitation — see
  // Blueprint §3.4 and issue 028.
  async function fetchOccupiedIntervalsMs({ organizationId, unitId, professionalId, timezone, dateFrom, dateTo }) {
    const [rangeStartUtc, rangeEndUtc] = await Promise.all([
      localTimeToUtc({ timezone, date: dateFrom, localTime: '00:00' }),
      localTimeToUtc({ timezone, date: addDays(dateTo, 1), localTime: '00:00' }),
    ]);

    const { data, error } = await supabaseAdmin
      .from('appointments')
      .select('starts_at, ends_at')
      .eq('organization_id', organizationId)
      .eq('unit_id', unitId)
      .eq('professional_id', professionalId)
      .in('status', OCCUPYING_APPOINTMENT_STATUSES)
      .lt('starts_at', rangeEndUtc)
      .gt('ends_at', rangeStartUtc);
    if (error) throw mapPostgresError(error);
    return (data ?? []).map((row) => ({
      startMs: new Date(row.starts_at).getTime(),
      endMs: new Date(row.ends_at).getTime(),
    }));
  }

  async function computeSlotsForProfessionalDay({ organizationId, unitId, professionalId, date, timezone, durationMinutes, occupiedIntervalsMs }) {
    const [{ data: policyBlocks, error: policyError }, { data: shiftBlocks, error: shiftError }, { data: overrideRows, error: overrideError }] =
      await Promise.all([
        supabaseAdmin.rpc('resolve_calendar_policy', { p_organization_id: organizationId, p_unit_id: unitId, p_date: date }),
        supabaseAdmin.rpc('resolve_professional_shift', {
          p_organization_id: organizationId,
          p_professional_id: professionalId,
          p_unit_id: unitId,
          p_date: date,
        }),
        supabaseAdmin.rpc('resolve_calendar_overrides', {
          p_organization_id: organizationId,
          p_unit_id: unitId,
          p_professional_id: professionalId,
          p_date: date,
        }),
      ]);
    if (policyError) throw mapPostgresError(policyError);
    if (shiftError) throw mapPostgresError(shiftError);
    if (overrideError) throw mapPostgresError(overrideError);

    // Tier 1/2 override closing the day wins outright. Tier 1/3 opening the
    // day still falls back to the standard policy/shift blocks in this v1 —
    // known simplification (Blueprint §3.4 documents the analogous buffer
    // gap; the same "fundação, não gold-plating" reasoning applies here):
    // resolve_calendar_overrides confirms the day is open but does not
    // return the exceptional window's own hours.
    const override = overrideRows?.[0];
    if (override && override.is_open === false) {
      return [];
    }

    const policy = policyBlocks?.[0]?.blocks ?? [];
    const shift = shiftBlocks?.[0]?.blocks ?? [];
    if (policy.length === 0 || shift.length === 0) {
      return [];
    }

    const localIntersection = intersectBlocks(policy, shift);
    if (localIntersection.length === 0) return [];

    const freeUtcIntervals = await blocksToUtcIntervals({ timezone, date, blocks: localIntersection });
    const free = subtractIntervalsMs(freeUtcIntervals, occupiedIntervalsMs);
    const slots = generateSlotStartsMs(free, durationMinutes * 60000, SLOT_STEP_MINUTES * 60000);

    return slots.map((slot) => ({
      starts_at: new Date(slot.startMs).toISOString(),
      ends_at: new Date(slot.endMs).toISOString(),
    }));
  }

  return {
    async getSlots({ organizationId, unitId, serviceId, professionalId, dateFrom, dateTo }) {
      const unit = await fetchUnit({ organizationId, unitId });
      const durationMinutes = await resolveDurationMinutes({ organizationId, serviceId, professionalId });
      const candidateProfessionalIds = await resolveCandidateProfessionalIds({ organizationId, unitId, serviceId, professionalId });
      const dates = dateRange(dateFrom, dateTo);

      const results = [];
      for (const candidateId of candidateProfessionalIds) {
        const occupiedIntervalsMs = await fetchOccupiedIntervalsMs({
          organizationId,
          unitId,
          professionalId: candidateId,
          timezone: unit.timezone,
          dateFrom,
          dateTo,
        });

        for (const date of dates) {
          const slots = await computeSlotsForProfessionalDay({
            organizationId,
            unitId,
            professionalId: candidateId,
            date,
            timezone: unit.timezone,
            durationMinutes,
            occupiedIntervalsMs,
          });
          if (slots.length > 0) {
            results.push({ date, professional_id: candidateId, slots });
          }
        }
      }

      return results;
    },
  };
}
