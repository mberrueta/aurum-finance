# Task 05: Documentation and ADR Sync

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 04
- **Blocks**: None

## Assigned Agent
`docs-feature-documentation-author` - Feature documentation writer. Creates and updates user-facing documentation aligned with actual application behavior.

## Agent Invocation
Activate the `docs-feature-documentation-author` agent with the following prompt:

> Act as `docs-feature-documentation-author` following `llms/constitution.md`.
>
> Execute Task 05 from `llms/tasks/012_ledger_primitives/05_documentation_sync.md`.
>
> Read all inputs listed in the task. Update project documentation to reflect the Transaction and Posting models as implemented. Focus on domain-model.md, ADR-0008, and project_context.md. Ensure documentation matches actual implementation, not aspirational design. Key decisions to document: no currency_code on postings (derived from account join), no entity_id on postings (derived from transaction), no memo on transactions (future overlay), no status enum on transactions (voided_at nullable timestamp instead), no updated_at on either table, zero-sum invariant per currency group, void-and-reverse workflow using voided_at, posting-backed balance derivation. Do NOT modify `plan.md`.

## Objective
Update project documentation to accurately reflect the Transaction and Posting model implementation from this issue. This includes the domain model document, relevant ADRs, project context, and milestone tracking. Documentation must match the actual code delivered in Tasks 01-02, not aspirational or future-state designs.

## Inputs Required

- [ ] `llms/tasks/012_ledger_primitives/plan.md` - Master plan with canonical domain decisions, terminology alignment, and field definitions
- [ ] `llms/tasks/012_ledger_primitives/01_domain_data_model_foundation.md` - Task 01 deliverables and execution summary
- [ ] `llms/tasks/012_ledger_primitives/04_handoff_notes.md` - Handoff notes from Task 04 (downstream unblock documentation)
- [ ] `llms/constitution.md` - Documentation rules
- [ ] `llms/project_context.md` - Project context (to be updated if new conventions established)
- [ ] `docs/domain-model.md` - Current domain model documentation (to be updated)
- [ ] `docs/adr/0008-ledger-schema-design.md` - Ledger schema ADR (to be updated with implementation notes)
- [ ] `docs/adr/0002-ledger-as-internal-double-entry-model.md` - Double-entry model ADR (verify alignment)
- [ ] `docs/adr/0004-immutable-facts-mutable-classification.md` - Immutable facts ADR (verify alignment)
- [ ] `lib/aurum_finance/ledger.ex` - Actual context implementation (source of truth)
- [ ] `lib/aurum_finance/ledger/transaction.ex` - Actual Transaction schema (source of truth)
- [ ] `lib/aurum_finance/ledger/posting.ex` - Actual Posting schema (source of truth)

## Expected Outputs

- [ ] **Updated**: `docs/domain-model.md`
  - Add Transaction entity with all canonical fields (id, entity_id, date, description, source_type, correlation_id, voided_at, inserted_at)
    - **No `memo` field. No `status` field. No `updated_at`.**
    - Document `voided_at`: nullable timestamp; NULL = active; non-null = voided with timestamp of when
  - Add Posting entity with all canonical fields (id, transaction_id, account_id, amount, inserted_at)
    - **No `currency_code`. No `entity_id`. No `updated_at`.**
  - Document relationships: Transaction belongs_to Entity, Transaction has_many Postings, Posting belongs_to Transaction, Posting belongs_to Account
  - Document the sign convention: positive = debit, negative = credit
  - Document that Posting has NO currency_code (derived from account.currency_code via join)
  - Document that Posting has NO entity_id (derived from transaction.entity_id)
  - Document that Transaction has NO memo (annotations are a future overlay model)
  - Document the zero-sum invariant (per currency group via account join)
  - Document the void-and-reverse workflow: sets `voided_at` on original, creates reversal with negated postings, links via `correlation_id`
  - Document balance derivation (posting-backed, single currency per account)
  - Document immutability: postings fully immutable, transaction facts immutable, no delete; only allowed mutation is setting `voided_at` once

- [ ] **Updated**: `docs/adr/0008-ledger-schema-design.md`
  - Add "Implementation Notes" or "Deviations" section (following pattern from Issue #11 updates)
  - Document that `posting.currency_code` was intentionally omitted — currency is structural via account join
  - Document that `posting.entity_id` was intentionally omitted — entity scope via transaction
  - Document that `transaction.memo` was intentionally omitted — annotations belong in future overlay context
  - Document that `transaction.status` was intentionally omitted — `voided_at` (nullable timestamp) is used instead, following the same pattern as `account.archived_at`
  - Document that neither `transactions` nor `postings` have `updated_at` — both are immutable ledger facts
  - Document zero-sum trigger implementation: `DEFERRABLE INITIALLY DEFERRED` constraint trigger joining accounts
  - Document `source_type` values: `manual`, `import`, `system`
  - Document void workflow: sets `voided_at` on original via `void_changeset/1`, creates reversing transaction
  - Note deferred items: BalanceSnapshot caching, transaction annotation overlay, write UI

- [ ] **Reviewed**: `docs/adr/0002-ledger-as-internal-double-entry-model.md`
  - Verify consistency between ADR and the implemented Transaction/Posting model
  - Note any deviations if found

- [ ] **Reviewed**: `docs/adr/0004-immutable-facts-mutable-classification.md`
  - Verify that Transaction/Posting immutability aligns with ADR-0004's immutable facts principle
  - Note any deviations if found

- [ ] **Updated** (if needed): `llms/project_context.md`
  - Add ledger transaction conventions if new patterns are established
  - Document sign convention (positive = debit, negative = credit)
  - Document that postings have no currency_code or entity_id
  - Document that balance is derived on read from postings

## Acceptance Criteria

- [ ] `docs/domain-model.md` includes Transaction entity with:
  - All canonical fields from plan.md (id, entity_id, date, description, source_type, correlation_id, voided_at, inserted_at)
  - Explicit note: NO `memo` field (deferred to overlay model)
  - Explicit note: NO `status` field (`voided_at` is used instead)
  - Explicit note: NO `updated_at` field
  - Relationship to Entity (via entity_id)
  - Relationship to Postings (has_many)
  - Void lifecycle: `voided_at` NULL = active; non-null = voided with timestamp
  - Source type values (manual, import, system)
  - Void-and-reverse workflow description
- [ ] `docs/domain-model.md` includes Posting entity with:
  - All canonical fields (id, transaction_id, account_id, amount, inserted_at)
  - Explicit note: NO currency_code field (derived from account.currency_code via join)
  - Explicit note: NO entity_id field (derived from parent transaction)
  - Explicit note: NO updated_at field
  - Sign convention documented
  - Full immutability documented
- [ ] `docs/domain-model.md` documents balance derivation:
  - Posting-backed, not stored
  - Single currency per account
  - as_of_date support
  - No FX conversion
- [ ] `docs/adr/0008-ledger-schema-design.md` has implementation notes for Transaction/Posting
- [ ] ADR-0002 reviewed and deviations noted (if any)
- [ ] ADR-0004 reviewed and alignment confirmed (both tables fully immutable — no updated_at)
- [ ] All documentation changes reference actual field names and types from the implementation
- [ ] No aspirational features documented as if they exist (e.g., BalanceSnapshot, memo, status enum, FX conversion)
- [ ] Out-of-scope items noted as deferred (consistent with plan.md "Out of Scope" section)

## Technical Notes

### Relevant Code Locations
```
docs/domain-model.md                                   # Primary update target
docs/adr/0008-ledger-schema-design.md                  # ADR update target
docs/adr/0002-ledger-as-internal-double-entry-model.md # Review for consistency
docs/adr/0004-immutable-facts-mutable-classification.md # Review for consistency
llms/project_context.md                                # Update if conventions established
lib/aurum_finance/ledger.ex                            # Source of truth for API
lib/aurum_finance/ledger/transaction.ex                # Source of truth for Transaction schema
lib/aurum_finance/ledger/posting.ex                    # Source of truth for Posting schema
llms/tasks/012_ledger_primitives/04_handoff_notes.md   # Handoff notes for reference
```

### Patterns to Follow

**Documentation update pattern** (from `llms/tasks/011_account_model/05_documentation_sync.md`):
- Match documentation to actual implementation, not aspirational design
- Use field names and types exactly as they appear in the schema files
- Note deviations from ADRs with rationale
- Mark deferred items explicitly as deferred with issue/milestone references
- Do not document features that do not exist yet

**ADR deviation documentation pattern**:
- Add a section titled "Implementation Notes" or "Deviations" at the end of the ADR
- For each deviation: what the ADR specified, what was implemented, and why
- Keep the original ADR text unchanged -- deviations are additive

**Terminology alignment** (from plan.md):
- "split" = Transaction with >2 postings (no separate entity)
- "debit"/"credit" = positive/negative amount (sign convention)
- "balance" = derived from postings (no denormalized field)
- "direction" = amount sign (not a separate field)
- "state" = `voided_at` (NULL = active, non-null = voided) — no `status` enum

### Constraints
- Documentation must match the actual code, not the plan's aspirational design
- Read the actual schema files to verify field names and types before writing documentation
- Do not add documentation for features not implemented in this issue
- Keep existing documentation structure and formatting conventions
- ADR modifications should be additive (implementation notes), not rewrites

## Execution Instructions

### For the Agent
1. Read all inputs listed above -- especially the actual schema files (Transaction, Posting) as the source of truth
2. Read existing `docs/domain-model.md` to understand current structure and where to add Transaction/Posting
3. Update `docs/domain-model.md` with Transaction and Posting entities
4. Read `docs/adr/0008-ledger-schema-design.md` and add implementation notes
5. Review `docs/adr/0002-ledger-as-internal-double-entry-model.md` for consistency
6. Review `docs/adr/0004-immutable-facts-mutable-classification.md` for alignment
7. Update `llms/project_context.md` if new conventions are established
8. Cross-check all documentation against actual schema files (not plan.md) for accuracy
9. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Verify domain-model.md accurately reflects the implemented Transaction and Posting schemas
2. Verify ADR-0008 implementation notes are accurate and complete
3. Verify no aspirational features are documented as existing
4. Verify terminology is consistent with plan.md's terminology alignment table
5. Verify project_context.md updates are appropriate
6. If approved: mark `[x]` on "Approved" and update plan.md status
7. If rejected: add rejection reason and specific feedback

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- [What was actually done]

### Outputs Created
- [List of files/artifacts created]

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| [Assumption 1] | [Why this was assumed] |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| [Decision 1] | [Options] | [Why chosen] |

### Blockers Encountered
- [Blocker 1] - Resolution: [How resolved or "Needs human input"]

### Questions for Human
1. [Question needing human input]

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
[Human's notes, corrections, or rejection reasons]

### Git Operations Performed
```bash
# [Commands human executed]
```
