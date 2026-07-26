import { mapPostgresError } from '../../shared/postgresError.js';

export function createPspWebhookEventsService(supabaseAdmin) {
  return {
    // At-least-once delivery (Blueprint §3.5): a replayed provider_event_id
    // hits the unique constraint and upsert(ignoreDuplicates) returns no row
    // instead of erroring — that IS the idempotent-success path, not a retry.
    async ingest({ provider, providerEventId, eventType, providerReference, status, rawPayload }) {
      const { data: inserted, error: insertError } = await supabaseAdmin
        .from('psp_webhook_events')
        .upsert(
          { provider, provider_event_id: providerEventId, event_type: eventType, payload: rawPayload },
          { onConflict: 'provider,provider_event_id', ignoreDuplicates: true },
        )
        .select('id')
        .maybeSingle();
      if (insertError) throw mapPostgresError(insertError);

      if (!inserted) {
        return { duplicate: true, matched: false };
      }

      const { data: intent, error: intentError } = await supabaseAdmin
        .from('payment_intents')
        .select('id, organization_id, unit_id')
        .eq('provider', provider)
        .eq('provider_reference', providerReference)
        .maybeSingle();
      if (intentError) throw mapPostgresError(intentError);

      if (!intent) {
        // Dead-letter: organization_id/unit_id/payment_intent_id stay NULL
        // together. Never discarded — reprocessable once the intent shows up.
        return { duplicate: false, matched: false };
      }

      const { error: updateIntentError } = await supabaseAdmin
        .from('payment_intents')
        .update({ status })
        .eq('id', intent.id);
      if (updateIntentError) throw mapPostgresError(updateIntentError);

      const { error: updateEventError } = await supabaseAdmin
        .from('psp_webhook_events')
        .update({
          organization_id: intent.organization_id,
          unit_id: intent.unit_id,
          payment_intent_id: intent.id,
          processed_at: new Date().toISOString(),
        })
        .eq('provider', provider)
        .eq('provider_event_id', providerEventId);
      if (updateEventError) throw mapPostgresError(updateEventError);

      return { duplicate: false, matched: true };
    },
  };
}
