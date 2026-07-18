# 14. Fase 11 — Convite de Equipe por E-mail: Provedor SMTP e Expiração (Accepted)

Date: 2026-07-17
Accepted: 2026-07-18

## Status

**Accepted.** Resolve 2 das 3 "Decisões em aberto" da Fase 11 (`docs/PLANEJAMENTO_EXECUCAO_UNIFICADO.md §Fase 11`). A terceira ("profissional pode enxergar comanda inteira ou só seus serviços") foi explicitamente adiada pelo usuário para uma fase futura — RLS de `orders`/`order_items` já bloqueia `professional` por completo hoje (`orders_select`/`order_items_select` não incluem esse papel no allowlist), então não há regressão em não decidir isso agora.

## Context

Fase 11 exige enviar e-mail real de convite (`auth.admin.inviteUserByEmail`). O mailer default do Supabase é rate-limited e a própria documentação diz que não é para uso em produção — precisa de SMTP customizado configurado no Dashboard do projeto (não é código de aplicação, é configuração de infraestrutura). O usuário confirmou que ainda não tem domínio próprio de e-mail.

## Pesquisa

### Provedor de SMTP

A documentação oficial do Supabase ([Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)) lista, sem eleger um "recomendado", seis provedores compatíveis: Resend, AWS SES, Postmark, Twilio SendGrid, ZeptoMail, Brevo.

| Provedor | Free tier | Setup com Supabase | Preço 1º tier pago |
|---|---|---|---|
| **Resend** | 3.000 e-mails/mês (100/dia) | Guia de integração dedicado com Supabase | ~$20/mês (50k e-mails) |
| **Brevo** | 300 e-mails/dia (~9.000/mês) — maior volume free | Genérico | ~$25/mês |
| **Postmark** | Só trial (100 e-mails) | Genérico | $15/mês (10k e-mails) |
| **SendGrid** | 100/dia por 60 dias, depois paga | Genérico | ~$19,95/mês |
| **AWS SES** | Só 1.000/mês se enviado de dentro da AWS | Setup mais complexo (IAM, sandbox mode, verificação) | ~$0,10/1.000 e-mails (baratíssimo em escala) |

Todo provedor de e-mail transacional exige verificação de pelo menos um remetente (idealmente domínio, com SPF/DKIM) antes de enviar para destinatários arbitrários — isso não é peculiaridade de nenhum provedor específico, é padrão da indústria contra spam/phishing. Sem domínio próprio, o teste inicial fica restrito a enviar só para o e-mail da própria conta cadastrada no provedor (sandbox), em qualquer um dos seis.

### Expiração do link de convite

Padrões de mercado B2B: Slack expira em 30 dias; GitHub (organizações) expira em 7 dias, com reenvio manual disponível.

**Restrição técnica do Supabase que domina a decisão**: o link de convite usa o mesmo mecanismo de OTP/magic link, controlado por uma única configuração global no Dashboard (**Email OTP expiration**), default 3600s (1h), **com teto de 86400s (24h)** — não é configurável por tipo de fluxo (convite vs. login). Existe uma feature request oficial em aberto pedindo expiração diferenciada, ainda não implementada ([supabase/discussions#23444](https://github.com/orgs/supabase/discussions/23444)). Ou seja: mesmo que o padrão de mercado (Slack/GitHub) sugira dias/semanas, a plataforma tecnicamente não permite passar de 24h hoje.

## Decision (proposta)

1. **SMTP: Resend.** Critério de desempate entre as 6 opções compatíveis: guia de integração dedicado com Supabase (menor fricção de setup dado que o usuário está começando do zero, sem domínio), free tier suficiente para desenvolvimento/piloto (3.000/mês cobre qualquer volume de teste e os primeiros meses reais de uma organização pequena), e não exige a complexidade de IAM/sandbox do SES. **Ação do usuário fora deste ADR**: criar conta em resend.com e configurar o SMTP no Dashboard do Supabase (Project Settings → Auth → SMTP Settings) — isso não é código, não faço eu.
2. **Expiração: 24h (86400s)**, o teto técnico da plataforma. Aceito como o valor mais generoso disponível hoje, documentado como limitação conhecida (não uma escolha de produto) — se o Supabase liberar expiração diferenciada por fluxo no futuro, revisitar para algo mais próximo do padrão de mercado (3-7 dias).
3. **Visibilidade de comanda por profissional: fora de escopo desta fase**, confirmado pelo usuário — RLS atual já bloqueia `professional` de `orders`/`order_items` por completo, nenhuma mudança necessária para não regredir.

## Consequences

### Positivo
- Fecha as 2 decisões que bloqueavam o início da implementação sem violar a regra de ouro do projeto.
- Resend tem o menor atrito de setup para quem está sem domínio configurado ainda — reduz a chance da Fase 11 travar numa etapa de infraestrutura externa ao código.

### Trade-off
- 24h de expiração de convite é mais curto que o padrão de mercado (Slack 30 dias, GitHub 7 dias) — um convidado que não checar o e-mail em 1 dia precisa que o admin reenvie. Aceitável para o estágio atual (equipes pequenas, convite normalmente checado no mesmo dia), mas vale reavaliar se virar fricção real reportada por usuários.
- Trocar de provedor de SMTP depois (ex.: sair do Resend) não exige mudança de código — é reconfiguração no Dashboard do Supabase, então essa decisão tem custo de reversão baixo.

## References
- [Supabase Docs — Custom SMTP](https://supabase.com/docs/guides/auth/auth-smtp)
- [Supabase Docs — Going into prod](https://supabase.com/docs/guides/deployment/going-into-prod)
- [GitHub discussion — Email OTP expiration cap (24h)](https://github.com/orgs/supabase/discussions/13527)
- [GitHub discussion — feature request para expiração diferenciada de convite](https://github.com/orgs/supabase/discussions/23444)
- [Slack Help — Manage pending invitations](https://slack.com/help/articles/360060363633-Manage-pending-invitations-and-invite-links-for-your-workspace)
- [GitHub Docs — Inviting users to join your organization](https://docs.github.com/en/organizations/managing-membership-in-your-organization/inviting-users-to-join-your-organization)
- `docs/PLANEJAMENTO_EXECUCAO_UNIFICADO.md` §Fase 11 — escopo original e decisões em aberto
