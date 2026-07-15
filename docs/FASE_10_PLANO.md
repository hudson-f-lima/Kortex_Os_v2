# Fase 10 — Capacidades N:N profissional×serviço + Hardening do Agendamento

**Objetivo**: Permitir que profissionais tenham capacidades diferentes para cada serviço (duração customizada, buffers de transição, preço customizado) e endurecer o módulo de agendamento contra integridade de dados.

## Entregas

### 1. **Migrations SQL**

#### 1.1 Migration: Tabela `professional_service_capabilities`
- Campos:
  - `organization_id` (FK)
  - `professional_id` (FK)
  - `service_id` (FK)
  - `duration_override_minutes` (nullable — NULL = usar `services.duration_minutes`)
  - `buffer_before_min` (default 0)
  - `buffer_after_min` (default 0)
  - `price_override_cents` (nullable — NULL = usar `services.price_cents`)
  - `active` (default true)
  - `created_at`, `updated_at`
  - UNIQUE (organization_id, professional_id, service_id)
- RLS: mesmo padrão de `professionals`/`services`

#### 1.2 Migration: Hardening de `appointments`
- Adicionar coluna `version` (bigint NOT NULL DEFAULT 1)
- Adicionar CHECK constraint para guard FSM (status transitions — `completed` é terminal, só reverter com privilégio)
- Remover aceitação de `ends_at` do cliente: sempre calculado servidor-side
- Trigger de `lock_otimista`: UPDATE falha se `version` divergir

### 2. **Backend**

#### 2.1 Módulo `professionalServiceCapabilities`
- Arquivo: `backend/src/modules/professionalServiceCapabilities/`
- Rotas:
  - `GET /api/v1/professional-service-capabilities` (filtro por professional_id/service_id)
  - `POST /api/v1/professional-service-capabilities` (criar)
  - `PATCH /api/v1/professional-service-capabilities/:id` (editar)
  - `DELETE /api/v1/professional-service-capabilities/:id` (deletar)
- Validação: referências cross-org, duração/preço válidos

#### 2.2 Módulo `appointments` — atualização
- Remover suporte a `ends_at` do payload (sempre calculado)
- Ajustar RPC `checkout_close` para rejeitar qualquer duração do cliente
- Adicionar validação de status_guard (completed é imutável, salvo reversão privilegiada)

### 3. **Frontend**

#### 3.1 Módulo Equipe — Nova aba "Capacidades"
- `CapabilitiesTab.jsx`: listagem por profissional
- `CapabilityModal.jsx`: criar/editar capability
- Validação client-side espelhando backend

#### 3.2 Agenda — Considerar capabilities ao renderizar
- Ao carregar `GET /professionals`, também carregar capabilities
- Duração e preço refletem override se existir
- (Opcional para Fase 10, prioridade baixa): filtro por capability

### 4. **Testes**

#### 4.1 pgTAP
- Arquivo: `supabase/tests/rls_professional_service_capabilities_test.sql`
- Validações:
  - RLS por papel (`owner`/`admin`/`manager` read+write, `reception`/`professional` read-only)
  - Cross-org bloqueado
  - Duplicata rejeitada
  - FK inválida (professional/service inativo) rejeitada
  - Lock otimista (version conflict)
  - Guard FSM (completed imutável, salvo reversão)

#### 4.2 Backend
- Integração: CRUD completo, validação de referências, cross-org
- 25+ testes novos

#### 4.3 Frontend
- `CapabilitiesTab.jsx`: render, create, edit, delete
- Testes de validação (duração/preço positivos, referência inválida)

## Gate de Saída

- [ ] pgTAP 100% PASS (151 → ~175 testes)
- [ ] Backend 208 → ~235 testes
- [ ] Frontend capabilities tab renderizando e CRUD funcional
- [ ] Agenda refletindo override de duração/preço
- [ ] Red team: versão conflict bloqueado, completed status rejeitado para update
- [ ] End-to-end: criar professional → adicionar capability → agenda reflete duração override

## Ordem de Execução

1. **Migrations** (SQL)
2. **Backend** (módulo novo + updates em appointments)
3. **Frontend** (tab em Equipe)
4. **Testes** (pgTAP + integração + UI)
5. **Verificação end-to-end**
