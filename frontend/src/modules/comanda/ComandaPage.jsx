import { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { useApiClient } from '../../shared/useApiClient.js';
import { useOrganization } from '../../shared/useOrganization.js';
import { ClientPicker } from '../../shared/ClientPicker.jsx';
import { Modal } from '../../shared/Modal.jsx';
import { formatCents } from '../../shared/money.js';
import { messageForError, OFFLINE_FALLBACK } from '../../shared/apiErrorMessage.js';
import { useCart } from './useCart.js';
import { useCheckout } from './useCheckout.js';
import { OrderHistory } from './OrderHistory.jsx';

// Mirrors backend/src/modules/checkout/checkout.route.js CHECKOUT_ROLES and
// orders.route.js READ_ROLES — professional is deliberately excluded from
// both (checkout_close's actor_has_role never included it), so this module
// is read-only-unavailable for that role, not something invented here.
const OPERATE_ROLES = ['owner', 'admin', 'manager', 'reception'];
// Mirrors order_refund's internal actor_has_role check (REFUND_ROLES em
// orders.route.js) — reception opera a comanda mas não pode estornar.
const REFUND_ROLES = ['owner', 'admin', 'manager'];
const PAYMENT_METHODS = [
  { value: 'cash', label: 'Dinheiro' },
  { value: 'pix', label: 'Pix' },
  { value: 'debit_card', label: 'Cartão de débito' },
  { value: 'credit_card', label: 'Cartão de crédito' },
  { value: 'other', label: 'Outro' },
];

function newLineKey() {
  return crypto.randomUUID();
}

export function ComandaPage() {
  const { role } = useOrganization();
  const apiClient = useApiClient();
  const navigate = useNavigate();
  const [searchParams] = useSearchParams();
  const appointmentId = searchParams.get('appointment_id');
  const canOperate = OPERATE_ROLES.includes(role);
  const canRefund = REFUND_ROLES.includes(role);

  const [view, setView] = useState('nova'); // 'nova' | 'historico'
  const [listsLoading, setListsLoading] = useState(true);
  const [listsError, setListsError] = useState(null);
  const [professionals, setProfessionals] = useState([]);
  const [catalogItems, setCatalogItems] = useState([]);
  const [clients, setClients] = useState([]);

  const [clientId, setClientId] = useState('');
  const [search, setSearch] = useState('');
  const [appointmentVersion, setAppointmentVersion] = useState(null);
  const [assigningKey, setAssigningKey] = useState(null);

  const {
    cart,
    setCart,
    subtotalCents,
    hasServiceLine,
    cartIsReady,
    addServiceOrProduct,
    addPackage,
    updateLineQuantity,
    removeLine,
    setLineProfessional,
    setPackageComponentProfessional,
    resetCart,
  } = useCart(apiClient, catalogItems, {
    // Abre o modal de atribuição de profissional assim que um serviço avulso
    // ou pacote entra no carrinho — produto não precisa (sem profissional).
    onLineAdded: (line) => {
      if (line.kind === 'service' || line.kind === 'package') setAssigningKey(line.key);
    },
  });

  const {
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
  } = useCheckout({ apiClient, cart, clientId, subtotalCents, hasServiceLine, appointmentId, appointmentVersion });

  const loadLists = useCallback(async () => {
    if (!canOperate) {
      setListsLoading(false);
      return;
    }
    setListsLoading(true);
    setListsError(null);
    try {
      const [professionalsRes, catalogRes, clientsRes] = await Promise.all([
        apiClient.get('/professionals?active=true'),
        apiClient.get('/catalog?active=true'),
        apiClient.get('/clients?active=true'),
      ]);
      setProfessionals(professionalsRes.professionals);
      setCatalogItems(catalogRes.items);
      setClients(clientsRes.clients);
    } catch (err) {
      setListsError(messageForError(err, { fallback: OFFLINE_FALLBACK }));
    } finally {
      setListsLoading(false);
    }
  }, [apiClient, canOperate]);

  useEffect(() => {
    loadLists();
  }, [loadLists]);

  // Pré-carrega a comanda a partir de um agendamento (docs/PWA_PLANEJAMENTO.md
  // §5.1/§5.2): cliente e o serviço do agendamento já entram no carrinho.
  // Não existe vínculo persistido appointment_id<->order no schema — é só
  // conveniência de UI; ao fechar, marcamos o agendamento como concluído
  // via uma segunda chamada independente (best-effort, não bloqueia o
  // fechamento se falhar).
  useEffect(() => {
    if (!appointmentId || !canOperate || listsLoading || catalogItems.length === 0) return;
    let cancelled = false;
    apiClient
      .get(`/appointments/${appointmentId}`)
      .then(({ appointment }) => {
        if (cancelled) return;
        setClientId(appointment.client_id);
        setAppointmentVersion(appointment.version);
        const service = catalogItems.find((item) => item.kind === 'service' && item.id === appointment.service_id);
        if (service) {
          setCart((current) => {
            if (current.some((line) => line.kind === 'service' && line.catalogId === service.id)) return current;
            return [
              ...current,
              {
                key: newLineKey(),
                kind: 'service',
                catalogId: service.id,
                name: service.name,
                unitPriceCents: service.price_cents,
                quantity: 1,
                professionalId: appointment.professional_id,
              },
            ];
          });
        }
      })
      .catch(() => {
        /* melhor esforço — se o agendamento não puder ser lido, a comanda segue avulsa */
      });
    return () => {
      cancelled = true;
    };
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [appointmentId, canOperate, listsLoading, catalogItems.length]);

  const filteredCatalog = useMemo(() => {
    const query = search.trim().toLowerCase();
    if (!query) return catalogItems;
    return catalogItems.filter((item) => item.name.toLowerCase().includes(query));
  }, [search, catalogItems]);

  const assigningLine = cart.find((line) => line.key === assigningKey) ?? null;

  function professionalName(id) {
    return professionals.find((professional) => professional.id === id)?.name ?? '—';
  }

  function handleClientCreated(client) {
    setClients((current) => [...current, client].sort((a, b) => a.name.localeCompare(b.name)));
  }

  function startNewComanda() {
    setClientId('');
    resetCart();
    resetCheckout();
    navigate('/comanda', { replace: true });
  }

  if (!canOperate) {
    return (
      <div className="comanda-page">
        <p>Seu papel não pode abrir ou fechar comandas nesta organização. Fale com a recepção ou gestão.</p>
      </div>
    );
  }

  const viewToggle = (
    <div className="agenda-view-toggle">
      <button type="button" className={view === 'nova' ? 'active' : ''} onClick={() => setView('nova')}>
        Nova comanda
      </button>
      <button type="button" className={view === 'historico' ? 'active' : ''} onClick={() => setView('historico')}>
        Comandas fechadas
      </button>
    </div>
  );

  if (view === 'historico') {
    return (
      <div className="comanda-page">
        <h1>Comanda</h1>
        {viewToggle}
        <OrderHistory apiClient={apiClient} canRefund={canRefund} />
      </div>
    );
  }

  if (listsLoading) return <p>Carregando comanda…</p>;

  if (listsError) {
    return (
      <div className="full-page-error">
        <p>{listsError}</p>
        <button type="button" onClick={loadLists}>
          Tentar novamente
        </button>
      </div>
    );
  }

  if (catalogItems.length === 0) {
    return <p>Nenhum item no catálogo ainda. Cadastre serviços ou produtos no módulo Catálogo para começar a vender.</p>;
  }

  if (step === 'closed' && closedOrder) {
    return (
      <div className="comanda-page comanda-closed">
        <h1>Comanda fechada</h1>
        {discountCents > 0 && <p>Desconto: −{formatCents(discountCents)}</p>}
        {tipCents > 0 && <p>Gorjeta: +{formatCents(tipCents)}</p>}
        <p>Total: {formatCents(closedOrder.total_cents)}</p>
        <p className="comanda-closed-id">Pedido #{closedOrder.order_id.slice(0, 8)}</p>
        <button type="button" onClick={startNewComanda}>
          Nova comanda
        </button>
      </div>
    );
  }

  if (step === 'payment') {
    return (
      <div className="comanda-page">
        <h1>Fechar comanda</h1>
        <p className="comanda-total">Subtotal: {formatCents(subtotalCents)}</p>

        <div className="comanda-discount-tip">
          <label>
            Desconto (R$)
            <input
              type="text"
              inputMode="decimal"
              aria-label="Desconto"
              value={discountReais}
              placeholder="0,00"
              onChange={(event) => setDiscountReais(event.target.value)}
            />
          </label>
          <label>
            Gorjeta (R$)
            <input
              type="text"
              inputMode="decimal"
              aria-label="Gorjeta"
              value={tipReais}
              placeholder="0,00"
              disabled={!hasServiceLine}
              onChange={(event) => setTipReais(event.target.value)}
            />
          </label>
        </div>
        {!discountValid && discountReais !== '' && (
          <p className="form-error">O desconto deve ser um valor entre 0 e o subtotal da comanda.</p>
        )}
        {!hasServiceLine && <p className="comanda-hint">Gorjeta só pode ser aplicada quando a comanda tem algum serviço.</p>}
        {hasServiceLine && !tipValid && tipReais !== '' && <p className="form-error">A gorjeta não pode ser negativa.</p>}

        <p className="comanda-total">Total a pagar: {formatCents(finalTotalCents)}</p>

        {payments.map((payment) => (
          <div className="comanda-payment-row" key={payment.key}>
            <select value={payment.method} onChange={(event) => updatePayment(payment.key, { method: event.target.value })}>
              {PAYMENT_METHODS.map((method) => (
                <option key={method.value} value={method.value}>
                  {method.label}
                </option>
              ))}
            </select>
            <input
              type="text"
              inputMode="decimal"
              aria-label="Valor do pagamento"
              value={payment.amountReais}
              onChange={(event) => updatePayment(payment.key, { amountReais: event.target.value })}
            />
            <button type="button" className="link-button" onClick={() => fillRemaining(payment.key)}>
              Preencher restante
            </button>
            {payments.length > 1 && (
              <button type="button" className="link-button" onClick={() => removePaymentLine(payment.key)}>
                Remover
              </button>
            )}
          </div>
        ))}
        <button type="button" className="link-button" onClick={addPaymentLine}>
          + Forma de pagamento (dividir conta)
        </button>

        <p className="comanda-payments-sum">
          Pagamentos: {formatCents(paymentsTotalCents)} {!paymentsReconcile && '— não bate com o total'}
        </p>

        {checkoutError && <p className="form-error">{checkoutError}</p>}

        <div className="modal-actions">
          <button type="button" className="link-button" onClick={backToBuilding} disabled={submitting}>
            Voltar para itens
          </button>
          <button type="button" disabled={!canClose || submitting} onClick={handleClose}>
            {submitting ? 'Fechando…' : 'Confirmar fechamento'}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="comanda-page">
      <h1>Comanda</h1>
      {viewToggle}

      <ClientPicker
        clients={clients}
        value={clientId}
        onChange={setClientId}
        apiClient={apiClient}
        onClientCreated={handleClientCreated}
        disabled={false}
        noneLabel="Cliente avulso (sem cadastro)"
      />

      <div className="comanda-catalog">
        <input
          type="text"
          placeholder="Buscar serviço, produto ou pacote"
          value={search}
          onChange={(event) => setSearch(event.target.value)}
        />
        <ul className="comanda-catalog-list">
          {filteredCatalog.map((item) => (
            <li key={`${item.kind}-${item.id}`}>
              <span>
                {item.name} · {formatCents(item.price_cents)}
                {item.kind === 'product' && item.stock_on_hand !== undefined && ` · estoque: ${item.stock_on_hand}`}
              </span>
              <button type="button" onClick={() => (item.kind === 'package' ? addPackage(item) : addServiceOrProduct(item))}>
                + Adicionar
              </button>
            </li>
          ))}
        </ul>
      </div>

      <div className="comanda-cart">
        <h2>Itens da comanda</h2>
        {cart.length === 0 && <p className="comanda-cart-empty">Nenhum item adicionado ainda.</p>}
        {cart.map((line) => (
          <div className="comanda-cart-line" key={line.key}>
            <div className="comanda-cart-line-header">
              <strong>{line.name}</strong>
              <span>{formatCents(line.kind === 'package' ? line.unitPriceCents : line.unitPriceCents * line.quantity)}</span>
              <button type="button" className="link-button" onClick={() => removeLine(line.key)}>
                Remover
              </button>
            </div>

            {line.kind !== 'package' && (
              <div className="comanda-cart-line-controls">
                <button type="button" onClick={() => updateLineQuantity(line.key, -1)} aria-label={`Diminuir quantidade de ${line.name}`}>
                  −
                </button>
                <span>{line.quantity}</span>
                <button type="button" onClick={() => updateLineQuantity(line.key, 1)} aria-label={`Aumentar quantidade de ${line.name}`}>
                  +
                </button>
                {line.stockOnHand !== undefined && line.quantity > line.stockOnHand && (
                  <span className="form-error">acima do estoque disponível ({line.stockOnHand})</span>
                )}
              </div>
            )}

            {line.kind === 'service' && (
              <div className="comanda-cart-line-assignment">
                <span>{line.professionalId ? `Profissional: ${professionalName(line.professionalId)}` : 'Profissional não atribuído'}</span>
                <button type="button" className="link-button" onClick={() => setAssigningKey(line.key)}>
                  Atribuir profissional
                </button>
              </div>
            )}

            {line.kind === 'package' && (
              <div className="comanda-cart-line-assignment">
                <span>
                  {line.components.every((component) => Boolean(component.professionalId))
                    ? 'Profissionais atribuídos'
                    : 'Profissionais pendentes'}
                </span>
                <button type="button" className="link-button" onClick={() => setAssigningKey(line.key)}>
                  Atribuir profissionais
                </button>
              </div>
            )}
          </div>
        ))}
      </div>

      <p className="comanda-total">Total: {formatCents(subtotalCents)}</p>

      <button type="button" disabled={!cartIsReady} onClick={goToPayment}>
        Fechar comanda
      </button>

      {assigningLine && (
        <Modal onClose={() => setAssigningKey(null)}>
          <h2>Atribuir profissional — {assigningLine.name}</h2>

          {assigningLine.kind === 'service' && (
            <label>
              Profissional
              <select
                aria-label={`Profissional para ${assigningLine.name}`}
                value={assigningLine.professionalId}
                onChange={(event) => setLineProfessional(assigningLine.key, event.target.value)}
              >
                <option value="">Selecione um profissional</option>
                {professionals.map((professional) => (
                  <option key={professional.id} value={professional.id}>
                    {professional.name}
                  </option>
                ))}
              </select>
            </label>
          )}

          {assigningLine.kind === 'package' && (
            <div className="comanda-package-components">
              {assigningLine.components.map((component) => (
                <label key={component.serviceId}>
                  {component.serviceName}
                  <select
                    aria-label={`Profissional para ${component.serviceName} (${assigningLine.name})`}
                    value={component.professionalId}
                    onChange={(event) => setPackageComponentProfessional(assigningLine.key, component.serviceId, event.target.value)}
                  >
                    <option value="">Selecione um profissional</option>
                    {professionals.map((professional) => (
                      <option key={professional.id} value={professional.id}>
                        {professional.name}
                      </option>
                    ))}
                  </select>
                </label>
              ))}
            </div>
          )}

          <div className="modal-actions">
            <button type="button" onClick={() => setAssigningKey(null)}>
              Concluir
            </button>
          </div>
        </Modal>
      )}
    </div>
  );
}
