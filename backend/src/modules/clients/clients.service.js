import { HttpError } from '../../shared/httpError.js';
import { mapPostgresError } from '../../shared/postgresError.js';

const COLUMNS = 'id, organization_id, name, phone, email, active, created_at, updated_at';
const PROFESSIONAL_COLUMNS = 'id, name';

async function listOwnAppointmentClients(
  supabaseAdmin,
  { organizationId, unitId, professionalId, active, clientId },
) {
  if (!unitId || !professionalId) return [];

  let appointmentsQuery = supabaseAdmin
    .from('appointments')
    .select('client_id')
    .eq('organization_id', organizationId)
    .eq('unit_id', unitId)
    .eq('professional_id', professionalId)
    .not('client_id', 'is', null);
  if (clientId !== undefined) appointmentsQuery = appointmentsQuery.eq('client_id', clientId);
  const { data: appointments, error: appointmentsError } = await appointmentsQuery;
  if (appointmentsError) throw mapPostgresError(appointmentsError);

  const clientIds = [...new Set(appointments.map((appointment) => appointment.client_id))];
  if (clientIds.length === 0) return [];

  let query = supabaseAdmin
    .from('clients')
    .select(PROFESSIONAL_COLUMNS)
    .eq('organization_id', organizationId)
    .in('id', clientIds)
    .order('name', { ascending: true });
  if (active !== undefined) query = query.eq('active', active);
  const { data, error } = await query;
  if (error) throw mapPostgresError(error);
  return data;
}

export function createClientsService(supabaseAdmin) {
  return {
    async list({ organizationId, active, professionalScope }) {
      if (professionalScope) {
        return listOwnAppointmentClients(supabaseAdmin, {
          organizationId,
          active,
          ...professionalScope,
        });
      }
      let query = supabaseAdmin
        .from('clients')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .order('name', { ascending: true });
      if (active !== undefined) {
        query = query.eq('active', active);
      }
      const { data, error } = await query;
      if (error) throw mapPostgresError(error);
      return data;
    },

    async get({ organizationId, clientId, professionalScope }) {
      if (professionalScope) {
        const clients = await listOwnAppointmentClients(supabaseAdmin, {
          organizationId,
          clientId,
          ...professionalScope,
        });
        if (clients.length === 0) throw HttpError.notFound('client_not_found', 'client not found');
        return clients[0];
      }
      const { data, error } = await supabaseAdmin
        .from('clients')
        .select(COLUMNS)
        .eq('organization_id', organizationId)
        .eq('id', clientId)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('client_not_found', 'client not found');
      return data;
    },

    async create({ organizationId, actorUserId, patch }) {
      const { data, error } = await supabaseAdmin
        .from('clients')
        .insert({ organization_id: organizationId, created_by: actorUserId, ...patch })
        .select(COLUMNS)
        .single();
      if (error) throw mapPostgresError(error);
      return data;
    },

    async update({ organizationId, clientId, patch }) {
      const { data, error } = await supabaseAdmin
        .from('clients')
        .update(patch)
        .eq('organization_id', organizationId)
        .eq('id', clientId)
        .select(COLUMNS)
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('client_not_found', 'client not found');
      return data;
    },

    async remove({ organizationId, clientId }) {
      const { data, error } = await supabaseAdmin
        .from('clients')
        .delete()
        .eq('organization_id', organizationId)
        .eq('id', clientId)
        .select('id')
        .maybeSingle();
      if (error) throw mapPostgresError(error);
      if (!data) throw HttpError.notFound('client_not_found', 'client not found');
    },
  };
}
