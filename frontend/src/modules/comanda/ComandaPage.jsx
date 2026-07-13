import { useCallback, useEffect, useMemo, useState } from 'react';
import { useNavigate, useSearchParams } from 'react-router-dom';
import { ApiError } from '../../shared/apiClient.js';
import { useApiClient } from '../../shared/useApiClient.js';
import { useOrganization } from '../../shared/OrganizationContext.jsx';
import { ClientPicker } from '../../shared/ClientPicker.jsx';
import { formatCents, reaisToCents } from '../../shared/money.js';
import { messageForCheckoutError } from './comandaErrors.js';

// Mirrors backend/src/modules/checkout/checkout.route.js CHECKOUT_ROLES and
// orders.route.js READ_ROLES — professional is deliberately excluded from
// both (checkout_close's actor_has_role never included it), so this module
// is read-only-unavailable for that role, not something invented here.
const OPERATE_ROLES = ['owner', 'admin', 'manager', 'reception'];
const PAYMENT_METHODS = [
  { value: 'cash', label: 'Dinheiro' },
  { value: 'pix', label: 'Pix' },
  { value: 'debit_card', label: 'Cartão de débito' },
  { value: 'credit_card', label: 'Cartão de crédito' },
  { value: 'other', label: 'Outro' },
];

function messageForListError(err) {
  if (err instanceof ApiError) return err.message;
  return 'Sem conexão. Verifique sua internet e tente novamente.';
}

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

  const [listsLoading, setListsLoading] = useState(true);
  const [listsError, setListsError] = useState(null);
  const [professionals, setProfessionals] = useState([]);
  const [catalogItems, setCatalogItems] = useState([]);
  const [clients, setClients] = useState([]);

  const [clientId, setClientId] = useState('');
  const [cart, setCart] = useState([]);
  const [search, setSearch] = useState('');

  const [step, setStep] = useState('building'); // 'building' | 'payment' | 'closed'
  const [idempotencyKey, setIdempotencyKey] = useState(null);
  const [payments, setPayments] = useState([]);
  const [submitting, setSubmitting] = useState(false);
  const [checkoutError, setCheckoutError] = useState(null);
  const [closedOrder, setClosedOrder] = useState(null);

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
      setListsError(messageForListError(err));
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

  const subtotalCents = useMemo(
    () => cart.reduce((sum, line) => sum + (line.kind === 'package' ? line.unitPriceCents : line.unitPriceCents * line.quantity), 0),
    [cart],
  );

  const paymentsWithCents = useMemo(
    () => payments.map((payment) => ({ ...payment, amountCents: reaisToCents(payment.amountReais) })),
    [payments],
  );

  const paymentsTotalCents = useMemo(
    () => paymentsWithCents.reduce((sum, payment) => sum + (payment.amountCents ?? 0), 0),
    [paymentsWithCents],
  );

  const cartIsReady =
    cart.length > 0 &&
    cart.every((line) => {
      if (line.kind === 'service') return Boolean(line.professionalId);
      if (line.kind === 'package') return line.components.every((component) => Boolean(component.professionalId));
      return true;
    });

  function handleClientCreated(client) {
    setClients((current) => [...current, client].sort((a, b) => a.name.localeCompare(b.name)));
  }

  function addServiceOrProduct(item) {
    setCart((current) => {
      const existing = current.find((line) => line.kind === item.kind && line.catalogId === item.id);
      if (existing) {
        return current.map((line) => (line === existing ? { ...line, quantity: line.quantity + 1 } : line));
      }
      return [
        ...current,
        {
          key: newLineKey(),
          kind: item.kind,
          catalogId: item.id,
          name: item.name,
          unitPriceCents: item.price_cents,
          quantity: 1,
          professionalId: item.kind === 'service' ? '' : undefined,
          stockOnHand: item.kind === 'product' ? item.stock_on_hand : undefined,
        },
      ];
    });
  }

  async function addPackage(item) {
    const { package: pkg } = await apiClient.get(`/packages/${item.id}`);
    const components = pkg.items.map((packageItem) => {
      const service = catalogItems.find((catalogItem) => catalogItem.kind === 'service' && catalogItem.id === packageItem.service_id);
      return { serviceId: packageItem.service_id, serviceName: service?.name ?? 'Serviço', professionalId: '' };
    });
    setCart((current) => [
      ...current,
      {
        key: newLineKey(),
        kind: 'package',
        catalogId: item.id,
        name: item.name,
        unitPriceCents: item.price_cents,
        components,
      },
    ]);
  }

  function updateLineQuantity(key, delta) {
    setCart((current) =>
      current
        .map((line) => (line.key === key ? { ...line, quantity: line.quantity + delta } : line))
        .filter((line) => line.kind === 'package' || line.quantity > 0),
    );
  }

  function removeLine(key) {
    setCart((current) => current.filter((line) => line.key !== key));
  }

  function setLineProfessional(key, professionalId) {
    setCart((current) => current.map((line) => (line.key === key ? { ...line, professionalId } : line)));
  }

  function setPackageComponentProfessional(key, serviceId, professionalId) {
    setCart((current) =>
      current.map((line) =>
        line.key === key
          ? {
              ...line,
              components: line.components.map((component) =>
                component.serviceId === serviceId ? { ...component, professionalId } : component,
              ),
            }
          : line,
      ),
    );
  }

  function goToPayment() {
    setIdempotencyKey(crypto.randomUUID());
    setPayments([{ key: newLineKey(), method: 'cash', amountReais: (subtotalCents / 100).toFixed(2) }]);
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
    const remaining = subtotalCents - (paymentsTotalCents - current);
    updatePayment(key, { amountReais: (Math.max(remaining, 0) / 100).toFixed(2) });
  }

  const paymentsReconcile =
    paymentsWithCents.length > 0 &&
    paymentsWithCents.every((payment) => Number.isInteger(payment.amountCents) && payment.amountCents > 0) &&
    paymentsWithCents.reduce((sum, payment) => sum + payment.amountCents, 0) === subtotalCents;

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
      };
      const result = await apiClient.post('/checkout', body, { headers: { 'Idempotency-Key': idempotencyKey } });
      setClosedOrder(result);
      setStep('closed');
      if (appointmentId) {
        apiClient.patch(`/appointments/${appointmentId}`, { status: 'completed' }).catch(() => {
          /* melhor esforço — não bloqueia a comanda já fechada */
        });
      }
    } catch (err) {
      setCheckoutError(messageForCheckoutError(err));
    } finally {
      setSubmitting(false);
    }
  }

  function startNewComanda() {
    setClientId('');
    setCart([]);
    setPayments([]);
    setIdempotencyKey(null);
    setCheckoutError(null);
    setClosedOrder(null);
    setStep('building');
    navigate('/comanda', { replace: true });
  }

  if (!canOperate) {
    return (
      <div className="comanda-page">
        <p>Seu papel não pode abrir ou fechar comandas nesta organização. Fale com a recepção ou gestão.</p>
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
        <p className="comanda-total">Total a pagar: {formatCents(subtotalCents)}</p>

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
          <button type="button" disabled={!paymentsReconcile || submitting} onClick={handleClose}>
            {submitting ? 'Fechando…' : 'Confirmar fechamento'}
          </button>
        </div>
      </div>
    );
  }

  return (
    <div className="comanda-page">
      <h1>Comanda</h1>

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
              <select
                aria-label={`Profissional para ${line.name}`}
                value={line.professionalId}
                onChange={(event) => setLineProfessional(line.key, event.target.value)}
              >
                <option value="">Selecione um profissional</option>
                {professionals.map((professional) => (
                  <option key={professional.id} value={professional.id}>
                    {professional.name}
                  </option>
                ))}
              </select>
            )}

            {line.kind === 'package' && (
              <div className="comanda-package-components">
                {line.components.map((component) => (
                  <label key={component.serviceId}>
                    {component.serviceName}
                    <select
                      aria-label={`Profissional para ${component.serviceName} (${line.name})`}
                      value={component.professionalId}
                      onChange={(event) => setPackageComponentProfessional(line.key, component.serviceId, event.target.value)}
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
          </div>
        ))}
      </div>

      <p className="comanda-total">Total: {formatCents(subtotalCents)}</p>

      <button type="button" disabled={!cartIsReady} onClick={goToPayment}>
        Fechar comanda
      </button>
    </div>
  );
}
