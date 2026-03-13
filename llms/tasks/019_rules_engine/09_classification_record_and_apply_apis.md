# Task 09: ClassificationRecord + Apply APIs

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 05
- **Blocks**: Task 10, Task 11

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file and all listed inputs before starting implementation.

## Objective
Implement the classification persistence layer: create `classification_records`, add the `ClassificationRecord` schema, and build the apply/manual-override APIs that upsert per-transaction classification state while preserving per-field manual protections and auditability.

## Inputs Required

- [ ] `llms/tasks/019_rules_engine/plan.md` - Full spec (Issue #21, US-13 through US-16, classification schema design)
- [ ] `llms/tasks/019_rules_engine/05_classification_engine.md` - Pure engine contract reused for apply flows
- [ ] `llms/constitution.md` - Context API, docs, and test requirements
- [ ] `llms/project_context.md` - Audit entry points and product invariants
- [ ] `llms/coding_styles/elixir.md` - Elixir style guide
- [ ] `lib/aurum_finance/classification.ex` - Context to extend
- [ ] `lib/aurum_finance/audit.ex` - Audit helpers
- [ ] `lib/aurum_finance/audit/multi.ex` - Multi-event append pattern if needed
- [ ] `lib/aurum_finance/ledger/transaction.ex` - FK target and query inputs
- [ ] `lib/aurum_finance/ledger/account.ex` - Category account validation target

## Expected Outputs

- [ ] Migration file: `priv/repo/migrations/YYYYMMDDHHMMSS_create_classification_records.exs`
- [ ] Schema: `lib/aurum_finance/classification/classification_record.ex`
- [ ] Updated context: `lib/aurum_finance/classification.ex` with apply/manual APIs
- [ ] Any supporting helper modules for provenance or field-level override handling

## Acceptance Criteria

- [ ] Migration creates `classification_records` exactly per spec, including unique `transaction_id`
- [ ] Schema models all four classification fields with per-field provenance JSONB and `*_manually_overridden` flags
- [ ] `get_classification_record/1` returns the record or `nil`
- [ ] `classify_transaction/2` evaluates rules for a single transaction and upserts the classification record
- [ ] `classify_transactions/1` evaluates and applies rules for an entity-scoped date range, returning summary counts
- [ ] Apply logic uses Task 05 engine semantics rather than duplicating rule evaluation logic ad hoc
- [ ] Apply flows include global groups, matching entity-scoped groups, and matching account-scoped groups for the transaction being classified
- [ ] Apply flows respect deterministic scope precedence `account > entity > global`, then `priority ASC`, then `name ASC`
- [ ] Per-field manual override protection is enforced: locked fields are skipped, unlocked fields remain automatable
- [ ] `set_manual_field/4` updates exactly one field, sets `{field}_manually_overridden` to `true`, and stores provenance with source `user`
- [ ] `clear_manual_override/3` clears the lock for exactly one field without clearing the current value
- [ ] Category manual/rule values validate as same-entity category accounts (`management_group: :category`)
- [ ] Tags constraints are enforced: max 20 tags, max 50 chars per tag
- [ ] Notes max length is enforced per spec
- [ ] Apply/manual operations emit audit events using existing audit infrastructure
- [ ] Historical provenance remains resilient if referenced rules/groups are later deleted
- [ ] All public functions have `@doc`

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/classification.ex                  # Context extension
lib/aurum_finance/classification/classification_record.ex
lib/aurum_finance/audit.ex                           # Audit helpers
lib/aurum_finance/audit/multi.ex                     # Multi-event append support
priv/repo/migrations/                                # Migration location
```

### Patterns to Follow
- Use `Repo.insert`/`Repo.update` through audit helpers where practical
- Keep per-field update logic centralized instead of branching throughout the context
- Prefer explicit field whitelists over dynamic atom creation from user input
- Reuse engine output/provenance structures where possible
- Reuse the same scope-aware group loading path as preview where possible

### Constraints
- Do NOT implement LiveView UI here
- Do NOT expose whole-record manual lock semantics; overrides are per field only
- Avoid `String.to_atom/1` on user input for field selection
- Bulk apply should tolerate per-transaction failures and report partial results

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Create the migration and schema first
3. Add single-transaction apply, bulk apply, and manual override APIs to the context
4. Centralize per-field override/provenance handling in small helpers
5. Integrate audit logging without introducing new audit schema tables
6. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Verify schema fields and indexes against the spec
2. Verify per-field manual override semantics carefully
3. Review category account validation and entity isolation
4. Review bulk apply result shape for UI consumption
5. If approved: mark `[x]` on "Approved" and update `execution_plan.md` status

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- [To be filled]

### Outputs Created
- [To be filled]

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|

### Blockers Encountered
- [To be filled]

### Questions for Human
1. [To be filled]

### Ready for Next Task
- [ ] All outputs complete
- [ ] Summary documented
- [ ] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
[YYYY-MM-DD]

### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
```
