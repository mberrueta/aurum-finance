# Task 06.b: Audit Masking for tax_identifier

## Status
- **Status**: ✅ COMPLETED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 06
- **Blocks**: Task 07

## Assigned Agent
`dev-backend-elixir-engineer` - Implements audit masking behavior safely in context/audit integration.

## Agent Invocation
Use `llms/agents/dev_backend_elixir_engineer.md` (`name: dev-backend-elixir-engineer`) to implement masking for `tax_identifier` in entity audit snapshots.

## Objective
Reduce PII exposure by masking `tax_identifier` in `before`/`after` audit payloads for entity create/update/archive/unarchive flows.

## Inputs Required
- [x] `llms/tasks/010_entity_model/06_security_architecture_handoff.md`
- [x] `lib/aurum_finance/entities.ex`
- [x] `lib/aurum_finance/audit.ex`
- [x] `test/aurum_finance/entities_test.exs`

## Expected Outputs
- [x] Entity audit integration masks `tax_identifier` in snapshots.
- [x] Existing audit shape remains unchanged (`entity_type`, `entity_id`, `action`, `actor`, `channel`, `before`, `after`, `occurred_at`).
- [x] Tests assert masked behavior for `tax_identifier`.

## Acceptance Criteria
- [x] `tax_identifier` never appears in clear text inside `audit_events.before`/`audit_events.after` for entities.
- [x] Masking applies consistently to create/update/archive/unarchive events.
- [x] No regression in existing audit logging behavior.
- [x] `mix test` passes for touched tests.

## Technical Notes
### Relevant Code Locations
`lib/aurum_finance/entities.ex`  
`lib/aurum_finance/audit.ex`  
`test/aurum_finance/entities_test.exs`

### Constraints
- Keep `tax_identifier` storage in Entity unchanged (only mask in audit payloads).
- Do not add country-format validation for `tax_identifier` (explicitly out of scope).

## Execution Summary
- Implemented masking via `@audit_redact_fields [:tax_identifier]` in entity audit integration (already present from Task 06 follow-up).
- Added assertions in `test/aurum_finance/entities_test.exs` to verify masked snapshots in create/update/archive/unarchive audit events.
- Fixed audit redaction traversal in `AurumFinance.Audit` to avoid JSON encoding failures caused by struct internals (`DateTime` tuple fields) during recursive redaction.
- Added safe serialization clauses for temporal and decimal structs in snapshot stringification.
- Validation run:
  - `mix format lib/aurum_finance/audit.ex test/aurum_finance/entities_test.exs`
  - `mix test test/aurum_finance/entities_test.exs` (pass)
