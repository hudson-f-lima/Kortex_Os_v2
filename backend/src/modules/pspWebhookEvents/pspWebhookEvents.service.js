import { mapPostgresError } from '../../shared/postgresError.js';

export function createPspWebhookEventsService(supabaseAdmin) {
  return {
    async ingest({ provider, providerEventId, eventType, providerReference, status, rawPayload }) {
      // The RPC owns the durable event, intent lookup, state transition and
      // retry bookkeeping as one transaction. A redelivery of an unmatched
      // event is retried; a processed event remains an idempotent no-op.
      const { data, error } = await supabaseAdmin.rpc('psp_webhook_event_ingest', {
        p_provider: provider,
        p_provider_event_id: providerEventId,
        p_event_type: eventType,
        p_provider_reference: providerReference,
        p_status: status,
        p_payload: rawPayload,
      });
      if (error) throw mapPostgresError(error);
      return data;
    },
  };
}
