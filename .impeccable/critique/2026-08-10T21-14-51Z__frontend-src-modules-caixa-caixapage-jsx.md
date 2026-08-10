---
target: frontend/src/modules/caixa/CaixaPage.jsx
total_score: 15
max_score: 40
na_heuristics: 
p0_count: 2
p1_count: 2
timestamp: 2026-08-10T21-14-51Z
slug: frontend-src-modules-caixa-caixapage-jsx
---
Method: dual-agent (A: acb9377f673c6cf7f · B: a49881c3d428b398a)

## Design Health Score

| # | Heuristic | Score | Key Issue |
|---|-----------|-------|-----------|
| 1 | Visibility of System Status | 2 | Full-skeleton replace on every refetch instead of inline update; no "synced as of" indicator |
| 2 | Match System / Real World | 2 | Correct pt-BR terms, but "Total no período" matches no real cash-handling mental model |
| 3 | User Control and Freedom | 2 | Modal exits cleanly, but no way to correct/void a submitted manual entry |
| 4 | Consistency and Standards | 1 | Modal skips house `title=` pattern; kind Select has no visible label unlike sibling date inputs; Badge/EmptyState unused here |
| 5 | Error Prevention | 1 | No confirmation before financial write; malformed decimal input silently reinterpreted; validation stops at first bad field |
| 6 | Recognition Rather Than Recall | 2 | Filters all visible, but debit vs. credit requires reading text, no visual cue |
| 7 | Flexibility and Efficiency | 1 | No keyboard shortcuts, no "hoje" date preset, no bulk actions — real gaps for an Operate surface |
| 8 | Aesthetic and Minimalist Design | 2 | Uncluttered but flat hierarchy; total barely outweighs per-row amounts |
| 9 | Error Recovery | 2 | `cashEntryErrors.js` does real translation work, but errors aren't localized to the offending field and list-load errors aren't mapped at all |
| 10 | Help and Documentation | 0 | No microcopy anywhere; no explanation for why only 2 of 4 filterable kinds can be created here |
| **Total** | | **15/40** | **Poor** |

Every heuristic was scored (none n/a) — this is an Operate surface where heuristics 7 and 10 genuinely apply, and both scored weak on merit rather than being exempted.

## Design Specificity Verdict

**LLM assessment**: This reads as a generic filtered-list-plus-create-modal CRUD screen wearing cash-register vocabulary, not a screen authored around how a cash drawer actually gets scanned and reconciled at a busy counter. `CaixaPage` has no CSS of its own — its container selector (`.caixa-page, .organizacao-page`, `styles.css:627-633`) is literally shared with the unrelated Organization-settings page, and its total line reuses `.comanda-total` (`styles.css:562-565`), a class borrowed wholesale from the Comanda/checkout module. Every ledger row renders its amount identically regardless of direction (`CaixaPage.jsx:143-149`) even though the app already has a `Badge` component built for exactly this kind of state-coding (used in `ClientesPage.jsx:131`). And the number a cash screen most needs to get right — the total — is a flat, unsigned sum (`CaixaPage.jsx:87`) even though the backend stores expenses/refunds as positive integers by contract. An inventory log or any other generic ledger could adopt this component unchanged.

**Deterministic scan**: `detect.mjs --json` returned `[]` (exit 0, clean) on both the target file and the full `caixa/` module directory — zero pattern-based findings. This is a real gap between the two assessments worth naming directly: the regex-based detector has no way to see that a CSS selector is shared with an unrelated page, that a class name was borrowed from another module, or that a sum is computed with the wrong sign — those are semantic/structural problems, not literal anti-patterns a static scan catches. The clean scan should not be read as "this screen is fine" — it means this class of specificity failure is outside the detector's reach entirely, and the LLM pass is where these were actually found.

**Visual overlays**: Browser inspection of the live `/caixa` route was blocked by Supabase auth (redirects to login; no credentials available, and none were attempted). The injection mechanism itself was verified working by testing it against the reachable login page instead, where it incidentally surfaced one real, severe finding unrelated to this target: `low-contrast — 1.0:1 (need 4.5:1) — text #ffffff on #ffffff` on the login form. That's a genuine bug worth a separate look, but it's on the login screen, not `CaixaPage`, so it isn't scored here. No live-rendered DOM/CSS evidence of `CaixaPage.jsx` itself was obtainable this run.

## Overall Impression

The bones are workable — role-gating, idempotency, and error-message translation all show real care — but the screen doesn't yet know it's a cash register. The single biggest opportunity is also the single scariest bug: the displayed total is arithmetically wrong for any period containing an expense or refund, on the one screen where a wrong number has direct financial consequences. Fix that and the visual money-in/money-out distinction, and this moves from "generic ledger" toward "an actual point-of-sale."

## What's Working

1. **Idempotency handling.** `ManualEntryModal.jsx:21` generates a fresh `Idempotency-Key` per modal open, matching the established pattern in `AdjustmentModal.jsx` and protecting against duplicate entries from double-submits or retries.
2. **Real error translation.** `cashEntryErrors.js:7-19` maps the two most likely backend failures (stale idempotency key, insufficient role) into specific, actionable pt-BR — better than most error paths in this file set.
3. **Precise, tested role-gating.** `READ_ROLES`/`WRITE_ROLES` mirror the backend RPC allowlists exactly, with inline comments explaining *why* reception is excluded (`CaixaPage.jsx:12-19`), and both the empty-permission and hidden-button states are covered in `CaixaPage.test.jsx:60-67,101-106`.

## Priority Issues

**[P0] "Total no período" is not a trustworthy cash figure**
- **Why it matters**: `totalCents` sums every entry's `amount_cents` regardless of `kind` (`CaixaPage.jsx:87`, displayed at `:136`), but the backend stores `expense`/`refund` amounts as positive integers by contract (`cashEntries.route.js:38-39`). A R$500 "Saída" adds to the total instead of subtracting. A manager reading this number as "how much cash this represents" is reading gross turnover mislabeled as a total — a real reconciliation risk.
- **Fix**: Compute a signed total (add for sale/income, subtract for expense/refund), or relabel explicitly as "Movimentação bruta" plus a separate, clearly-labeled net figure.
- **Suggested command**: `$impeccable harden` (this is a correctness/edge-case bug before it's a design one — flag for a code fix alongside the relabeling)

**[P0] No visual distinction between money-in and money-out**
- **Why it matters**: Every row renders its amount identically regardless of `kind` (`CaixaPage.jsx:143-149`); the single most important scan operation on a cash ledger — credit vs. debit — is completely flattened, despite the app already having a `Badge` component built for this exact purpose.
- **Fix**: Color/badge-code by kind (e.g. green for sale/income, red for expense/refund) and/or prefix amounts with +/−.
- **Suggested command**: `$impeccable colorize`

**[P1] Manual-entry modal has no focus management**
- **Why it matters**: `Modal.jsx` sets no initial focus and has no focus trap; since `ManualEntryModal.jsx:53` doesn't pass `title=`, the dialog also never gets the `aria-labelledby` wiring the `title` branch would add. A keyboard user can tab out of a money-entry dialog into the page behind it; a screen-reader user gets no announced context for what just opened.
- **Fix**: Pass `title="Novo lançamento"` (matches the established pattern in `ActionRequestModal.jsx:32`) and add a focus trap + initial-focus-on-first-field to `Modal.jsx`.
- **Suggested command**: `$impeccable audit`

**[P1] Validation errors aren't localized to the offending field**
- **Why it matters**: `Input`/`Select` both support an `error` prop (red border, `aria-invalid`, inline message) but `ManualEntryModal` never uses it — all errors collapse into one shared paragraph below all three fields. Under counter-pressure with a client waiting, the user has to re-scan the whole form to find what failed.
- **Fix**: Track per-field error state and pass it to the specific `Input`/`Select` that failed.
- **Suggested command**: `$impeccable clarify`

**[P2] Amount input silently reinterprets malformed decimals with no preview**
- **Why it matters**: `reaisToCents` (`money.js:12-22`) parses free-text amounts by string manipulation; ambiguous input (e.g. an extra comma) is silently truncated/reinterpreted rather than rejected, and the parsed value is never shown back before submit — a distracted staff member could commit an amount they didn't intend.
- **Fix**: Show a live formatted preview (e.g. "R$ 50,00") beneath the input before submit, or reject ambiguous multi-comma input outright.
- **Suggested command**: `$impeccable harden`

## Persona Red Flags

**Sam (Accessibility-Dependent User)**: No focus trap/initial focus/`aria-labelledby` on the money-entry modal (detailed above). WCAG 2.5.3 "Label in Name" failure — the "De"/"Até" date inputs show visible labels "De"/"Até" but carry `aria-label="Data inicial"`/`"Data final"` (`CaixaPage.jsx:127-128`); since `aria-label` wins for the accessible name, a speech-input user saying "click De" won't match what's announced. The kind `Select` has no visible label at all, only `aria-label`, inconsistent with its sibling date inputs in the same toolbar row.

**Riley (Deliberate Stress Tester)**: The P0 signed-total bug is exactly Riley's kind of find — invisible until you check a period with a mix of expense/refund entries. The list also has no server-side date filter at all; a comment in `CaixaPage.jsx:75-77` confirms "a API não tem parâmetro de período," so a salon with months of history pulls the entire ledger on every load/refetch, filtered only client-side. Malformed decimal input (`"50,00,00"`) is a classic Riley probe this form doesn't guard against.

**Casey (Distracted Mobile User)**: Without `title=` on `Modal`, there's no top-corner close affordance — the only exits are Escape (unreliable on touch) or scrolling to a bottom "Fechar" button, worse on a small viewport mid-transaction. Every filter change or post-create refetch swaps the entire content area for a full-screen skeleton rather than updating inline — a jarring flash if Casey gets interrupted mid-glance. The unbounded full-history fetch above is also slower and more data-hungry on salon wifi from a tablet.

## Minor Observations

- `PageSkeleton` shows a title + top-right pill shape that doesn't match Caixa's real layout (the "+ Novo lançamento" button lives inside the toolbar row, not beside the `<h1>`) — a generic, unshaped loading state.
- The submit `Button` never uses the design system's built-in `isLoading`/spinner — it only swaps text to "Lançando…", losing a visual affordance already available elsewhere.
- The filter dropdown lists all 4 kinds (Venda/Entrada/Saída/Estorno) but the create-modal only offers 2 (Entrada/Saída) — no copy anywhere explains why Venda/Estorno can never be created from this screen.
- `ManualEntryModal.jsx` has no dedicated test file; its own validation branches are only exercised indirectly through one happy-path test in `CaixaPage.test.jsx`.
- Separately from this target: the injection mechanism used for Assessment B incidentally found a real `1.0:1` white-on-white contrast failure on the login form (`form.auth-form`) while testing overlay delivery. Worth a dedicated look — not scored here since it's a different screen.

## Questions to Consider

- What should a receptionist be able to read off this screen in under 2 seconds to know "is the drawer roughly right" before serving the next client — and is "sum of everything" ever the right shape for that number?
- If Venda/Estorno can only ever be created by other flows (checkout, refund), should this screen split into a read-only "histórico do caixa" and a narrower "lançamento avulso" (income/expense only), instead of one flat list implying all 4 kinds are equally user-generated here?
- This screen is named "Caixa" but has zero visible concept of an open/closed session. Should it at least acknowledge that today, so staff aren't left wondering whether closing the register is tracked at all?
- On a tablet with a client waiting, is a full-screen modal really the fastest way to log a R$20 supply purchase — or would an inline quick-add row in the toolbar match how a busy front desk actually works?
