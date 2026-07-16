# KORTEXOS — LOCAL PROJECTION CACHE & INCREMENTAL SYNC

## Objetivo

Garantir abertura praticamente instantânea do PWA sem violar o princípio de que **o backend é a única fonte da verdade**.

## Invariantes

* Backend é a única fonte da verdade (SSOT).
* Frontend nunca calcula regras críticas.
* Cache local é apenas uma projeção operacional.
* Toda mutação crítica é validada pelo backend.
* Sincronização deve ser incremental, idempotente e observável.

## Arquitetura

```text
Backend (SSOT)
        │
        ▼
Incremental Sync Engine
        │
        ▼
Local Projection Cache (IndexedDB)
        │
        ▼
Memory Cache
        │
        ▼
UI
```

## Política

Na inicialização:

1. carregar imediatamente a interface;
2. carregar dados da Local Projection Cache;
3. renderizar a UI sem aguardar a rede;
4. iniciar sincronização silenciosa em segundo plano;
5. aplicar apenas alterações recebidas;
6. atualizar automaticamente a interface.

## Não permitido

* copiar todo o banco para memória;
* manter duas fontes de verdade;
* calcular disponibilidade, preço, comissão ou regras críticas localmente;
* sobrescrever dados locais sem validação de versão.

## Dados elegíveis para cache

Permitir:

* agenda recente;
* agenda futura configurável;
* profissionais;
* clientes recentes;
* catálogo de serviços;
* produtos;
* configurações;
* permissões;
* dashboards projetados.

Não permitir:

* ledger completo;
* histórico financeiro integral;
* auditorias completas;
* logs;
* tabelas de grande volume sem necessidade operacional.

## Estratégia de sincronização

Utilizar somente sincronização incremental.

Fluxo:

```text
lastSync
        │
        ▼
Backend identifica alterações
        │
        ▼
retorna somente deltas
        │
        ▼
Projection Cache é atualizado
        │
        ▼
UI recebe atualização silenciosa
```

Sempre preferir eventos e deltas em vez de recarga completa.

## Atualizações em tempo real

Sempre que disponível:

* WebSocket;
* Supabase Realtime;
* SSE;
* mecanismo equivalente.

Receber apenas eventos de alteração.

Exemplos:

```text
AppointmentCreated
AppointmentUpdated
AppointmentCancelled
CustomerUpdated
ProfessionalUpdated
PaymentConfirmed
InventoryChanged
```

## Política Offline

Enquanto offline:

* consultas utilizam Projection Cache;
* comandos ficam em fila quando permitido;
* operações críticas aguardam validação do backend;
* nenhuma confirmação definitiva ocorre offline.

## Observabilidade

Monitorar:

* tempo de abertura;
* tempo de sincronização;
* quantidade de deltas;
* tamanho do cache;
* conflitos;
* falhas de sincronização;
* taxa de acerto do cache.

## Critérios de aceite

A solução somente é aprovada se:

* abertura do PWA ocorrer utilizando Projection Cache;
* sincronização for incremental;
* backend permanecer como única autoridade;
* nenhuma regra crítica existir apenas no frontend;
* sincronização for idempotente;
* inconsistências forem detectáveis e recuperáveis;
* atualização da interface ocorrer sem recarga completa.

## Decisão Canônica

**Adotar Local Projection Cache sincronizado por deltas/eventos como arquitetura padrão de desempenho do KortexOS.**

**É proibido copiar integralmente o banco de dados para memória ou criar qualquer segunda fonte de verdade.**
