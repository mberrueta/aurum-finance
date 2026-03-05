# Issue #2 Plan - Phase 2: Architecture & System Design

## Objective

Produce a reviewable, implementation-free Phase 2 execution plan that transforms
the validated Phase 1 findings into concrete architecture definitions, domain model
documentation, and architecture decision records for AurumFinance.

Phase 2 does not write code. It produces the design artifacts that make
implementation (starting at M1 - Core Ledger) unambiguous and traceable.

---

## Source Alignment

- Issue: `https://github.com/mberrueta/aurum-finance/issues/2`
- Baseline workflow: `llms/tasks/000_project_plan.md`
- Planning agent guidance: `llms/agents/po_analyst.md`
- Governance baseline: `llms/constitution.md`
- Project domain context: `llms/project_context.md`
- Phase 1 plan (inputs): `llms/tasks/001_research_landscape_analysis/plan.md`

---

## Phase 1 Validated Inputs

These decisions are **settled** and documented as accepted ADRs. Phase 2 builds
on them; it does not revisit them.

| ADR | Decision | Reference |
|-----|----------|-----------|
| ADR-0002 | Internal double-entry ledger with personal-finance UX mapping | `docs/adr/0002-ledger-as-internal-double-entry-model.md` |
| ADR-0003 | Grouped rules engine with per-group priority and explainability | `docs/adr/0003-grouped-rules-engine.md` |
| ADR-0004 | Immutable facts vs mutable classification with manual override protection | `docs/adr/0004-immutable-facts-mutable-classification.md` |
| ADR-0005 | Multi-jurisdiction FX with named rate series and immutable tax snapshots | `docs/adr/0005-multi-jurisdiction-fx-model.md` |
| ADR-0006 | Retrospective + projection posture (non-envelope) | `docs/adr/0006-retrospective-projection-posture.md` |

### Key validated findings carried forward

- Double-entry is internal; UX maps expense/income/transfer/card to posting pairs.
- Rules engine is grouped, not flat. Multiple groups fire per transaction. First match wins within a group.
- Imported data splits into immutable facts and mutable classification.
- Manual user edits are protected via `manually_overridden` / `classified_by` flags.
- FX supports N named rate series per currency pair, scoped by jurisdiction/purpose.
- Fiscal residency drives default tax-relevant FX rates.
- Tax event FX snapshots are immutable once recorded.
- Ledger stores originals; conversions are derived on read.
- Multi-entity is a gap none of the researched tools solve well.

---

## In-Scope

- Define the domain model with entity relationships, bounded contexts, and ownership boundaries.
- Define ledger architecture: account types, posting model, balance derivation, and invariants.
- Define the multi-entity model: how multiple legal/fiscal entities coexist under one installation.
- Define ingestion pipeline architecture: import flow from raw file to classified postings.
- Produce architecture decision records for open design questions (listed below).
- Update `docs/architecture.md` and `docs/domain-model.md` from draft stubs to substantive documents.
- Frame all decisions as design artifacts with rationale — no code, no schemas, no migrations.

## Out of Scope

- Application code changes in `lib/`, `test/`, `config/`, or assets.
- Database migrations, Ecto schemas, or runtime behavior.
- UI wireframes, LiveView implementation, or API endpoint design.
- Revisiting Phase 1 decisions (ADRs 0002-0006 are accepted).
- Deployment architecture, infrastructure, or CI/CD pipeline design.

---

## Scope Expansion (Approved)

On 2026-03-05, maintainers approved extending Phase 2 planning scope to add
foundational ADRs that were identified as missing architecture baselines:

- ADR-0014: Core financial domain model
- ADR-0015: Account model and instrument types
- ADR-0016: Investment tracking model (architectural baseline, implementation still deferred to M5)
- ADR-0017: Reporting and read model architecture (architectural baseline, implementation still deferred to M4)
- ADR-0018: Financial data security boundaries (architectural baseline for future AI/MCP and security work)

This expansion remains implementation-free and consistent with Issue #2's
planning objective.

---

## Scope Restatement (Issue-Driven)

Tied to the acceptance criteria from GitHub Issue #2:

- Deliver one planning artifact at `llms/tasks/002_architecture_system_design/plan.md`.
- Define explicit architecture outputs (docs and ADRs) to be produced during Phase 2 execution.
- Plan clearly defines research topics, deliverables, and decision points.
- Plan keeps execution sequencing explicit and review-ready.
- Planning only — no code implementation.

---

## Architecture Decision Points (Open Questions for Phase 2)

These are the design questions Phase 2 must answer. Each produces an ADR or
a section in the architecture/domain-model documents. The questions are framed
here; the answers are produced during execution.

### DP-1: Bounded Context Boundaries

**Question:** How should AurumFinance partition its domain into Elixir contexts
(modules under `lib/aurum_finance/`)?

**Considerations:**
- Which entities belong together vs which deserve their own context?
- Where do the seams fall between ledger, ingestion, rules, reconciliation, and FX?
- How do contexts communicate — direct function calls, or explicit boundary APIs?
- What is the dependency direction between contexts (which depends on which)?
- How does multi-tenancy (multi-entity) cut across context boundaries?

**Inputs:** ADR-0002 (ledger model), ADR-0003 (rules engine), ADR-0004 (fact/classification split), project_context.md (product invariants).

### DP-2: Ledger Schema Design

**Question:** What is the concrete structure of the ledger's core entities —
accounts, transactions, postings, and their relationships?

**Considerations:**
- Account type hierarchy (Asset, Liability, Equity, Income, Expense) and how account trees are modeled.
- Transaction-to-posting relationship: one transaction to N posting lines, summing to zero per currency.
- How splits are represented (multiple postings under one transaction vs a separate split model).
- Balance derivation strategy: computed on read from postings, or cached with invalidation?
- Soft delete vs hard delete semantics for corrections and voids.
- How the ledger enforces the zero-sum invariant at the database level (check constraints, application logic, or both).

**Inputs:** ADR-0002 (double-entry model), GnuCash reference from Phase 1 research.

### DP-3: Multi-Entity Model

**Question:** How does AurumFinance model multiple legal/fiscal entities under
a single installation?

**Considerations:**
- What is an "entity"? (Person, company, trust, household — or a generic ownership wrapper.)
- Tenant isolation: shared database with entity_id scoping, or separate schemas/databases?
- Which data is entity-scoped (accounts, transactions, rules) vs global (currencies, rate series)?
- Cross-entity visibility: can one user see multiple entities? Can reports span entities?
- How does multi-entity interact with fiscal residency (one entity can have different residency than another)?
- What is the relationship between user accounts (authentication) and entities (data ownership)?

**Inputs:** ADR-0005 (multi-jurisdiction FX), Phase 1 finding that multi-entity is a gap in all researched tools.

### DP-4: Ingestion Pipeline Architecture

**Question:** What is the architecture of the import-to-posting pipeline?

**Considerations:**
- Pipeline stages: file upload, format detection, parsing, normalization, deduplication, classification, posting creation.
- Where does the fact/classification split happen in the pipeline?
- How are import files tracked (source file metadata, import batch identity, row-level provenance)?
- Deduplication strategy: what constitutes a duplicate? (institution ID, amount+date+description hash, user confirmation?)
- How does the pipeline integrate with the rules engine (inline or as a separate pass)?
- Preview-before-commit workflow: how does the user review and approve before postings are created?
- Error handling: partial imports, malformed rows, encoding issues.
- Idempotency: what happens when the same file is imported twice?
- Extensibility: how are new file formats (CSV variants, OFX, QIF) added?

**Inputs:** ADR-0004 (immutable facts / mutable classification), ADR-0003 (grouped rules engine), Firefly III's separate importer pattern from Phase 1.

### DP-5: Rules Engine Data Model

**Question:** How are rule groups, rules, conditions, and actions stored and
evaluated?

**Considerations:**
- Rule group schema: name, purpose, execution order.
- Rule schema within a group: priority, conditions (field + operator + value), actions (field + value).
- Condition evaluation: how are conditions composed (AND/OR)? What operators are supported (contains, matches regex, equals, greater_than, etc.)?
- Action types: set field value, add tag, set investment type. Are actions extensible?
- How is the `classified_by` provenance recorded (which group, which rule, which field)?
- How does `manually_overridden` interact with rule evaluation at the storage level?
- Rule versioning: what happens when rules change after transactions were classified?
- Performance: how is the engine evaluated efficiently for bulk imports (hundreds/thousands of transactions)?

**Inputs:** ADR-0003 (grouped rules engine), ADR-0004 (manual override protection), Firefly III rules pipeline from Phase 1.

### DP-6: FX Rate Storage and Lookup Model

**Question:** How are FX rates stored, versioned, and queried for both reporting
and tax event snapshots?

**Considerations:**
- Rate series identity: currency pair + rate type name + jurisdiction.
- Rate granularity: daily, intraday, or event-specific?
- Rate source tracking: where did this rate come from and when was it fetched?
- Tax snapshot immutability: how is the link between a tax event and its rate snapshot enforced?
- Rate lookup API: given a currency pair, rate type, and date, return the applicable rate.
- Missing rate handling: what happens when no rate exists for a given date? (Nearest available, interpolation, error?)
- Bulk rate ingestion: how are historical rate series loaded?

**Inputs:** ADR-0005 (multi-jurisdiction FX model), GnuCash Trading Accounts reference.

### DP-7: Reconciliation Workflow Model

**Question:** How does statement-level reconciliation work in the data model?

**Considerations:**
- Reconciliation states: unreconciled, cleared, reconciled (following GnuCash model from Phase 1).
- What triggers state transitions? (User action, automatic matching, import confirmation.)
- Statement-to-posting matching: how are imported rows matched to existing postings?
- Discrepancy tracking: how are mismatches surfaced and recorded?
- Correction history: when a reconciled posting is corrected, what happens to the reconciliation state?

**Inputs:** GnuCash reconciliation workflow from Phase 1, ADR-0002 (ledger model).

---

## Deliverables

### Documents to produce (updates to existing files)

| # | Deliverable | Location | Description |
|---|-------------|----------|-------------|
| D-1 | Architecture document (substantive update) | `docs/architecture.md` | Expand from current draft stub to full architecture overview: context map, data flow, integration points, key invariants. |
| D-2 | Domain model document (substantive update) | `docs/domain-model.md` | Expand from current draft stub to full domain model: entities, relationships, bounded contexts, ownership, and lifecycle. |

### ADRs to produce (new files)

| # | ADR | Planned location | Decision point |
|---|-----|------------------|----------------|
| D-3 | Bounded context boundaries | `docs/adr/0007-bounded-context-boundaries.md` | DP-1 |
| D-4 | Ledger schema design | `docs/adr/0008-ledger-schema-design.md` | DP-2 |
| D-5 | Multi-entity ownership model | `docs/adr/0009-multi-entity-ownership-model.md` | DP-3 |
| D-6 | Ingestion pipeline architecture | `docs/adr/0010-ingestion-pipeline-architecture.md` | DP-4 |
| D-7 | Rules engine data model | `docs/adr/0011-rules-engine-data-model.md` | DP-5 |
| D-8 | FX rate storage and lookup | `docs/adr/0012-fx-rate-storage-and-lookup.md` | DP-6 |
| D-9 | Reconciliation workflow model | `docs/adr/0013-reconciliation-workflow-model.md` | DP-7 |
| D-10 | Core financial domain model | `docs/adr/0014-core-financial-domain-model.md` | Scope expansion |
| D-11 | Account model and instrument types | `docs/adr/0015-account-model-and-instrument-types.md` | Scope expansion |
| D-12 | Investment tracking model | `docs/adr/0016-investment-tracking-model.md` | Scope expansion |
| D-13 | Reporting and read model architecture | `docs/adr/0017-reporting-and-read-model-architecture.md` | Scope expansion |
| D-14 | Financial data security boundaries | `docs/adr/0018-financial-data-security-boundaries.md` | Scope expansion |

### Planning artifact

| # | Deliverable | Location |
|---|-------------|----------|
| D-15 | This plan | `llms/tasks/002_architecture_system_design/plan.md` |

---

## Execution Steps

Each step is sequenced. Steps within the same group may be parallelized where
noted. All steps are planning/design only.

### Step 1: Establish Context Map and Bounded Contexts (DP-1)

**Goal:** Define the Elixir context structure for the entire application.

**Activities:**
1. Enumerate all domain concepts from Phase 1 findings and product invariants.
2. Group concepts into candidate bounded contexts based on cohesion, coupling, and ownership.
3. Define dependency direction between contexts (acyclic graph).
4. Document context responsibilities and public API surface (function signatures, not implementations).
5. Identify where multi-entity scoping applies within each context.

**Outputs:** ADR-0007, initial structure for `docs/domain-model.md`.

**Assigned agent:** `tl-architect`

**Review gate:** Maintainer reviews context boundaries before proceeding to per-context design.

---

### Step 2: Design Ledger Core (DP-2)

**Goal:** Define the ledger's entity model, posting invariants, and balance derivation strategy.

**Activities:**
1. Define account type hierarchy and account tree model.
2. Define transaction and posting entity structures with their relationships.
3. Specify zero-sum invariant enforcement strategy.
4. Define balance derivation approach (computed vs cached).
5. Document how UX concepts (expense, income, transfer, card purchase, card payment) map to posting pairs.
6. Address soft delete / void / correction semantics.

**Outputs:** ADR-0008, ledger section of `docs/domain-model.md`.

**Assigned agent:** `tl-architect`

**Dependencies:** Step 1 (context boundaries define where ledger entities live).

---

### Step 3: Design Multi-Entity Model (DP-3)

**Goal:** Define how multiple legal/fiscal entities coexist and are isolated.

**Activities:**
1. Define the entity concept (what it represents, what it scopes).
2. Choose isolation strategy (entity_id column scoping vs schema separation).
3. Define relationship between authentication users and data-owning entities.
4. Specify which data is entity-scoped vs global.
5. Define cross-entity reporting boundaries.
6. Document interaction between entity and fiscal residency.

**Outputs:** ADR-0009, multi-entity section of `docs/domain-model.md`.

**Assigned agent:** `tl-architect`

**Dependencies:** Step 1 (context boundaries), Step 2 (ledger model — entities own accounts and postings).

---

### Step 4: Design Ingestion Pipeline (DP-4)

**Goal:** Define the import-to-posting pipeline architecture.

**Activities:**
1. Define pipeline stages and their responsibilities.
2. Specify the fact/classification split point in the pipeline.
3. Define import batch and file tracking model.
4. Define deduplication strategy and conflict resolution.
5. Design preview-before-commit workflow (data flow, user interactions, state management).
6. Specify error handling for partial imports and malformed data.
7. Define idempotency guarantees.
8. Document extensibility model for new file formats.

**Outputs:** ADR-0010, ingestion section of `docs/architecture.md`.

**Assigned agent:** `tl-architect`

**Dependencies:** Step 1 (context boundaries), Step 2 (ledger model — pipeline creates postings), Step 5 (rules engine — pipeline invokes classification).

**Note:** Steps 4 and 5 have a circular dependency (pipeline invokes rules; rules
act on imported data). These should be designed together by the same agent in a
single pass, with the ADRs produced as separate documents referencing each other.

---

### Step 5: Design Rules Engine Data Model (DP-5)

**Goal:** Define how rule groups, rules, conditions, and actions are stored and evaluated.

**Activities:**
1. Define rule group and rule entity structures.
2. Specify condition model (operators, composition logic, supported fields).
3. Specify action model (field assignments, tag additions, extensibility).
4. Define `classified_by` provenance recording.
5. Define `manually_overridden` interaction with rule evaluation.
6. Address rule versioning and change impact on historical classifications.
7. Specify performance strategy for bulk evaluation.

**Outputs:** ADR-0011, rules engine section of `docs/domain-model.md`.

**Assigned agent:** `tl-architect`

**Dependencies:** Step 1 (context boundaries), Step 2 (ledger model — rules classify postings/transactions).

**Note:** Design jointly with Step 4 (see note above).

---

### Step 6: Design FX Rate Storage and Lookup (DP-6)

**Goal:** Define how FX rates are stored, queried, and snapshotted for tax events.

**Activities:**
1. Define rate series identity model (pair + type + jurisdiction).
2. Define rate record structure (date, value, source, timestamp).
3. Specify tax snapshot immutability enforcement.
4. Define rate lookup API semantics (exact date, nearest, fallback).
5. Address missing rate scenarios and error behavior.
6. Define bulk rate ingestion model.

**Outputs:** ADR-0012, FX section of `docs/domain-model.md`.

**Assigned agent:** `tl-architect`

**Dependencies:** Step 1 (context boundaries), Step 3 (multi-entity — fiscal residency is per-entity).

---

### Step 7: Design Reconciliation Workflow (DP-7)

**Goal:** Define reconciliation states, transitions, and matching model.

**Activities:**
1. Define reconciliation state machine (unreconciled, cleared, reconciled).
2. Specify state transition triggers and guards.
3. Define statement-to-posting matching strategy.
4. Specify discrepancy tracking model.
5. Address correction impact on reconciliation state.

**Outputs:** ADR-0013, reconciliation section of `docs/domain-model.md`.

**Assigned agent:** `tl-architect`

**Dependencies:** Step 2 (ledger model — reconciliation operates on postings), Step 4 (ingestion — imports trigger reconciliation).

---

### Step 8: Consolidate Architecture Document (D-1)

**Goal:** Update `docs/architecture.md` from its current draft stub to a
substantive architecture overview.

**Activities:**
1. Write context map showing all bounded contexts and their relationships.
2. Document data flow from import to posting to reporting.
3. Summarize key invariants and cross-cutting concerns.
4. Reference all ADRs produced in Steps 1-7.
5. Include a high-level component diagram (text-based, Mermaid or ASCII).

**Outputs:** Updated `docs/architecture.md`.

**Assigned agent:** `tl-architect`

**Dependencies:** Steps 1-7 (all design work must be complete).

---

### Step 9: Consolidate Domain Model Document (D-2)

**Goal:** Update `docs/domain-model.md` from its current draft stub to a
substantive domain model reference.

**Activities:**
1. Document all entities, their fields (conceptual, not Ecto schema), and relationships.
2. Organize by bounded context.
3. Include entity lifecycle descriptions where relevant.
4. Include an entity relationship diagram (text-based, Mermaid or ASCII).
5. Reference ADRs for design rationale.

**Outputs:** Updated `docs/domain-model.md`.

**Assigned agent:** `tl-architect`

**Dependencies:** Steps 1-7 (all design work must be complete).

---

### Step 10: Review and Handoff

**Goal:** Validate that all deliverables are complete, consistent, and ready
for implementation planning.

**Activities:**
1. Verify each ADR follows the project's ADR format (see existing ADRs 0002-0006 for template).
2. Cross-check that `docs/architecture.md` and `docs/domain-model.md` are consistent with ADRs.
3. Verify that all decision points (DP-1 through DP-7) have been answered.
4. Validate terminology against `llms/project_context.md` and `llms/constitution.md`.
5. Confirm that no implementation work was introduced (no code, no schemas, no migrations).
6. Produce a handoff summary listing what is ready for M1 implementation.

**Outputs:** Review notes, updated plan status.

**Assigned agent:** `po-analyst`

**Dependencies:** Steps 8-9 (consolidated documents).

---

## Execution Sequencing Summary

```
Step 1: Context Map / Bounded Contexts (DP-1)
  |
  +---> Step 2: Ledger Core (DP-2)
  |       |
  |       +---> Step 3: Multi-Entity (DP-3)
  |       |       |
  |       |       +---> Step 6: FX Rates (DP-6)
  |       |
  |       +---> Steps 4+5: Ingestion + Rules (DP-4, DP-5) [designed jointly]
  |       |
  |       +---> Step 7: Reconciliation (DP-7)
  |
  +---> (all above complete)
          |
          +---> Step 8: Architecture Doc (D-1)
          +---> Step 9: Domain Model Doc (D-2)  [parallel with Step 8]
          |
          +---> Step 10: Review & Handoff
```

---

## Success Criteria

- All seven decision points (DP-1 through DP-7) are answered with explicit design decisions.
- Seven new ADRs (0007-0013) are produced, following the format of existing ADRs 0002-0006.
- Additional foundational ADRs (0014-0018) are produced and explicitly marked as approved scope expansion.
- `docs/architecture.md` is expanded from stub to substantive architecture overview.
- `docs/domain-model.md` is expanded from stub to substantive domain model reference.
- All deliverables are implementation-free (no Ecto schemas, no migration SQL, no runtime code).
- Terminology is consistent with `llms/project_context.md` and existing ADRs.
- Phase 1 decisions (ADRs 0002-0006) are respected, not revisited.
- Each ADR provides sufficient design clarity for a developer to begin implementation without ambiguity.
- The plan is traceable: every deliverable maps to a decision point, and every decision point maps to Phase 1 inputs.

---

## Risks and Mitigations

| Risk | Impact | Mitigation |
|------|--------|------------|
| Multi-entity model is under-specified and creates schema churn during M1 | High | DP-3 is explicitly sequenced before ingestion/rules design; force the entity-scoping decision early. |
| Ledger schema design drifts into implementation detail (premature Ecto schemas) | Medium | Constitution guardrail: no code in this issue. Review gate at Step 10 enforces this. |
| Ingestion and rules engine design creates circular dependency | Medium | Steps 4 and 5 are designed jointly in a single pass by the same agent. |
| FX rate model complexity leads to over-engineering before real usage | Medium | Scope FX design to storage and lookup only; defer rate ingestion automation to M6. |
| Bounded context boundaries are drawn too early and need revision | Medium | Step 1 output is a proposal reviewed before per-context design begins. Context boundaries can be revised during Steps 2-7 if needed, with Step 1 ADR amended. |
| Reconciliation design overlaps with ingestion deduplication | Low | Explicitly distinguish deduplication (same source, same file) from reconciliation (matching against existing postings from different sources). |
| Decision paralysis on multi-entity isolation strategy | Medium | Frame DP-3 as a binary choice (entity_id scoping vs schema separation) with clear trade-off analysis; force a decision rather than deferring. |
| Phase 2 scope creep beyond approved architecture baseline | Low | Scope expansion is explicitly documented and limited to ADR-level design (no implementation detail). |

---

## Agent Assignment Summary

| Agent | Steps | Responsibility |
|-------|-------|----------------|
| `tl-architect` | 1, 2, 3, 4, 5, 6, 7, 8, 9 | All design work: ADRs, architecture doc, domain model doc |
| `po-analyst` | 10 | Final review, terminology validation, handoff |

---

## Relationship to Milestones

Phase 2 outputs feed directly into implementation milestones:

| Phase 2 Output | Implementation Milestone |
|----------------|--------------------------|
| ADR-0007 (Context boundaries) | M1 — Core Ledger (project structure) |
| ADR-0008 (Ledger schema) | M1 — Core Ledger |
| ADR-0009 (Multi-entity model) | M1 — Core Ledger |
| ADR-0010 (Ingestion pipeline) | M2 — Import Pipeline |
| ADR-0011 (Rules engine data model) | M3 — Rules Engine |
| ADR-0012 (FX rate storage) | M6 — Tax Awareness |
| ADR-0013 (Reconciliation workflow) | M2 — Import Pipeline |
| ADR-0014 (Core financial domain model) | M1-M6 (cross-cutting finance semantics) |
| ADR-0015 (Account model and instrument types) | M1, M5 |
| ADR-0016 (Investment tracking model) | M5 — Investments |
| ADR-0017 (Reporting/read model architecture) | M4 — Reporting |
| ADR-0018 (Financial data security boundaries) | M7 + cross-milestone governance |
| `docs/architecture.md` | All milestones (reference) |
| `docs/domain-model.md` | All milestones (reference) |
