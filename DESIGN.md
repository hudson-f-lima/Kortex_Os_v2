---
name: KortexOS
description: Operational infrastructure for beauty & wellness businesses — a control room for agenda, cash, and trust, not a booking calendar.
colors:
  control-green: "#059669"
  control-green-hover: "#047857"
  control-green-tint: "#ECFDF5"
  intelligence-blue: "#1D4ED8"
  intelligence-blue-tint: "#EFF6FF"
  kortex-ai-violet: "#6D5CE7"
  alert-amber: "#D97706"
  danger-red: "#DC2626"
  ink: "#0F172A"
  ink-secondary: "#334155"
  ink-muted: "#64748B"
  hairline: "#E2E8F0"
  hairline-strong: "#CBD5E1"
  canvas: "#F8FAFC"
  surface: "#FFFFFF"
typography:
  body:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', 'Segoe UI', sans-serif"
    fontSize: "1rem"
    fontWeight: 400
    lineHeight: 1.5
    letterSpacing: "normal"
  label:
    fontFamily: "system-ui, -apple-system, BlinkMacSystemFont, 'SF Pro Display', 'SF Pro Text', 'Segoe UI', sans-serif"
    fontSize: "0.75rem"
    fontWeight: 500
    lineHeight: 1.3
    letterSpacing: "normal"
rounded:
  sm: "8px"
  md: "12px"
  lg: "16px"
  xl: "22px"
  pill: "999px"
spacing:
  1: "4px"
  2: "8px"
  3: "12px"
  4: "16px"
  5: "20px"
  6: "24px"
  8: "32px"
  10: "40px"
  12: "48px"
components:
  button-primary:
    backgroundColor: "{colors.control-green}"
    textColor: "{colors.surface}"
    rounded: "{rounded.sm}"
    height: "44px"
    padding: "0 16px"
  button-primary-hover:
    backgroundColor: "{colors.control-green-hover}"
    textColor: "{colors.surface}"
    rounded: "{rounded.sm}"
  button-secondary:
    backgroundColor: "transparent"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    height: "44px"
    padding: "0 16px"
  input:
    backgroundColor: "{colors.surface}"
    textColor: "{colors.ink}"
    rounded: "{rounded.sm}"
    height: "44px"
    padding: "0 12px"
  badge-success:
    backgroundColor: "#D1FAE5"
    textColor: "#047857"
    rounded: "{rounded.pill}"
    height: "24px"
    padding: "0 8px"
  badge-danger:
    backgroundColor: "#FEE2E2"
    textColor: "#B91C1C"
    rounded: "{rounded.pill}"
    height: "24px"
    padding: "0 8px"
  card:
    backgroundColor: "{colors.surface}"
    rounded: "{rounded.lg}"
    padding: "16px"
---

# Design System: KortexOS

## Overview

**Creative North Star: "The Control Room"**

KortexOS reads as a calm command room for a beauty/wellness business, not a consumer booking app. Its job is to let a busy owner or front-desk operator glance at agenda, caixa, and estoque and know instantly what state each thing is in — confirmed, pending, in progress, at risk — the same way a control-room operator reads a bank of status lights, not a way a shopper browses a catalog. That instinct shows up everywhere in the implemented system: a five-state color vocabulary on appointment cards, a three-level alert strip on the timeline, six semantic badge variants, a toast system keyed to the same palette. One accent (`control-green`) does double duty as the primary action color AND the "confirmed / healthy" status color — action and status share one visual language on purpose.

The system is built entirely on the OS's own UI font stack (no custom webfont), flat by default with shadows appearing only as a deliberate signal (elevated cards, open modals, a hovering drag target) rather than ambient decoration. It is unapologetically utilitarian: dense information, high-contrast text (WCAG AAA is an explicit project invariant, not a nice-to-have), and color spent almost exclusively on status and one primary action per screen. There is no marketing surface here — no hero type, no illustration, no display typeface — because none of the implemented screens are trying to persuade; every one of them is trying to be read correctly in under two seconds by someone with a client at the counter.

One deliberate, load-bearing distinction: the system uses **two different accent blues** for two different meanings. `intelligence-blue` (#1D4ED8) marks ordinary system information — the kind of thing the backend already knows and is just surfacing. `kortex-ai-violet` (#6D5CE7) is reserved exclusively for anything the Kortex.ai layer suggested or classified. The two never swap roles; see the Named Rule below.

**Key Characteristics:**
- Status-coded, not decoration-coded — color always means something specific (confirmed / pending / in-progress / completed / canceled, or insight / alert / conflict), never applied for visual variety.
- Flat by default; shadow is a state signal, not a resting-state texture.
- System font only, no custom typeface loading — a deliberate performance choice for an offline-first PWA.
- One primary accent (`control-green`) shared between "the button to press" and "the thing that's fine."
- A second accent (`kortex-ai-violet`) exists solely to mark AI-originated content, kept visually separate from ordinary system blue.
- Single light theme today — see the Don't at the end of this document; the mandated component system has no dark-mode layer yet, even though the page chrome around it does.

## Colors

The palette is small and role-driven: one action/status green, one system-intelligence blue, one AI-only violet, two alert tones (amber/red), and a five-step neutral scale that carries almost all of the actual surface area.

### Primary
- **Control Green** (`#059669` / hover `#047857`): the one color that means both "press this" and "this is fine." Used on primary buttons, and — separately, as a background tint (`#ECFDF5`) — on the "confirmed" state of appointment cards. Reusing one hue for both action and status is intentional: pressing the primary action is what usually *produces* the confirmed state.

### Secondary
- **Intelligence Blue** (`#1D4ED8`, tint `#EFF6FF`): ordinary system information — badges marked `info`, the "in-progress" appointment state, the SmartStrip's informational icon. This is the system talking about itself, not the AI talking to the user.

### Tertiary
- **Kortex.ai Violet** (`#6D5CE7`): reserved exclusively for content the Kortex.ai interface layer produced or classified (an AI-flagged badge, the SmartStrip's `ai` icon). Never used for ordinary system state.

### Neutral
- **Ink** (`#0F172A`): primary text.
- **Ink Secondary** (`#334155`): secondary text, card meta lines, appointment service labels.
- **Ink Muted** (`#64748B`): placeholder text, disabled state, tertiary labels.
- **Hairline** (`#E2E8F0`) / **Hairline Strong** (`#CBD5E1`): default and emphasized border/divider weight.
- **Canvas** (`#F8FAFC`): page background beneath cards.
- **Surface** (`#FFFFFF`): card, input, and modal surface color.

**Alert tones (not yet formal scale tokens, but consistently reused as literals across Badge, Card, AppointmentCard, and SmartStrip):** amber `#D97706` (icon/text) with tint `#FFFBEB`/`#FEF3C7` for warning surfaces; red `#DC2626` (danger, same hue as `danger-red`) with tint `#FEF2F2`/`#FEE2E2` for danger surfaces. Treat these as the real amber/red vocabulary even though — unlike green/blue/violet — they were never promoted to named CSS custom properties.

### Named Rules
**The AI Never Wears System Blue Rule.** Anything the Kortex.ai layer suggested, classified, or drafted uses `kortex-ai-violet`, never `intelligence-blue`. A user must be able to tell "the system computed this" from "the AI suggested this" by color alone, without reading a label.

**The One Green Rule.** `control-green` is the only color that means "do this" or "this succeeded." It never appears as a neutral decorative accent — if a green element is on screen, it is either the primary action or a confirmed/success state.

## Typography

**Body Font:** system-ui, -apple-system, BlinkMacSystemFont, "SF Pro Display", "SF Pro Text", "Segoe UI", sans-serif (no fallback webfont — this is the whole stack)

**Character:** Native and fast over distinctive. The system deliberately spends zero typographic personality on a custom face; legibility and load time (offline-first PWA) win over voice. Hierarchy is carried by weight and size, not by a second family.

### Hierarchy
- **Body** (400, 1rem, 1.5): default reading size for lists, form values, card content.
- **Title** (600, 1.05–1.15rem): section/page headers (`<h1>` in list pages, modal `<h3>`), a name and a color/token, not a formal size ramp.
- **Label** (500, 0.75rem): status labels, timestamps, secondary meta on appointment cards and toolbar controls — the smallest text in the system.

### Named Rules
**The 0.75rem Floor Rule.** No legend, label, or status text renders smaller than `0.75rem`, and every text/background pairing at that size still clears WCAG AAA contrast (a project invariant, not a target) — this floor exists specifically because the smallest text in the system (status labels on a crowded day view) is also the text a distracted operator most needs to read correctly.

## Layout

List-first, modal-second. Every management surface (Clientes, Equipe, Catálogo, Estoque, Caixa, Organização) follows the same shell: a page title, a toolbar row (filters + one primary "+ Novo …" action, ≤4 controls), then a bordered `record-list` of rows, with all create/edit work happening in an overlaid `<Modal>` rather than a separate route. The one screen that breaks this pattern on purpose is Agenda, which is mandated to use a vertical timeline instead of a list (absolutely-positioned appointment cards inside time-scored columns per professional).

Modals are adaptive: a centered card on desktop (`sm` 400px / `md` 540px / `lg` 720px / `xl` 900px, internal scroll capped at `90vh`), collapsing to a full-width bottom sheet under 640px so a one-handed phone user can reach the primary action with a thumb. Bottom navigation on mobile keeps touch targets at a `44px` minimum.

Spacing runs on an 8-point-ish rhythm (`4/8/12/16/20/24/32/40/48px`), tighter inside components (`4–12px`) and looser between page sections (`16–24px`).

## Elevation & Depth

Flat at rest. The system has no formal shadow token scale — every shadow value is a literal, hand-picked per component — but the same three-step vocabulary repeats everywhere shadow appears, which is a real (if untokenized) system:

### Shadow Vocabulary
- **Ambient Low** (`0 1px 2px rgba(0,0,0,0.05)`): resting elevation for an appointment card sitting on the timeline canvas.
- **Ambient Card** (`0 4px 6px -1px rgba(0,0,0,0.05), 0 2px 4px -2px rgba(0,0,0,0.05)`): an explicitly elevated `Card`, or an appointment card on hover (`0 4px 6px -1px rgba(0,0,0,0.1)` — same shape, doubled opacity for the state change).
- **Ambient Modal** (`0 20px 25px -5px rgba(0,0,0,0.1), 0 8px 10px -6px rgba(0,0,0,0.1)`): the one place shadow does real work — lifting a modal card off the page behind a blurred, darkened overlay.

### Named Rules
**The Flat-Until-It-Matters Rule.** Surfaces are flat by default (a `Card` with a plain hairline border, not a shadow). Shadow appears only to mark a genuine state change: something is now floating above the page (modal), something is being hovered as an interactive target (card, draggable appointment), or something was explicitly asked to stand out (`Card--elevated`). A resting list item never has a shadow.

## Shapes

Corners scale with a component's weight, not its content: small interactive controls (button, input, select, appointment card) use `radius-sm` (8px); containers with real surface area (Card, EmptyState, the amount-input preview panel) step up to `radius-lg` (16px); a status pill (Badge) or a fully rounded action (the mobile FAB) goes to `radius-pill` (999px). `radius-xl` (22px) exists in the scale for a larger hero-weight surface but has no current caller — reserve it rather than reach for `lg` twice.

The one recurring *geometric* signature, not just a radius choice, is the **4px colored status bar**: a thin vertical strip on the left edge of an appointment card, colored by state (green/amber/blue/muted/red), doing the same status-communication job as a badge but as pure geometry instead of text — readable at a glance, at a size too small to hold a label.

## Components

### Buttons
- **Shape:** `radius-sm` (8px), heights on a 3-step scale (`36 / 44 / 52px` for sm/md/lg).
- **Primary:** `control-green` background, white text; hover deepens to `control-green-hover`. This is the one color in the whole system that means "the main thing to do here."
- **Secondary:** transparent background, `hairline-strong` border, `ink` text; hover fills with `canvas`-tinted surface.
- **Ghost:** transparent, no border, same text/hover treatment as secondary minus the outline.
- **Danger:** `danger-red` background, white text — reserved for destructive confirmations.
- **Link:** no background, `control-green` text, underline on hover — inline actions inside sentences.
- **Loading:** text is replaced by a `currentColor` spinner ring; the button keeps its size so nothing reflows.

### Badges
- **Style:** small pill (`radius-pill`), 24px tall, 600-weight 0.75rem text, no border — a tinted-background + saturated-text pairing per variant (`neutral` slate / `success` emerald / `warning` amber / `danger` red / `info` royal-blue / `ai` violet).
- **Use:** the primary way the system labels a row's kind or state inline (transaction kind in Caixa, client active/inactive, AI-flagged content).

### Cards
- **Corner Style:** `radius-lg` (16px).
- **Background:** `surface` (white) at rest; `canvas`-tinted `--muted` variant for de-emphasized content; role tints (`intelligence`/`warning`/`danger`) for contextual callouts; `control-green-tint` + green border for a selected state.
- **Shadow Strategy:** flat by default; `Ambient Card` only on the `--elevated` variant or on hover for `--interactive`.
- **Border:** 1px `hairline`, upgrading to `hairline-strong` on interactive hover.
- **Internal Padding:** `16px` (`space-4`).

### Inputs / Selects
- **Style:** `surface` background, 1px `hairline-strong` border, `radius-sm`, `44px` tall, label sits above the field (never a floating label).
- **Focus:** border shifts to `intelligence-blue`-adjacent focus color plus a matching 1px outer glow (`box-shadow: 0 0 0 1px var(--color-focus)`) — no default browser outline.
- **Error:** border and message text switch to `danger-red`; the message renders inline beneath the field, tied to the input via `aria-describedby`, never as a page-level banner for a field-specific problem.
- **Select** matches Input's shell exactly, with a custom chevron icon replacing the native arrow.

### Modal
- **Shell:** centered card, adaptive width (`sm/md/lg/xl`), `radius-md` (12px) corners, `Ambient Modal` shadow over a blurred dark overlay.
- **Header:** optional — when a `title` is supplied, a bordered header row with an `h3` and a "✕" close button; content-only modals omit the header entirely.
- **Behavior:** Escape closes; clicking the overlay (not the card) closes; on mobile (< 640px) the same shell becomes a bottom sheet that slides up instead of fading in.
- **Focus:** the shell traps Tab/Shift+Tab inside itself, sends initial focus to the first real field in the content (skipping its own close button), and restores focus to whatever had it before the modal opened.

### Empty State
- **Style:** centered column inside a dashed-border, `radius-lg` panel — a circular muted icon badge (80px), an 1.125rem/600 title, a muted description, and an optional primary-button action.
- **Known issue:** the current CSS references custom properties (`--spacing-*`, `--color-background`, `--color-text-tertiary`) that don't exist anywhere in `tokens.css`; per CSS fallback rules this collapses the component's padding/margins to `0` and its background to `transparent` today. Treat the description above as the *intended* design (mapped to the real `--space-*`/`--color-*` tokens), not what currently renders — see Don't below.

### Toast
- **Style:** a `radius-md` surface card with a 4px colored left border (the same status-bar language as appointment cards), title (600/0.875rem) over a muted description, slide-in from the right.
- **Known issue:** like Empty State, the current CSS references undefined custom properties (`--spacing-*`, `--shadow-lg`, `--color-primary-500`, `--color-emerald-500`, `--color-rose-500`, `--color-amber-500`) — none exist in `tokens.css`. The component is wired into `ToastContext` and renders live, but without its intended spacing, shadow, or border-accent color. See Don't below.

### Skeleton
- **Style:** a `slate-200`→`slate-100` shimmer gradient, animating left-to-right over 1.5s — text/circular/rectangular variants for line, avatar, and block placeholders respectively.

### Appointment Card (signature)
The Agenda timeline's core unit, and the clearest expression of the Control Room identity: a `radius-sm` card with the 4px colored status bar described in Shapes, tinted background per state (`confirmed` green / `pending` amber / `in-progress` blue / `completed` muted slate / `canceled` 60%-opacity), time in bold `ink`, client name truncating with ellipsis before service. A `--compact` modifier collapses the layout to a single row for short appointments; `--draggable`/`--dragging`/`--saving` modifiers support the drag-to-reschedule interaction with `touch-action: none` so a drag gesture doesn't fight mobile scroll.

### SmartStrip (signature)
A full-width banner docked at the top of a view, carrying the Kortex.ai layer's voice into the UI: `insight` (blue tint), `alert` (amber tint), `conflict` (red tint) variants, each with an icon, a message, inline text actions, and a dismiss control. This is where `kortex-ai-violet` earns its keep — the `ai` icon variant is the one place in this component that breaks from the info/warning/danger triad to say "this came from the AI layer specifically," per the Named Rule above.

## Do's and Don'ts

### Do:
- **Do** use `control-green` for exactly one thing per screen: the primary action, or a confirmed/success status. Never both a decorative accent and a status color on the same screen without a reason.
- **Do** reserve `kortex-ai-violet` exclusively for Kortex.ai-originated content; use `intelligence-blue` for everything else the system already knows.
- **Do** build every new interactive control from `ui/primitives` (`Button`, `Input`, `Select`, `Badge`, `Modal`, `Card`, `ActionRequestModal`) — never a raw `<button>`/`<input>`/`<select>`. This is an explicit project invariant, not a style preference.
- **Do** keep every modal on the shared `<Modal>` shell with internal scroll and the mobile bottom-sheet behavior; don't build a bespoke dialog.
- **Do** hold every label and status text to `0.75rem` minimum with WCAG AAA contrast — verify, don't assume, on any new color pairing.

### Don't:
- **Don't** add a shadow to a resting-state element. Shadow in this system always signals something (elevated, hovered, floating above the page) — a permanently-shadowed card reads as broken, not "polished."
- **Don't** introduce a new accent hue for a one-off feature. The palette is deliberately small (green / blue / violet / amber / red / neutral); a new color needs a new *meaning*, not just visual variety.
- **Don't** reference `--spacing-*`, `--shadow-*`, `--color-primary-500`, `--color-emerald-500`, `--color-rose-500`, `--color-amber-500`, or `--color-text-tertiary` in new CSS — none of these exist in `tokens.css` (only `--space-*` and the semantic `--color-*` roles documented above do). `Toast.css` and `EmptyState.css` currently do this and render broken as a result; don't copy the pattern forward.
- **Don't** assume dark-mode support inside a `ui/primitives` component. `tokens.css` has no `prefers-color-scheme: dark` layer today — only the legacy page-chrome tokens in `styles.css` (`--bg`/`--fg`/`--accent`/etc., used by Login/Create-Organization/Accept-Invite and the shell nav) do. A primitive-built modal or card will stay light-themed even when the OS is dark, which currently looks inconsistent against dark-themed page chrome around it. Extending `tokens.css` with a dark layer is real, scoped future work — don't paper over it locally inside one component.
