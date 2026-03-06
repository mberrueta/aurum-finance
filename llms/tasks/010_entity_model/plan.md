# Execution Plan: Issue #10 - Entity Model (Person / Legal Entity + Ownership)

## Metadata
- **Spec**: `https://github.com/mberrueta/aurum-finance/issues/10`
- **Created**: 2026-03-06
- **Updated**: 2026-03-06
- **Status**: PLANNED
- **Current Task**: 06 (ready after Task 05 review)

## Overview
Issue #10 establishes the multi-entity ownership foundation for M1. In AurumFinance, **Entity is the tenant/ownership boundary** for financial data. This plan delivers the entity model, LiveView CRUD (including archive), and a **generic audit_events** foundation so every entity change is traceable (who, when, old/new values) from day one.

This work is explicitly aligned with ADR-0009 and the domain model guidance:
- multi-entity ownership model
- entity as tenant boundary
- fiscal residency as an entity property
- soft archive / no hard delete posture
- explainability and auditability expectations

## Scope Restatement (Issue-Driven)
- Introduce the `Entity` model with ADR-aligned taxonomy and fiscal fields.
- Deliver Entities CRUD LiveView: list, new, edit, archive.
- Enforce soft-delete via `archived_at` only (no hard delete paths).
- Establish ownership foundation for downstream account/holding work:
  - accounts are entity-scoped
  - holdings are entity-scoped
- Implement a **generic** `audit_events` model and log all entity changes.
- Perform a final documentation sync pass across docs/ADRs/README and planning artifacts touched by these decisions.

## Acceptance Criteria Mapping
| Acceptance Criterion | Planned Delivery |
|---|---|
| Entity schema: id, name, type, tax identifier, notes, inserted_at, updated_at | `AurumFinance.Entities.Entity` schema + migration with required fields, including ADR-aligned extensions (`country_code`, fiscal residency defaults, `archived_at`) |
| Entities CRUD LiveView (list, new, edit, archive) | `AurumFinanceWeb.EntitiesLive` with list/new/edit/archive flows, route integration, and app-shell navigation |
| Soft-delete (archive) — never hard delete | Archive implemented via `archived_at`; no delete APIs exposed in context or UI |
| Entity can own accounts, holdings | Ownership boundary codified in entities APIs/contracts and documented as foundation for #11 (accounts) and #27 (holdings) |
| Audit trail: every change logged (who, when, old/new values) | Generic `audit_events` table/model used for entity create/update/archive with `before`/`after` snapshots and actor/channel metadata |

## Canonical Domain Decisions (Applied)

### Entity type enum
Use exactly:
- `:individual`
- `:legal_entity`
- `:trust`
- `:other`

### Entity fields (minimum required)
- `id`
- `name`
- `type`
- `tax_identifier`
- `country_code` (`:string`)
- `fiscal_residency_country_code`
- `default_tax_rate_type`
- `notes`
- `archived_at`
- `inserted_at`
- `updated_at`

Notes:
- Use `tax_identifier` (never `tax_id`).
- `tax_identifier` is a real-world fiscal/legal identifier (CPF/CNPJ/CUIL-CUIT/SSN-TIN-EIN/RUT/etc.), not a database key.

### Archive model
- Primary mechanism: `archived_at`.
- No hard delete paths in context or LiveView.

### Generic audit model
Use a shared `audit_events` concept/table/model from the start, with at least:
- `entity_type`
- `entity_id`
- `action`
- `actor` (string)
- `channel` (supports `web`, `system`, `mcp`, `ai_assistant`)
- `before`
- `after`
- `occurred_at`

Actor format decision (single-user rationale):
- `actor` is a plain string (`"system"`, `"person"`, `"scheduler"`, etc.).
- We intentionally avoid a structured map because this is a single-user application and actor IDs do not add meaningful value now.
- This keeps schema/API simpler while preserving audit readability.

## Project Context and ADR Alignment

### Ownership and tenancy
- `Entity` is the ownership and tenant boundary for financial domain data.
- Accounts must be entity-scoped (`entity_id`) in upcoming Issue #11.
- Holdings must be entity-scoped (`entity_id`) in upcoming Issue #27.
- This issue establishes that boundary contract and foundational model now.

### Fiscal residency alignment
- Fiscal residency belongs to entity (`fiscal_residency_country_code`, `default_tax_rate_type`) per ADR/domain docs.
- Decision: `fiscal_residency_country_code` defaults at write time from `country_code` when omitted.

### Traceability alignment
- Entity lifecycle changes are captured as append-only audit events.
- `before`/`after` payloads provide explainability and operational auditability.

## Terminology Alignment
| Deprecated/Do Not Use | Canonical Term | Reason |
|---|---|---|
| `:person`, `:company` | `:individual`, `:legal_entity` | ADR/domain-aligned taxonomy |
| `tax_id` | `tax_identifier` | Clear fiscal/legal semantics |
| entity-specific ad hoc audit table | generic `audit_events` | Cross-domain audit foundation |
| `is_active` as primary archive flag | `archived_at` | Soft archive posture with temporal trace |

## Implementation Tasks

### Task 01 - Domain + Data Model Foundation
- **Agent**: `dev-backend-elixir-engineer`
- **Goal**: Introduce `Entities` context and canonical `Entity` schema/migration.
- **Deliverables**:
  - Migration for `entities` table with canonical fields listed above.
  - `AurumFinance.Entities.Entity` schema with enum type:
    - `:individual`, `:legal_entity`, `:trust`, `:other`
  - Context API baseline:
    - `list_entities/1`
    - `get_entity!/1`
    - `create_entity/1`
    - `update_entity/2`
    - `archive_entity/1` (sets `archived_at`)
  - Explicit omission of any hard-delete API.
  - `tax_identifier` has no unique restriction.
  - Archived entities remain editable through standard update flows.
- **Output file**: `llms/tasks/010_entity_model/01_domain_data_model_foundation.md`

### Task 02 - Generic Audit Events Foundation
- **Agent**: `dev-backend-elixir-engineer`
- **Goal**: Implement reusable `audit_events` model and integrate with entities changes.
- **Deliverables**:
  - Migration + schema for `audit_events` with canonical shape:
    - `entity_type`, `entity_id`, `action`, `actor`, `channel`, `before`, `after`, `occurred_at`
  - Context/service API to append events transactionally during entity mutations.
  - Channels support includes: `web`, `system`, `mcp`, `ai_assistant`.
  - Entity operations (create/update/archive) must emit audit events with before/after snapshots.
- **Output file**: `llms/tasks/010_entity_model/02_generic_audit_events_foundation.md`

### Task 03 - Entities CRUD LiveView
- **Agent**: `dev-frontend-ui-engineer`
- **Goal**: Ship list/new/edit/archive UI in authenticated app shell.
- **Deliverables**:
  - New `EntitiesLive` route and navigation entry.
  - List behavior decision:
    - show active entities by default
    - provide explicit toggle/control to include archived entities
  - Create/edit forms using `<.form for={@form}>` and `<.input>` patterns.
  - Archive action wired to `archive_entity/1` (no delete UI).
  - Stable DOM IDs for testability.
- **Output file**: `llms/tasks/010_entity_model/03_entities_crud_liveview.md`

### Task 04 - Ownership Boundary Contract for Downstream Contexts
- **Agent**: `tl-architect`
- **Goal**: Encode and document ownership invariants consumed by #11/#27.
- **Deliverables**:
  - Explicit contract note: every account/holding row must reference `entity_id`.
  - Interface notes for downstream contexts to accept entity scope in public APIs.
  - Implementation guardrails to prevent cross-entity leakage by default query patterns.
- **Output file**: `llms/tasks/010_entity_model/04_ownership_boundary_contract.md`

### Task 05 - Test Coverage
- **Agent**: `qa-elixir-test-author`
- **Goal**: Cover entity model, archive behavior, CRUD flows, and audit creation.
- **Coverage targets**:
  - Entity changeset validations (enum, required fields, field semantics).
  - `archive_entity/1` sets `archived_at` and does not delete.
  - No hard-delete function/path exists in context behavior.
  - Audit events emitted with expected shape for create/update/archive.
  - Fiscal residency behavior test (required): write-time default from `country_code` when omitted.
  - LiveView tests for list/new/edit/archive interactions via explicit element IDs.
- **Output file**: `llms/tasks/010_entity_model/05_test_coverage.md`

### Task 06 - Security/Architecture Review + Handoff
- **Agent**: `audit-security` + `rm-release-manager`
- **Goal**: Validate posture and document operator-facing behavior.
- **Checks**:
  - Soft archive only, no hard-delete paths.
  - Audit events include actor/channel/occurred_at/before/after.
  - No leakage of sensitive `tax_identifier` values via logs/flash/debug output.
  - Handoff notes explain how this issue unblocks entity-scoped accounts/holdings.
- **Output file**: `llms/tasks/010_entity_model/06_security_architecture_handoff.md`

### Task 07 - Documentation and ADR/README Sync
- **Agent**: `docs-feature-documentation-author` + `tl-architect`
- **Goal**: Ensure all documentation reflects the implemented canonical model.
- **Checks**:
  - Update all relevant references in `README.md`, `docs/domain-model.md`, `docs/architecture.md`, and applicable ADRs.
  - Replace deprecated terminology (`person/company`, `tax_id`, `is_active` archive language) with canonical terms.
  - Confirm docs consistently state: `archived_at` soft-archive, generic `audit_events`, entity ownership boundary for accounts/holdings.
  - Verify milestone/task artifacts remain aligned (`llms/tasks/...` summaries and outputs).
- **Output file**: `llms/tasks/010_entity_model/07_documentation_sync.md`

## Task Sequence

| # | Task | Status | Approved | Dependencies |
|---|------|--------|----------|--------------|
| 01 | Domain + Data Model Foundation | ⏳ PENDING | [ ] | None |
| 02 | Generic Audit Events Foundation | ⏳ PENDING | [ ] | Task 01 |
| 03 | Entities CRUD LiveView | ✅ COMPLETED | [ ] | Task 01 |
| 04 | Ownership Boundary Contract for Downstream Contexts | ✅ COMPLETED | [ ] | Task 01 |
| 05 | Test Coverage | ✅ COMPLETED | [ ] | Tasks 02, 03 |
| 06 | Security/Architecture Review + Handoff | ⏳ PENDING | [ ] | Task 05 |
| 07 | Documentation and ADR/README Sync | ⏳ PENDING | [ ] | Task 06 |

## Schema and Audit Assumptions
1. `entities.id` remains UUID aligned with project conventions.
2. `tax_identifier` is optional at DB level unless product policy requires mandatory per entity type (to be confirmed in Task 01 validation).
3. `country_code`/`fiscal_residency_country_code` use string storage with validation in changesets.
4. `audit_events.before` and `audit_events.after` are structured JSON-like payloads suitable for explainability and later domain reuse.
5. `audit_events.actor` is a string by design (single-user simplification).
6. `occurred_at` is explicitly stored (append-only semantics) and not inferred solely from insertion timestamp.

## Open Questions (To Resolve Before Implementation Freeze)
- None at this stage. Core modeling decisions are resolved.

## Validation Plan
- Add/expand ExUnit coverage for context and audit integration.
- Add LiveView tests for list/new/edit/archive flows with stable selectors.
- Run:
  - `mix test`
  - `mix precommit`
- Resolve all warnings/errors before handoff.

## Change Log
| Date | Item | Change | Reason |
|---|---|---|---|
| 2026-03-06 | Plan | Initial issue #10 plan created | Start planning workflow |
| 2026-03-06 | Plan | Revised for ADR/domain alignment and canonical field/type/audit decisions | Align with staff-level architecture requirements |
| 2026-03-06 | Plan | Open questions resolved: fiscal residency write-default, non-unique tax_identifier, archived entities editable | Remove ambiguity before Task 02 |
| 2026-03-06 | Plan | Actor format revised to string (not map) with single-user rationale documented | Keep audit model pragmatic for current architecture |
