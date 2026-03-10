# Task 01: Review and Materialization Domain Contract

## Status
- **Status**: PLANNED
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: Tasks 02, 03, 04, 05, 07, 09, 10, 11, 12, 13

## Assigned Agent
`tl-architect` - Technical lead architect. Transforms validated specs into executable technical contracts, task boundaries, and implementation sequencing.

## Agent Invocation
Activate `tl-architect` with:

> Act as `tl-architect` following `llms/constitution.md`.
>
> Execute Task 01 from `llms/tasks/017_import_review_queue_materialization/01_review_and_materialization_domain_contract.md`.
>
> Read the full milestone plan first, then lock down the domain contract for review state, materialization state, row eligibility, native-currency rules, and idempotency boundaries. Do not implement code in this step. Do not modify `plan.md`.

## Objective
Define the authoritative domain contract for the review queue and ledger materialization workflow before schema or implementation work begins. This task must make the boundaries between immutable imported-row evidence, mutable review decisions, materialization runs, and native-currency ledger writes explicit and unambiguous.

## Inputs Required

- [ ] `llms/tasks/017_import_review_queue_materialization/plan.md`
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/tasks/015_import_source_file_model/plan.md`
- [ ] `llms/tasks/012_ledger_primitives/plan.md`
- [ ] `lib/aurum_finance/ingestion/imported_row.ex`
- [ ] `lib/aurum_finance/ledger/transaction.ex`
- [ ] `lib/aurum_finance/ledger/posting.ex`

## Expected Outputs

- [ ] Domain contract note covering imported-row evidence vs review state vs materialization state
- [ ] Row eligibility matrix for `ready`, `duplicate`, `invalid`, already committed, and currency-mismatch rows
- [ ] Explicit idempotency/retry policy for row-level and batch-level materialization
- [ ] Explicit native-currency rule set confirming that materialization uses `account.currency_code` only

## Acceptance Criteria

- [ ] Imported-row evidence semantics remain separate from review/materialization workflow semantics
- [ ] The contract explicitly states that the ledger write model is native-currency only
- [ ] The contract explicitly states that `imported_rows.currency` is evidence only and does not drive ledger postings
- [ ] The contract defines how duplicate rows become materializable only after explicit override
- [ ] The contract defines how currency-mismatch rows are skipped or failed without conversion
- [ ] The contract defines whether partial row failures make the run `complete` or `failed`

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/ingestion/             # Existing import evidence model and async orchestration
lib/aurum_finance/ledger/                # Transaction/posting write model constraints
lib/aurum_finance_web/live/              # Existing import details review surface
llms/tasks/015_import_source_file_model/ # Prior ingestion boundary and completed milestone
llms/tasks/012_ledger_primitives/        # Ledger currency and balancing invariants
```

### Patterns to Follow
- Preserve the closed boundary from issue #15 instead of redefining it
- Keep state-machine responsibilities separate rather than overloading one enum
- Follow the ledger invariant that postings derive effective currency from accounts, not row payloads

### Constraints
- No implementation code in this task
- No scope expansion into reconciliation, rules, or import-profile work
- Human approval is required before schema design starts

## Execution Instructions

### For the Agent
1. Read all inputs listed above.
2. Produce a concise technical contract artifact within this task file's execution summary.
3. Resolve ambiguous wording from the plan into explicit state and eligibility rules.
4. Document all assumptions in "Execution Summary".
5. List any blockers or questions.

### For the Human Reviewer
After agent completes:
1. Review outputs against acceptance criteria.
2. Verify the state and currency boundaries are acceptable.
3. Check that no hidden scope expansion slipped in.
4. If approved: mark `[x]` on "Approved" and update plan.md status.
5. If rejected: add rejection reason and specific feedback.

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- 

### Outputs Created
- 

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
|  |  |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
|  |  |  |

### Blockers Encountered
- 

### Questions for Human
1. 

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
- [ ] ✅ APPROVED - Proceed to next task
- [ ] ❌ REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
# Human-only commands, if any
```
