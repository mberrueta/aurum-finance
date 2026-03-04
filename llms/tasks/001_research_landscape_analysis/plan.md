# Issue #1 Plan - Phase 1 Research and Landscape Analysis

## Objective

Produce a reviewable, implementation-free Phase 1 execution plan based on
`llms/tasks/000_project_plan.md`, focused on researching comparable personal
finance systems and extracting design lessons for AurumFinance.

---

## Source Alignment

- Issue: `https://github.com/mberrueta/aurum-finance/issues/1`
- Baseline workflow: `llms/tasks/000_project_plan.md`
- Planning agent guidance: `llms/agents/po_analyst.md`
- Governance baseline: `llms/constitution.md`
- Project domain context: `llms/project_context.md`

---

## In-Scope

- Research landscape analysis for:
  - Firefly III
  - GnuCash
  - Actual Budget
- Create a structured comparison and decision-support notes.
- Capture design lessons relevant to:
  - ledger correctness
  - reconciliation workflows
  - privacy-first self-hosting
  - grouped rules engine model
  - multi-currency and FX handling
- Define handoff outputs for subsequent architecture and implementation phases.

## Out of Scope

- Application code changes in `lib/`, `test/`, `config/`, or assets.
- Database migrations or runtime behavior changes.
- UI implementation, API implementation, or prototype coding.

---

## Scope Restatement (Issue-Driven)

- Deliver exactly one planning artifact for Phase 1 in this task folder.
- Keep all work planning-only and implementation-free.
- Include objective, research topics, deliverables, artifacts, and success criteria.
- Include comparison notes and design lessons directly in this plan document.
- Mark all initial notes as **hypotheses** until validated against primary documentation.

---

## Research Questions

- Which accounting model choices are explicit in each product (double-entry
  rigor, budget model, transaction model)?
- How does each product structure accounts, categories, payees, tags, and splits?
- What reconciliation workflows are available and what user steps are required?
- How import/export friendly is each product for migration and long-term data
  ownership?
- What privacy and self-hosting assumptions exist by default?
- Which UX patterns reduce bookkeeping friction without sacrificing auditability?
- How does each product handle multi-currency transactions and FX?
- How do automated rules interact with manual user edits?

---

## Comparison Framework

Each researched product should be evaluated with the same dimensions:

- Product orientation and core mental model.
- Data model primitives (accounts, transactions, splits, budgets, categories, rules).
- Reconciliation flow and error handling.
- Import/export capabilities and interoperability.
- Automation support (rules, scheduled transactions, recurring behavior).
- Reporting depth and explainability.
- Multi-currency and FX handling approach.
- Multi-user, permissions, and deployment posture for self-hosting.
- Known adoption friction points and operational complexity.

---

## Landscape Analysis (Validated Design Lessons)

> **Legend:** ✅ Applicable to AurumFinance | ⚠️ Use with caution | ❌ Not applicable / avoid

### Firefly III

**Orientation:** Self-hosted web personal finance manager. Privacy-first, API-driven,
import ecosystem separated from core by design.

| Dimension | Finding | Applicability |
|---|---|---|
| Accounting model | Double-entry under the hood (journal with two sides per event) | ✅ Confirms internal ledger model |
| Rules engine | Trigger → condition → action pipeline, priority-ordered per group | ✅ Strong blueprint for AurumFinance |
| Import architecture | Data Importer is a separate service (security + maintenance boundary) | ✅ Keep ingestion pipeline decoupled |
| Multi-currency | Supported, explicit FX handling per transaction | ✅ Validate approach |
| Budgets | Period-based budgets (not envelope/zero-sum) | ⚠️ Different model than YNAB-style |
| Recurring transactions | Supported natively | ✅ Planned feature |
| API | REST API for automation and integration | ✅ Align with MCP layer vision |
| License | AGPL-3.0 | ❌ Do NOT reuse code — take ideas only |

**Key lessons for AurumFinance:**
- Separate importer from core ledger as an explicit security and maintenance boundary.
- Rules pipeline architecture (triggers → conditions → actions) is a proven pattern.
- Double-entry can be internal/invisible while UX stays personal-finance-first.

---

### GnuCash

**Orientation:** Desktop-first double-entry accounting system. Professional accounting
correctness, mature multi-currency model, strong reconciliation semantics.

| Dimension | Finding | Applicability |
|---|---|---|
| Accounting model | Full double-entry, account hierarchy, commodities/currencies as first-class | ✅ Primary reference for ledger invariants |
| Multi-currency | Trading Accounts model for FX imbalances — explicit and auditable | ✅ Strongest reference for multi-currency design |
| Reconciliation | Statement-matching workflow with explicit states (unreconciled → cleared → reconciled) | ✅ Adopt reconciliation state model |
| Imports | QIF, OFX/QFX, CSV — well-documented formats | ✅ Reference for import format coverage |
| Multi-entity | Separate "books" per entity — no unified multi-owner model | ⚠️ AurumFinance needs first-class multi-entity (gap to fill) |
| UX | Desktop-first, accountant-oriented, steep learning curve | ❌ Not a UX reference |
| License | GPL-2.0+ | ❌ Do NOT reuse code |

**Key lessons for AurumFinance:**
- Use as the canonical reference for account modeling, posting splits, commodity/currency
  handling, and reconciliation state semantics.
- Multi-entity is a gap GnuCash doesn't solve — AurumFinance can differentiate here.
- FX via Trading Accounts is a well-reasoned pattern worth studying in depth.

---

### Actual Budget

**Orientation:** Local-first envelope budgeting with modern UX. Privacy-focused,
optional sync server, MIT license.

| Dimension | Finding | Applicability |
|---|---|---|
| Architecture | Local-first client + optional sync server | ✅ Good pattern for MCP/AI layer with scoped permissions |
| Budgeting model | Envelope / zero-sum (assign every dollar a job) | ✅ Useful UX pattern for budget features |
| Privacy | Local-first by default, sync is opt-in | ✅ Aligns with AurumFinance privacy posture |
| API | Available for automation and import/export | ✅ Reference for integration design |
| Multi-currency | **Not supported** (explicitly documented limitation) | ❌ Cannot reference for FX design |
| Investments / multi-entity | Not in scope | ❌ Not applicable |
| License | MIT | ✅ Most permissive — safest for referencing patterns |

**Key lessons for AurumFinance:**
- ~~Envelope/zero-sum UX patterns~~ — **explicitly not applicable**. AurumFinance is
  retrospective and projection-based, not forward-assignment-based. Users import
  historical statements; the system learns patterns from actuals and projects forward.
  Asking users to pre-assign income to buckets contradicts the import-first, low-friction posture.
- Local-first + optional sync is a clean architecture for privacy and AI layer design.
- Multi-currency is a hard gap in Actual — reinforces that AurumFinance fills a real niche.

---

### Comparative Summary

| | Firefly III | GnuCash | Actual Budget | AurumFinance target |
|---|---|---|---|---|
| Double-entry | ✅ internal | ✅ explicit | ❌ | ✅ internal |
| Multi-currency | ✅ | ✅ strong | ❌ | ✅ first-class |
| Multi-entity | ⚠️ limited | ⚠️ separate books | ❌ | ✅ first-class |
| Self-hosted | ✅ | ✅ desktop | ✅ | ✅ |
| Rules engine | ✅ | ❌ | ❌ | ✅ grouped |
| Envelope budgeting | ❌ | ❌ | ✅ | ❌ not applicable |
| AI layer | ❌ | ❌ | ❌ | ✅ local-first |
| MCP data access | ❌ | ❌ | ❌ | ✅ planned |
| License | AGPL ⚠️ | GPL ⚠️ | MIT ✅ | Apache 2.0 |

---

## Product Owner Direction (Captured)

### Rules Engine Direction — Grouped Model

AurumFinance adopts a **grouped rules engine** model. This is a deliberate design
decision that differs from a single flat priority-ordered pipeline.

#### Core model

Rules are organized into **independent groups**. Each group has a dedicated
responsibility (e.g., expense category, account origin, investment type).

- **Multiple groups can match the same transaction simultaneously.**
  Each group produces its own output independently — there is no conflict between groups.
- **Within a group, priority order applies.**
  The first matching rule in the group wins. Remaining rules in that group are skipped.
- **A transaction with no match in a group produces no output for that group.**
  Absence of match is a valid, explicit outcome — not an error.

#### Example

```
Group 1 — Expense Type
  Rule 1.1: description contains "UBER"  → category = Transport
  Rule 1.2: description contains "RAPPI" → category = Food Delivery
  Rule 1.3: amount < 0, account = VISA   → category = General Expense

Group 2 — Account Origin
  Rule 2.1: account = "VISA Santander"  → tag = credit-card
  Rule 2.2: account = "CA USD"          → tag = usd-account
  Rule 2.3: account = "Broker A"        → tag = brokerage

Group 3 — Investment Type
  Rule 3.1: description matches /CEDEARs?/i → investment_type = CEDEAR
  Rule 3.2: description matches /ON\s/i      → investment_type = Corporate Bond
```

A single transaction (e.g., "UBER EATS" charged to VISA Santander) would
simultaneously match Group 1 (→ category = Food Delivery) and Group 2 (→ tag =
credit-card), producing both outputs. Group 3 would produce no output.

#### Explainability requirements

Every automated change must record:
- Which group fired.
- Which rule within the group matched.
- What fields were modified and their previous values.
- That no match occurred in groups where rules were skipped.

#### Immutable facts vs mutable classification

A transaction has two distinct layers with different mutability rules:

**Immutable facts** — sourced directly from the bank/broker statement. Never editable by the user or by rules:
- Original amount and currency
- Original transaction date
- Original description (as provided by the institution)
- Source account
- Institution transaction ID / reference

**Mutable classification** — the interpretation layer applied on top of facts. Editable by both rules and users:
- Category (e.g., Transport, Supermarket)
- Tags
- Investment type
- Friendly description / notes
- Split assignments (subdividing into sub-categories)

This distinction means: if the bank says "UBER TRIP #4821 — $1500", that is permanent evidence. What AurumFinance (or the user) decides that transaction *means* is classification and can always be corrected.

#### Manual edit protection

Manual user edits to the classification layer are protected from unintentional reversion:
- A classification field edited manually is flagged as `manually_overridden = true`.
- Rules pipelines must skip fields with `manually_overridden = true` on re-runs and re-imports.
- The `classified_by` field records whether the current value was set by a rule (and which one) or by the user.
- Overrides are visible in the audit trail and can be cleared explicitly by the user to allow rules to re-apply.

Example:

| Field | Value | Layer | Editable? |
|---|---|---|---|
| Original description | "UBER TRIP #4821" | Fact | ❌ never |
| Amount | -$1500 | Fact | ❌ never |
| Date | 2025-03-03 | Fact | ❌ never |
| Category | Transport → corrected to Supermarket | Classification | ✅ user |
| `classified_by` | rule_1.1 → user | Classification | auto |
| `manually_overridden` | true (after user correction) | Classification | auto |

#### Import workflow

- Rules must support **preview-before-apply** mode.
- Preview shows per-row: matched group, matched rule, proposed changes, confidence.
- User can approve, reject, or modify before committing.

---

### Ledger Model Direction

- Treat ledger-style double-entry as an **internal correctness model** even if
  the user-facing UX stays personal-finance-first.
- Validate account-to-account movement modeling (A → B) as the canonical
  transaction representation.
- Preserve simple external concepts while mapping internally to balanced postings:

| UX concept | Internal posting model |
|---|---|
| Expense | Asset/Liability → Expense Category |
| Income | Income Category → Asset |
| Transfer | Asset Account A → Asset Account B |
| Credit card purchase | Credit Card (Liability) → Expense Category |
| Credit card payment | Bank Account (Asset) → Credit Card (Liability) |

---

### Multi-Currency Direction

Multi-currency is a **first-class concern**, not an afterthought.

#### Core ledger rule

Every posting must carry its **original currency and original amount** — immutable, same as transaction facts. Converted values are always derived, never stored as the source of truth.

#### FX rate types — multiple named series

A single currency pair (e.g., ARS/USD or BRL/USD) has **N named rate types**, each with a distinct purpose. AurumFinance must support multiple simultaneous rate series per pair, scoped to a jurisdiction:

| Rate type | Jurisdiction | Purpose | Source |
|---|---|---|---|
| `ptax` | 🇧🇷 Brazil | Tax reporting — Receita Federal reference rate | Banco Central do Brasil |
| `official_afip` | 🇦🇷 Argentina | Tax reporting — AFIP/ARCA legal rate | AFIP/ARCA published rates |
| `mep` | 🇦🇷 Argentina | Market rate via AL30/GD30 bond arbitrage | Exchange / broker data |
| `ccl` | 🇦🇷 Argentina | Contado con liquidación — offshore rate | Exchange / broker data |
| `blue` | 🇦🇷 Argentina | Informal parallel market (reference only) | Informal trackers |
| `irs_yearly` | 🇺🇸 USA | IRS yearly average rate for FBAR/FATCA reporting | IRS published tables |
| `crypto` | any | USDT/fiat rate on exchanges (reference only) | Exchange APIs |

This list is illustrative — the data model must support **arbitrary named rate types per currency pair per jurisdiction**, not a hardcoded enum. New jurisdictions and rate types must be addable without schema changes.

#### Tax-first rate — per fiscal residency

Each user configures a **country of fiscal residency**. This drives which rate type
is used as the default for tax-relevant event snapshots:

| Fiscal residency | Default tax rate type | Authority |
|---|---|---|
| 🇧🇷 Brazil | `ptax` | Receita Federal |
| 🇦🇷 Argentina | `official_afip` | AFIP / ARCA |
| 🇺🇸 USA | `irs_yearly` | IRS |
| other | user-configurable | — |

For any tax-relevant event (asset sale, dividend, income, FX gain), the system must:
- Record the fiscal-residency rate at the time of the event.
- Flag the event as tax-relevant with the rate snapshot used.
- Never retroactively modify this snapshot even if the rate series is updated.

**Fiscal residency ≠ where your accounts are.** A user living in Brazil with accounts
in Argentina and the US has fiscal residency in Brazil — all tax snapshots default
to PTAX, regardless of which country the account is in.

This is non-negotiable for correct multi-jurisdiction tax tracking.

#### Reporting views

Users can choose which rate type to use as the **display currency base** for any report or portfolio view:

- *"Show my net worth in USD MEP"*
- *"Show my tax liability in USD AFIP"*
- *"Show monthly expenses in ARS"*

The system converts on read using the selected rate type and date. The ledger stores originals only.

#### FX transaction recording

Every cross-currency transaction must record:
- Source amount + source currency (immutable)
- Target amount + target currency (immutable)
- Rate type used (`official_afip`, `mep`, `ccl`, etc.)
- Rate value at time of transaction
- Rate source and timestamp

#### Real-world cases that must work without hacks

- BRL ↔ USD at PTAX rate (Receita Federal tax events for a Brazil resident)
- ARS ↔ USD at official AFIP rate (tax events for Argentina resident)
- ARS ↔ USD at MEP or CCL rate (investment transactions)
- USD positions in a US broker, viewed from a Brazil fiscal residency (PTAX conversion)
- Multi-broker positions across BR/AR/US denominated in different currencies
- Transfers between accounts in different countries and currencies
- Portfolio valuation in any named rate type at any historical date
- A single user with accounts in 3 countries and fiscal residency in a 4th

#### Reference

GnuCash's Trading Accounts model is the strongest available reference for
maintaining ledger balance invariants across currencies. Validate in Phase 1.

---

### Reporting and Projection Model

AurumFinance is **retrospective and projection-based** — not a forward budgeting tool.
Users never pre-assign income. The system learns from imported actuals and surfaces
insights automatically.

#### Core user flow

```
User imports bank/broker statement (e.g., January on Feb 1st)
         ↓
Rules engine classifies transactions automatically
         ↓
System detects recurring patterns from historical data
         ↓
User sees: what happened, what is expected, what looks anomalous
```

#### What the system provides (no user setup required)

**Historical cashflow analysis**
- Income vs expenses by category and period
- Net worth evolution over time
- Per-entity and per-account breakdowns

**Automatic recurring detection**
The system detects recurring items from history — the user never declares them manually:
- Recurring income: salary, rent income, fixed-income payments, dividends
- Recurring expenses: utilities, subscriptions, insurance, loan payments

**Next-month projection**
Based on historical averages and known commitments:
- *"Based on Oct–Jan, energy typically costs ~$100/month"*
- *"Your salary hit on the 3rd every month — not yet seen this month"*
- *"You have a recurring payment that usually appears around the 15th"*

**Tax awareness**
- Track tax-relevant events (asset sales, dividends, interest, FX gains)
- Estimate tax exposure using the fiscally-relevant rate (`official_afip`)
- Surface what to reserve for upcoming tax obligations

**Anomaly alerts**
- *"Transport spend is 40% above your 3-month average this month"*
- *"Expected recurring debit for energy not seen yet — 5 days overdue"*
- *"This transaction looks like a duplicate of one imported last week"*

#### What AurumFinance is NOT

- Not a forward budgeting tool — no pre-assignment of income to categories
- Not a spending coach instructing users how to allocate future money
- The user observes, understands, and is alerted — not assigned homework

#### Design implication

The reporting layer must work entirely from imported data and detected patterns.
Zero configuration should be required to get value from the first import.

---

### Why This Matters (Validation Targets)

- **Correctness:** Avoid transfer double-counting and balance drift.
- **Reconciliation and auditability:** Enable statement matching, duplicate/error
  detection, and full traceability from import source → rules engine → manual edits.
- **Real-world coverage:** Support liabilities (credit cards), FX transactions,
  multi-entity ownership, and investment tracking without ad-hoc hacks.

---

## Phase 1 Execution Steps

1. Prepare research checklist and evidence template for all three products.
2. Gather product documentation and trusted secondary references.
3. Fill comparison matrix across all framework dimensions.
4. **Mark all initial comparison notes as hypotheses** and validate against
   primary documentation during research.
5. Distill design lessons and implications per product for AurumFinance architecture.
6. Validate grouped rules engine model against Firefly III's rules implementation.
7. Validate FX/multi-currency model against GnuCash's Trading Accounts approach.
8. Produce a concise recommendation section for Phase 2 architecture design.

---

## Deliverables

- `llms/tasks/001_research_landscape_analysis/plan.md` containing:
  - objective and scope
  - research topics and comparison framework
  - landscape analysis with per-product lessons and applicability ratings
  - validated grouped rules engine model
  - multi-currency direction
  - ledger model direction
  - execution steps
  - success criteria

## Repository Artifacts

- `llms/tasks/001_research_landscape_analysis/plan.md`
- `docs/adr/0002-ledger-as-internal-double-entry-model.md`
- `docs/adr/0003-grouped-rules-engine.md`
- `docs/adr/0004-immutable-facts-mutable-classification.md`
- `docs/adr/0005-multi-jurisdiction-fx-model.md`
- `docs/adr/0006-retrospective-projection-posture.md`

---

## Success Criteria

- Plan is complete, reviewable, and implementation-free.
- All initial comparison notes are marked as hypotheses with validation targets.
- Grouped rules engine model is fully described with example, explainability
  requirements, and manual edit protection.
- Multi-currency direction is documented with real-world multi-jurisdiction cases (BR/AR/US).
- Comparison notes include applicability ratings (✅ ⚠️ ❌) for each dimension.
- Scope remains aligned with issue #1 without adding implementation work.

---

## Risks and Mitigations

| Risk | Mitigation |
|---|---|
| Bias from prior assumptions about tools | Mark all initial notes explicitly as hypotheses; validate against primary docs |
| Mixing planning with implementation details | Keep outputs at decision/criteria level only; no code tasks in this issue |
| Inconsistent comparison depth across products | Use fixed comparison framework; complete every dimension per product |
| Multi-currency complexity underestimated | Dedicate explicit research step to FX models; use GnuCash as correctness reference |
| Rules engine over-engineered before validation | Validate grouped model against Firefly III's implementation before committing to schema |
