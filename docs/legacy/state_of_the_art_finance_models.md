# Modelos de Arquitetura Financeira (State of the Art)

Abaixo estão as implementações em JavaScript (Node.js) focadas nos padrões arquiteturais globais de ponta para ecossistemas financeiros (Double-Entry Ledgers, State Machines, Idempotência e Escrow/Splits).

Você pode utilizá-los como fundação conceitual para o seu novo projeto.

---

## 1. Ledger (Contabilidade de Partidas Dobradas)
O padrão ouro exige que o saldo não seja um número solto no banco de dados, mas sim a soma de todas as transações (Entradas de Diário / Journal Entries). E o mais importante: a soma de todas as entradas de uma transação deve ser estritamente zero.

```javascript
// ledger.js

class Ledger {
  constructor() {
    this.transactions = []; // Tabela: transactions (id, timestamp, metadata)
    this.entries = [];      // Tabela: journal_entries (id, transaction_id, account_id, amount, type)
  }

  /**
   * Registra uma transação garantindo atomicidade e partidas dobradas
   */
  postTransaction(referenceId, entriesPayload) {
    // 1. Validação de Partida Dobrada (Soma de todos os débitos e créditos DEVE ser ZERO)
    const sum = entriesPayload.reduce((acc, entry) => acc + entry.amount, 0);
    
    if (sum !== 0) {
      throw new Error(`Double-Entry Violation: A transação não está balanceada. Diferença de ${sum} centavos.`);
    }

    // 2. Criar Transação (Imutável)
    const transactionId = `txn_${Date.now()}_${Math.floor(Math.random() * 1000)}`;
    const transaction = {
      id: transactionId,
      referenceId,
      createdAt: new Date().toISOString()
    };
    
    // 3. Gerar Entradas (Imutáveis)
    const entries = entriesPayload.map(entry => ({
      id: `entry_${Date.now()}_${Math.floor(Math.random() * 1000)}`,
      transactionId,
      accountId: entry.accountId,
      amount: entry.amount, // Positivo (Crédito) ou Negativo (Débito)
      type: entry.amount > 0 ? 'CREDIT' : 'DEBIT',
      description: entry.description
    }));

    // Simula commit no banco de dados
    this.transactions.push(transaction);
    this.entries.push(...entries);

    return transaction;
  }

  /**
   * O saldo é DERIVADO, nunca armazenado diretamente
   */
  getDerivedBalance(accountId) {
    const accountEntries = this.entries.filter(e => e.accountId === accountId);
    return accountEntries.reduce((acc, entry) => acc + entry.amount, 0);
  }
}

module.exports = { Ledger };
```

---

## 2. Template-Driven Posting (e Escrow/Split)
Em vez de espalhar lógicas de "quem recebe quanto" pelo código inteiro, nós definimos templates e mapeamos as contas transitórias (Escrow / Custódia).

```javascript
// templateEngine.js
const { Ledger } = require('./ledger');
const ledger = new Ledger();

// Template de uma Venda em Marketplace/Salão (Split Payment)
const TEMPLATE_VENDA_COMISSIONADA = {
  name: 'VENDA_COMISSIONADA',
  generateEntries: (data) => {
    // Data = { amount: 10000, commissionAmount: 2000, professionalId: 'prof_1', clientId: 'cli_1' }
    const companyRevenue = data.amount - data.commissionAmount;
    
    return [
      // Cliente perde dinheiro (Débito)
      { accountId: `account_cliente_${data.clientId}`, amount: -data.amount, description: 'Pagamento de Serviço' },
      
      // Dinheiro entra na conta transitória da plataforma (Clearing/Escrow)
      { accountId: 'account_escrow_plataforma', amount: data.amount, description: 'Custódia Temporária' },
      
      // Imediatamente o sistema divide (Split): 
      // 1. Tira da conta de Custódia
      { accountId: 'account_escrow_plataforma', amount: -data.amount, description: 'Liquidação de Split' },
      // 2. Credita a Receita da Plataforma (Lucro)
      { accountId: 'account_receita_empresa', amount: companyRevenue, description: 'Taxa da Plataforma/Salão' },
      // 3. Credita o Profissional (A Pagar)
      { accountId: `account_payable_${data.professionalId}`, amount: data.commissionAmount, description: 'Comissão do Profissional' }
    ];
  }
};

// Executando o Template
function processSale(clientId, professionalId, totalValueCents, professionalCommissionCents) {
  const entries = TEMPLATE_VENDA_COMISSIONADA.generateEntries({
    amount: totalValueCents,
    commissionAmount: professionalCommissionCents,
    professionalId,
    clientId
  });

  return ledger.postTransaction(`order_12345`, entries);
}
```

---

## 3. Máquina de Estados Finita (FSM) para Pagamentos
Evita que uma cobrança seja estornada antes de ser capturada, ou que uma falha altere o status de um pagamento já processado.

```javascript
// stateMachine.js

class PaymentStateMachine {
  constructor(paymentId, initialAmount) {
    this.paymentId = paymentId;
    this.amount = initialAmount;
    this.status = 'PENDING';
    
    // Regras Estritas de Transição de Estado
    this.transitions = {
      'PENDING': ['AUTHORIZED', 'FAILED'],
      'AUTHORIZED': ['CAPTURED', 'VOIDED', 'FAILED'],
      'CAPTURED': ['SETTLED', 'REFUNDED'],
      'SETTLED': ['REFUNDED'],
      'FAILED': [],
      'VOIDED': [],
      'REFUNDED': []
    };
  }

  transitionTo(newStatus) {
    const allowedTransitions = this.transitions[this.status];
    
    if (!allowedTransitions.includes(newStatus)) {
      throw new Error(`Invalid Transition: Não é possível mudar o pagamento de ${this.status} para ${newStatus}`);
    }
    
    console.log(`[Pagamento ${this.paymentId}] Status alterado: ${this.status} -> ${newStatus}`);
    this.status = newStatus;
  }

  // Exemplos de ações do Gateway de Pagamento
  authorize() {
    // Chama a API do Gateway
    this.transitionTo('AUTHORIZED');
  }

  capture() {
    this.transitionTo('CAPTURED');
    // Aciona o Ledger.postTransaction()
  }

  refund() {
    this.transitionTo('REFUNDED');
    // Aciona um novo Ledger template de estorno
  }
}
```

---

## 4. Idempotência em APIs Financeiras
Impede processamento duplicado (ex: o cliente apertou "Pagar" 2x seguidas, ou a internet caiu durante a resposta).

```javascript
// idempotency.js

class IdempotencyStore {
  constructor() {
    this.store = new Map(); // Num cenário real, isso seria um Redis (chave-valor rápido)
  }

  /**
   * Middleware/Wrapper para funções financeiras perigosas
   */
  async executeIdempotent(idempotencyKey, actionFn) {
    if (!idempotencyKey) throw new Error('Idempotency Key é obrigatória em APIs financeiras.');

    // 1. Verifica se essa chave já foi processada
    if (this.store.has(idempotencyKey)) {
      const cached = this.store.get(idempotencyKey);
      
      if (cached.status === 'IN_PROGRESS') {
        throw new Error('Conflito: Já existe uma requisição em andamento para esta chave.');
      }
      
      // Retorna o resultado salvo sem executar novamente
      console.log(`[Idempotency] Requisição duplicada interceptada. Retornando cache para ${idempotencyKey}`);
      return cached.response;
    }

    // 2. Trava a chave (Lock)
    this.store.set(idempotencyKey, { status: 'IN_PROGRESS' });

    try {
      // 3. Executa a ação real (ex: cobrar no cartão)
      const result = await actionFn();

      // 4. Salva a resposta no cache
      this.store.set(idempotencyKey, { status: 'COMPLETED', response: result });
      return result;
      
    } catch (error) {
      // Se falhou por erro de validação (ex: sem saldo), podemos apagar ou marcar como falho
      this.store.set(idempotencyKey, { status: 'FAILED', error: error.message });
      throw error;
    }
  }
}

// Exemplo de uso num Endpoint (Express.js / Node):
const idempotencyStore = new IdempotencyStore();

async function handleCheckoutRequest(req, res) {
  const { idempotencyKey, amount } = req.body;

  try {
    const result = await idempotencyStore.executeIdempotent(idempotencyKey, async () => {
       // ... chama o gateway, 
       // ... roda a state machine, 
       // ... grava no ledger
       return { success: true, transactionId: 'txn_123', charged: amount };
    });
    
    res.json(result);
  } catch (error) {
    res.status(400).json({ error: error.message });
  }
}
```
