import { useMemo, useState } from 'react';
import { reaisToCents } from '../../shared/money.js';
import { messageForCheckoutError } from './comandaErrors.js';

function newLineKey() {
  return crypto.randomUUID();
}

// Estado e lógica de fechamento da comanda — extraído de ComandaPage.jsx
// (corte-e-cola sem mudança de comportamento). Recebe cart/clientId/etc. de
// fora porque o corpo do checkout depende do carrinho (useCart) e do
// agendamento pré-carregado (efeito que continua em ComandaPage).
export function useCheckout({ apiClient, cart, clientId, subtotalCents, hasServiceLine, appointmentId, appointmentVersion }) {
  const [step, setStep] = useState('building'); // 'building' | 'payment' | 'closed'
  const [idempotencyKey, setIdempotencyKey] = useState(null);
  const [payments, setPayments] = useState([]);
  const [discountReais, setDiscountReais] = useState('');
  const [tipReais, setTipReais] = useState('');
  const [submitting, setSubmitting] = useState(false);
  const [checkoutError, setCheckoutError] = useState(null);
  const [closedOrder, setClosedOrder] = useState(null);

  const discountCents = discountReais.trim() === '' ? 0 : reaisToCents(discountReais);
  const tipCents = tipReais.trim() === '' ? 0 : reaisToCents(tipReais);
  const discountValid = Number.isInteger(discountCents) && discountCents >= 0 && discountCents <= subtotalCents;
  const tipValid = Number.isInteger(tipCents) && tipCents >= 0 && (tipCents === 0 || hasServiceLine);
  const finalTotalCents = subtotalCents - (discountValid ? discountCents : 0) + (tipValid ? tipCents : 0);

  const paymentsWithCents = useMemo(
    () => payments.map((payment) => ({ ...payment, amountCents: reaisToCents(payment.amountReais) })),
    [payments],
  );

  const paymentsTotalCents = useMemo(
    () => paymentsWithCents.reduce((sum, payment) => sum + (payment.amountCents ?? 0), 0),
    [paymentsWithCents],
  );

  const paymentsReconcile =
    paymentsWithCents.length > 0 &&
    paymentsWithCents.every((payment) => Number.isInteger(payment.amountCents) && payment.amountCents > 0) &&
    paymentsWithCents.reduce((sum, payment) => sum + payment.amountCents, 0) === finalTotalCents;

  const canClose = paymentsReconcile && discountValid && tipValid;

  function goToPayment() {
    setIdempotencyKey(crypto.randomUUID());
    setPayments([{ key: newLineKey(), method: 'cash', amountReais: (subtotalCents / 100).toFixed(2) }]);
    setDiscountReais('');
    setTipReais('');
    setCheckoutError(null);
    setStep('payment');
  }

  function backToBuilding() {
    setStep('building');
    setCheckoutError(null);
  }

  function addPaymentLine() {
    setPayments((current) => [...current, { key: newLineKey(), method: 'cash', amountReais: '' }]);
  }

  function removePaymentLine(key) {
    setPayments((current) => current.filter((payment) => payment.key !== key));
  }

  function updatePayment(key, patch) {
    setPayments((current) => current.map((payment) => (payment.key === key ? { ...payment, ...patch } : payment)));
  }

  function fillRemaining(key) {
    const current = paymentsWithCents.find((payment) => payment.key === key)?.amountCents ?? 0;
    const remaining = finalTotalCents - (paymentsTotalCents - current);
    updatePayment(key, { amountReais: (Math.max(remaining, 0) / 100).toFixed(2) });
  }

  async function handleClose() {
    setSubmitting(true);
    setCheckoutError(null);
    try {
      const body = {
        client_id: clientId || null,
        items: cart.map((line) => {
          if (line.kind === 'service') {
            return { kind: 'service', id: line.catalogId, quantity: line.quantity, professional_id: line.professionalId };
          }
          if (line.kind === 'package') {
            return {
              kind: 'package',
              id: line.catalogId,
              quantity: 1,
              professionals: Object.fromEntries(line.components.map((component) => [component.serviceId, component.professionalId])),
            };
          }
          return { kind: 'product', id: line.catalogId, quantity: line.quantity };
        }),
        payments: paymentsWithCents.map((payment) => ({ method: payment.method, amount_cents: payment.amountCents })),
        discount_cents: discountValid ? discountCents : 0,
        tip_cents: tipValid ? tipCents : 0,
      };
      const result = await apiClient.post('/checkout', body, { headers: { 'Idempotency-Key': idempotencyKey } });
      setClosedOrder(result);
      setStep('closed');
      if (appointmentId) {
        apiClient
          .patch(
            `/appointments/${appointmentId}`,
            { status: 'completed', version: appointmentVersion },
            { headers: { 'Idempotency-Key': `appt-complete-${crypto.randomUUID()}` } },
          )
          .catch(() => {
            /* melhor esforço — não bloqueia a comanda já fechada */
          });
      }
    } catch (err) {
      setCheckoutError(messageForCheckoutError(err));
    } finally {
      setSubmitting(false);
    }
  }

  function resetCheckout() {
    setPayments([]);
    setDiscountReais('');
    setTipReais('');
    setIdempotencyKey(null);
    setCheckoutError(null);
    setClosedOrder(null);
    setStep('building');
  }

  return {
    step,
    payments,
    discountReais,
    setDiscountReais,
    tipReais,
    setTipReais,
    submitting,
    checkoutError,
    closedOrder,
    discountCents,
    tipCents,
    discountValid,
    tipValid,
    finalTotalCents,
    paymentsWithCents,
    paymentsTotalCents,
    paymentsReconcile,
    canClose,
    goToPayment,
    backToBuilding,
    addPaymentLine,
    removePaymentLine,
    updatePayment,
    fillRemaining,
    handleClose,
    resetCheckout,
  };
}
