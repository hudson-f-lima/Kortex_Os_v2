import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';

const COLUMNS = 'id, organization_id, professional_id, service_id, duration_override_minutes, buffer_before_min, buffer_after_min, price_override_cents, active, created_at, updated_at';

export function createProfessionalServiceCapabilitiesService(supabaseAdmin) {
  return {
    async list({ organizationId, professional_id, service_id }) {
      let query = supabaseAdmin
        .from('professional_service_capabilities')
        .select(COLUMNS)
        .eq('organization_id', organizationId);

      if (professional_id) {
        query = query.eq('professional_id', professional_id);
      }
      if (service_id) {
        query = query.eq('service_id', service_id);
      }

      const { data, error } = await query;
      if (error) throw mapPostgresError(error);
      return data || [];
    },

    async get({ organizationId, capabilityId }) {
      const { data, error } = await supabaseAdmin
        .from('professional_service_capabilities')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .eq('id', capabilityId)
        .maybeSingle();

      if (error) throw mapPostgresError(error);
      if (!data) return null;
      return data;
    },

    async create({ organizationId, payload }) {
      const { data, error } = await supabaseAdmin
        .from('professional_service_capabilities')
        .insert([
          {
            organization_id: organizationId,
            professional_id: payload.professional_id,
            service_id: payload.service_id,
            duration_override_minutes: payload.duration_override_minutes || null,
            buffer_before_min: payload.buffer_before_min || 0,
            buffer_after_min: payload.buffer_after_min || 0,
            price_override_cents: payload.price_override_cents || null,
            active: payload.active !== false,
          },
        ])
        .select(COLUMNS)
        .single();

      if (error) {
        const mapped = mapPostgresError(error);
        // Customize the message for duplicate capability
        if (error.code === '23505' && error.message.includes('professional_service_capabilities')) {
          throw HttpError.conflict('capability_duplicate', 'This professional already has this capability');
        }
        throw mapped;
      }
      return data;
    },

    async update({ organizationId, capabilityId, payload }) {
      const updates = {};

      if (payload.duration_override_minutes !== undefined) {
        updates.duration_override_minutes = payload.duration_override_minutes || null;
      }
      if (payload.buffer_before_min !== undefined) {
        updates.buffer_before_min = payload.buffer_before_min;
      }
      if (payload.buffer_after_min !== undefined) {
        updates.buffer_after_min = payload.buffer_after_min;
      }
      if (payload.price_override_cents !== undefined) {
        updates.price_override_cents = payload.price_override_cents || null;
      }
      if (payload.active !== undefined) {
        updates.active = payload.active;
      }

      const { data, error } = await supabaseAdmin
        .from('professional_service_capabilities')
        .update(updates)
        .eq('organization_id', organizationId)
        .eq('id', capabilityId)
        .select(COLUMNS)
        .maybeSingle();

      if (error) throw mapPostgresError(error);
      if (!data) return null;
      return data;
    },

    async delete({ organizationId, capabilityId }) {
      const { error } = await supabaseAdmin
        .from('professional_service_capabilities')
        .delete()
        .eq('organization_id', organizationId)
        .eq('id', capabilityId);

      if (error) throw mapPostgresError(error);
      return true;
    },
  };
}
