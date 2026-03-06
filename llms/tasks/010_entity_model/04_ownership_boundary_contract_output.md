# Ownership Boundary Contract (Issue #10 -> #11/#27)

## Purpose
This contract formalizes how Issue #10 (Entity model) defines ownership boundaries consumed by:
- Issue #11: Account model
- Issue #27: Instruments & holdings model

## Canonical Boundary
1. `Entity` is the tenant and ownership boundary for financial domain data.
2. Entity-scoped records must be queryable and writable only within one `entity_id` scope.
3. No implicit cross-entity merge is allowed in domain write paths.

## Required Invariants
1. Accounts are entity-scoped:
   - Every account row must carry `entity_id` (not null, FK to entities).
   - Account queries in public context APIs must include entity scope.
2. Holdings are entity-scoped:
   - Every holding/position row must carry `entity_id` (not null, FK to entities).
   - Holding queries in public context APIs must include entity scope.
3. Ownership consistency:
   - A transaction/posting/holding mutation cannot reference objects from different entities unless explicitly modeled as a cross-entity operation.
4. Archive posture:
   - Entities are never hard deleted; `archived_at` is the lifecycle flag.
   - Downstream contexts must tolerate archived owner entities for historical reads.

## Public API Guardrails for Downstream Contexts
1. Public listing/query functions should accept an explicit entity scope argument (`entity` or `entity_id`) and enforce it.
2. Internal query builders should bake entity filtering early (`where: schema.entity_id == ^entity_id`) to reduce leakage risk.
3. Cross-entity reporting remains read-only and explicit (`WHERE entity_id IN (...)`), never default behavior for operational context APIs.

## Fiscal Residency Alignment
1. Fiscal residency is a property of Entity, not Account/Holding.
2. Downstream tax/FX logic reads fiscal defaults from the owning entity (`fiscal_residency_country_code`, `default_tax_rate_type`).
3. Entity write semantics remain:
   - `fiscal_residency_country_code` defaults from `country_code` when omitted.

## Auditability Alignment
1. Entity lifecycle changes are logged via generic `audit_events`.
2. Downstream contexts should reuse the same audit event model shape (`entity_type`, `entity_id`, `action`, `actor`, `channel`, `before`, `after`, `occurred_at`) for consistency.

## Implementation Checklist for #11 (Accounts)
- Add `entity_id` FK + not-null constraint.
- Require entity scope in public list/get/create/update APIs.
- Add tests proving no cross-entity leakage in queries.

## Implementation Checklist for #27 (Holdings)
- Add `entity_id` FK + not-null constraint.
- Require entity scope in public list/get/create/update APIs.
- Add tests proving no cross-entity leakage in queries.

## References
- `docs/domain-model.md`
- `docs/architecture.md`
- `docs/adr/0009-multi-entity-ownership-model.md`
