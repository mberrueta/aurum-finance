# Task 05: Documentation and ADR Sync

## Status
- **Status**: COMPLETED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 04
- **Blocks**: None

## Assigned Agent
`docs-feature-documentation-author` - Feature documentation writer. Creates and updates user-facing documentation aligned with actual application behavior.

## Agent Invocation
Activate the `docs-feature-documentation-author` agent with the following prompt:

> Act as `docs-feature-documentation-author` following `llms/constitution.md`.
>
> Execute Task 05 from `llms/tasks/011_account_model/05_documentation_sync.md`.
>
> Read all inputs listed in the task. Update project documentation to reflect the Account model as implemented. Focus on domain-model.md, ADR-0008, ADR-0015, and project_context.md. Ensure documentation matches actual implementation, not aspirational design.

## Objective
Update project documentation to accurately reflect the Account model implementation. This includes the domain model document, relevant ADRs (documenting deviations), project context, and milestone tracking. Documentation must match the actual code delivered in Tasks 01-03, not aspirational or future-state designs.

## Inputs Required

- [ ] `llms/tasks/011_account_model/plan.md` - Master plan with terminology alignment table and canonical decisions
- [ ] `llms/tasks/011_account_model/04_handoff_notes.md` - Handoff notes from Task 04 (if created)
- [ ] `docs/domain-model.md` - Current domain model documentation (to be updated)
- [ ] `docs/adr/0008-ledger-schema-design.md` - Ledger schema ADR (needs `archived_at` deviation note)
- [ ] `docs/adr/0015-account-model-and-instrument-types.md` - Account model ADR (verify consistency with implementation)
- [ ] `llms/project_context.md` - Project context (update if conventions established)
- [ ] `llms/tasks/000_project_plan.md` - Milestone tracking (if it exists -- update M1 account status)
- [ ] `lib/aurum_finance/ledger.ex` - Actual context implementation (source of truth)
- [ ] `lib/aurum_finance/ledger/account.ex` - Actual schema implementation (source of truth)
- [ ] `lib/aurum_finance_web/live/accounts_live.ex` - Actual LiveView implementation (source of truth)

## Expected Outputs

- [ ] **Updated**: `docs/domain-model.md`
  - Add Account entity with all canonical fields
  - Document the dual classification model (account_type + operational_subtype)
  - Document entity scoping relationship (Account belongs_to Entity)
  - Document archive lifecycle (archived_at pattern)
  - Document balance derivation commitment (no balance column, derived from postings)
- [ ] **Updated**: `docs/adr/0008-ledger-schema-design.md`
  - Add a "Deviations" or "Implementation Notes" section
  - Document that `is_active` (boolean) was replaced by `archived_at` (utc_datetime_usec)
  - Document rationale: consistency with entity model lifecycle, temporal audit trace
  - Document that `account_number_last4` was replaced by `institution_account_ref`
- [ ] **Reviewed**: `docs/adr/0015-account-model-and-instrument-types.md`
  - Verify consistency between ADR and implementation
  - Note any deviations if found
- [ ] **Updated** (if needed): `llms/project_context.md`
  - Add any new project conventions established by this issue (e.g., Ledger context pattern, dual classification approach)
- [ ] **Updated** (if exists): `llms/tasks/000_project_plan.md`
  - Mark M1 account model work as complete or in-progress

## Acceptance Criteria

- [ ] `docs/domain-model.md` includes Account entity with:
  - All canonical fields from plan.md
  - Relationship to Entity (via entity_id)
  - Dual ledger classification explanation (`account_type` + `operational_subtype`)
  - Explicit management grouping explanation (`management_group`)
  - Archive lifecycle description
  - Balance derivation note (placeholder until postings exist)
- [ ] `docs/adr/0008-ledger-schema-design.md` documents the `archived_at` deviation from `is_active`
- [ ] `docs/adr/0008-ledger-schema-design.md` documents the `institution_account_ref` deviation from `account_number_last4`
- [ ] `docs/adr/0015-account-model-and-instrument-types.md` is verified consistent with implementation
- [ ] All documentation changes reference actual field names and types from the implementation
- [ ] No aspirational features documented as if they exist (e.g., parent/child tree, trading accounts)
- [ ] Out-of-scope items are noted as deferred (consistent with plan.md "Explicitly out of scope" section)

## Technical Notes

### Relevant Code Locations
```
docs/domain-model.md                                   # Primary update target
docs/adr/0008-ledger-schema-design.md                  # ADR deviation documentation
docs/adr/0015-account-model-and-instrument-types.md    # Verify consistency
llms/project_context.md                                # Update if needed
llms/tasks/000_project_plan.md                         # Milestone tracking (if exists)
lib/aurum_finance/ledger.ex                            # Source of truth: context API
lib/aurum_finance/ledger/account.ex                    # Source of truth: schema fields
```

### Documentation Principles

**Source of truth is Tasks 01–03 (implementation), not Task 04:**
- The primary source of truth for documentation is the code delivered in Tasks 01–03
  (`lib/aurum_finance/ledger.ex`, `lib/aurum_finance/ledger/account.ex`, `lib/aurum_finance_web/live/accounts_live.ex`)
- Task 04 (Security/Architecture Review) is a review-only task: it produces findings and handoff notes but does NOT change behavior or implementation. It unblocks Task 05 in sequencing terms, but does not modify what gets documented.
- If Task 04 findings reveal a deviation or correction to the implementation, that correction must be applied in a follow-up task before it is documented here. Do not document intended or recommended state as if it is implemented.
- Read the actual implementation files to verify field names, types, and behavior
- If the implementation differs from plan.md (due to Task 01-03 decisions), document the implementation, not the plan

**ADR deviation format:**
- ADR deviations should be documented as addenda, not by rewriting the original ADR
- Use a clear "Implementation Deviations" section at the end of the ADR
- Include: what changed, why, when (Issue #11), and any migration impact

**Domain model documentation:**
- Should match the level of detail of existing entities in `docs/domain-model.md`
- Include field table with types, constraints, and notes
- Include relationship diagram notation if the document uses one

### Terminology Alignment (from plan.md)
When updating documentation, use the canonical terms:
| Old / ADR Term | Canonical Term | Reason |
|---|---|---|
| `type` (flat enum) | `account_type` + `operational_subtype` | Two orthogonal dimensions per ADR-0015 |
| `is_active` (boolean) | `archived_at` (timestamp) | Consistency with entity lifecycle |
| `institution` | `institution_name` | ADR-0008 canonical name |
| `account_number_last4` | `institution_account_ref` | Free string, not always last 4 |
| `currency` | `currency_code` | ADR-0008 canonical name |
| heuristic management grouping | `management_group` | Explicit management/presentation classification in implementation |

### Constraints
- Only modify documentation files (under `docs/` and `llms/`)
- Do not modify source code files
- Do not add documentation for features that are out of scope (parent/child tree, trading accounts, balance snapshots)
- Keep ADR modifications as addenda rather than rewriting original content

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Read the actual implementation files (`ledger.ex`, `account.ex`) to verify field names and behavior
3. Update `docs/domain-model.md` with Account entity documentation
4. Add deviation notes to `docs/adr/0008-ledger-schema-design.md`
5. Review `docs/adr/0015-account-model-and-instrument-types.md` for consistency
6. Update `llms/project_context.md` if new conventions were established
7. Check if `llms/tasks/000_project_plan.md` exists and update milestone status
8. Document all changes and assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Review domain model documentation for accuracy against actual implementation
2. Verify ADR deviation notes are clear and well-reasoned
3. Verify no aspirational features are documented as existing
4. Verify terminology alignment uses canonical terms
5. Check that out-of-scope items are properly noted as deferred
6. If approved: mark `[x]` on "Approved" and update plan.md status
7. If rejected: add rejection reason and specific feedback

---

## Execution Summary
Updated documentation to match the implemented Account model rather than the broader conceptual target architecture. The main correction was in `docs/domain-model.md`, which still described account tree, placeholder accounts, active boolean lifecycle, and balance snapshots as if they were already implemented.

### Work Performed
- Updated `docs/domain-model.md` to reflect the implemented Account slice:
  - canonical fields
  - `management_group`
  - `archived_at`
  - entity-scoped retrieval/listing
  - placeholder balance behavior
  - deferred transaction/posting/tree features
- Added an implementation addendum to `docs/adr/0008-ledger-schema-design.md`
  documenting:
  - `archived_at` over `is_active`
  - `institution_account_ref` naming
  - explicit `management_group`
  - deferred ADR items not yet implemented
- Updated `llms/project_context.md` with conventions established by this issue
- Reviewed `docs/adr/0015-account-model-and-instrument-types.md` and left it unchanged because it already matches the implemented model
- Reviewed `llms/tasks/000_project_plan.md` and left it unchanged because it is an LLM workflow conventions file, not milestone tracking for M1 progress

### Outputs Created
- Updates to `docs/domain-model.md`
- Updates to `docs/adr/0008-ledger-schema-design.md`
- Updates to `llms/project_context.md`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| `docs/domain-model.md` should describe the implemented Ledger slice, not the full aspirational ledger roadmap | Task 05 explicitly requires matching the code, not future-state design |
| `llms/tasks/000_project_plan.md` should not be repurposed as milestone tracking | Its content is issue-execution workflow guidance, not roadmap status |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Add an implementation deviation section to ADR-0008 instead of rewriting earlier conceptual sections | Rewrite the ADR body to fully mirror the current code | The task explicitly asks for addenda/deviation notes rather than destructive ADR rewrites |
| Leave ADR-0015 unchanged | Add redundant clarification churn | It is already consistent with `management_group`, canonical account semantics, and separated management surfaces |

### Blockers Encountered
- `docs/domain-model.md` mixed implemented behavior and deferred architecture in the same Ledger section - Resolution: documented current implementation scope explicitly and marked deferred concepts as deferred

### Questions for Human
1. None

### Ready for Next Task
- [x] All outputs complete
- [x] Summary documented
- [x] Questions listed (if any)

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
