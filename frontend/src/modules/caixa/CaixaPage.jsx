import { useCallback, useEffect, useMemo, useState } from 'react';
import { useApiClient } from '../../shared/useApiClient.js';
import { useOrganization } from '../../shared/useOrganization.js';
import { formatCents } from '../../shared/money.js';
import { messageForError, OFFLINE_FALLBACK } from '../../shared/apiErrorMessage.js';
import { ManualEntryModal } from './ManualEntryModal.jsx';
import { Button } from '../../ui/primitives/Button.jsx';
import { Input } from '../../ui/primitives/Input.jsx';
import { Select } from '../../ui/primitives/Select.jsx';
import { PageSkeleton } from '../../ui/primitives/PageSkeleton.jsx';
import './CaixaPage.css';

// Mirrors backend/src/modules/cashEntries/cashEntries.route.js READ_ROLES
// (owner/admin/manager) — reception has 'caixa' in nav.js (recepção também
// baixa no caixa) mas nunca esteve no allowlist de leitura de cash_entries,
// então o módulo mostra indisponibilidade em vez de tentar a chamada.
const READ_ROLES = ['owner', 'admin', 'manager'];
// Mirrors cash_entry_manual's internal actor_has_role check (WRITE_ROLES em
// cashEntries.route.js) — mesmo conjunto de READ_ROLES nesta rota.
const WRITE_ROLES = ['owner', 'admin', 'manager'];

const KIND_LABELS = { sale: 'Venda', income: 'Entrada', expense: 'Saída', refund: 'Estorno' };
const KIND_OPTIONS = [
  { value: '', label: 'Todos os tipos' },
  { value: 'sale', label: 'Venda' },
  { value: 'income', label: 'Entrada' },
  { value: 'expense', label: 'Saída' },
  { value: 'refund', label: 'Estorno' },
];


function kindLabel(kind) {
  return KIND_LABELS[kind] ?? kind;
}

// Fase 9 (docs/adr/0006-gorjeta-fora-da-comissao-e-motivo-do-estorno.md):
// cash_entry_manual permite lançamento avulso de income/expense; estorno
// ('refund') continua exclusivo de order_refund a partir de uma comanda
// fechada (módulo Comanda), nunca lançado manualmente aqui.
export function CaixaPage() {
  const { role } = useOrganization();
  const apiClient = useApiClient();
  const canRead = READ_ROLES.includes(role);
  const canWrite = WRITE_ROLES.includes(role);

  const [entries, setEntries] = useState([]);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState(null);
  const [kindFilter, setKindFilter] = useState('');
  const [fromDate, setFromDate] = useState('');
  const [toDate, setToDate] = useState('');
  const [showManualEntry, setShowManualEntry] = useState(false);

  const load = useCallback(async () => {
    if (!canRead) {
      setLoading(false);
      return;
    }
    setLoading(true);
    setError(null);
    try {
      const query = kindFilter ? `?kind=${kindFilter}` : '';
      const { cash_entries: data } = await apiClient.get(`/cash-entries${query}`);
      setEntries(data);
    } catch (err) {
      setError(messageForError(err, { fallback: OFFLINE_FALLBACK }));
    } finally {
      setLoading(false);
    }
  }, [apiClient, canRead, kindFilter]);

  useEffect(() => {
    load();
  }, [load]);

  // A API não tem parâmetro de período — filtro de data é só no cliente,
  // sobre o que já foi carregado (nenhum dado financeiro é tratado como mais
  // atual do que a última revalidação).
  const filteredEntries = useMemo(() => {
    return entries.filter((entry) => {
      const createdAt = new Date(entry.created_at);
      if (fromDate && createdAt < new Date(`${fromDate}T00:00:00`)) return false;
      if (toDate && createdAt > new Date(`${toDate}T23:59:59`)) return false;
      return true;
    });
  }, [entries, fromDate, toDate]);

  const totalCents = filteredEntries.reduce((sum, entry) => sum + entry.amount_cents, 0);

  if (!canRead) {
    return (
      <div className="caixa-page">
        <p>Seu papel não pode visualizar o caixa nesta organização.</p>
      </div>
    );
  }

  if (loading) {
    return (
      <div className="caixa-page">
        <h1>Caixa</h1>
        <PageSkeleton />
      </div>
    );
  }

  if (error) {
    return (
      <div className="full-page-error">
        <p>{error}</p>
        <Button onClick={load}>Tentar novamente</Button>
      </div>
    );
  }

  return (
    <div className="caixa-page">
      <h1>Caixa</h1>

      <div className="list-toolbar">
        <Select aria-label="Filtrar por tipo" value={kindFilter} onChange={(event) => setKindFilter(event.target.value)}>
          {KIND_OPTIONS.map((option) => (
            <option key={option.value} value={option.value}>
              {option.label}
            </option>
          ))}
        </Select>
        <Input label="De" type="date" aria-label="Data inicial" value={fromDate} onChange={(event) => setFromDate(event.target.value)} />
        <Input label="Até" type="date" aria-label="Data final" value={toDate} onChange={(event) => setToDate(event.target.value)} />
        {canWrite && (
          <Button onClick={() => setShowManualEntry(true)}>
            + Novo lançamento
          </Button>
        )}
      </div>

      <p className="comanda-total">Total no período: {formatCents(totalCents)}</p>

      {filteredEntries.length === 0 && <p className="list-empty">Nenhum lançamento encontrado.</p>}

      <ul className="record-list">
        {filteredEntries.map((entry) => (
          <li key={entry.id} className="record-list-item">
            <span className="record-list-main">
              <strong>{formatCents(entry.amount_cents)}</strong>
              <span>
                {kindLabel(entry.kind)}
                {entry.description ? ` · ${entry.description}` : ''} · {new Date(entry.created_at).toLocaleString('pt-BR')}
              </span>
            </span>
          </li>
        ))}
      </ul>

      {showManualEntry && (
        <ManualEntryModal
          apiClient={apiClient}
          onClose={() => setShowManualEntry(false)}
          onCreated={() => {
            setShowManualEntry(false);
            load();
          }}
        />
      )}
    </div>
  );
}
