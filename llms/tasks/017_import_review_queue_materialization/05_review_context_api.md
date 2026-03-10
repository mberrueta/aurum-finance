# Task 05: Review Context API

## Status
- **Status**: PLANNED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Tasks 01, 02, 03, 04
- **Blocks**: Tasks 06, 07, 08, 09, 10, 11, 12, 13

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, business logic, and safe orchestration entrypoints.

## Agent Invocation
Activate `dev-backend-elixir-engineer` with:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 05 from `llms/tasks/017_import_review_queue_materialization/05_review_context_api.md`.
>
> Read the full milestone plan and Tasks 01-04 outputs first. Implement the review context APIs and materialization-request entrypoint, but do not build the worker, PubSub wiring, or LiveView UI in this step.

## Objective
Implement the backend context APIs that persist review decisions, expose review-oriented row queries, and create/enqueue durable materialization requests safely.

## Inputs Required

- [ ] `llms/tasks/017_import_review_queue_materialization/plan.md`
- [ ] Tasks 01-04 outputs
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `lib/aurum_finance/ingestion.ex`
- [ ] `lib/aurum_finance/ingestion/imported_file.ex`
- [ ] `lib/aurum_finance/ingestion/imported_row.ex`
- [ ] `lib/aurum_finance/ledger.ex`

## Expected Outputs

- [ ] Review decision APIs in the ingestion/review context
- [ ] Review-oriented query/list functions for imported rows
- [ ] Materialization-request API that persists a run and enqueues work
- [ ] I18n-backed validation/error handling for review and currency-mismatch boundaries

## Acceptance Criteria

- [ ] Public APIs are account-scoped and follow existing query/context patterns
- [ ] Review decisions can be persisted without mutating imported-row evidence facts
- [ ] Bulk approval of `ready` rows is supported at the API layer
- [ ] Duplicate rows require explicit override API, not implicit approval
- [ ] Materialization requests create durable run state before async execution
- [ ] The API layer enforces that `imported_row.currency` never overrides `account.currency_code`

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/ingestion.ex                  # Existing import context and query patterns
lib/aurum_finance/ingestion/imported_row.ex     # Imported-row evidence model
lib/aurum_finance/ledger.ex                     # Ledger transaction creation entrypoints
test/aurum_finance/                             # Existing backend test patterns
```

### Patterns to Follow
- Use `list_*`, `get_*!`, and composable `*_query/1` APIs
- Keep ownership boundaries explicit via `account_id` and ledger-derived entity scope
- Return `{:ok, data}` / `{:error, reason}` for important backend operations

### Constraints
- Do not build Oban worker execution in this task
- Do not build LiveView UI in this task
- Do not add FX conversion logic

## Execution Instructions

### For the Agent
1. Read all inputs listed above.
2. Implement review persistence/query APIs and the request-materialization entrypoint.
3. Keep currency handling native-account only.
4. Document all assumptions in "Execution Summary".
5. List any blockers or questions.

### For the Human Reviewer
After agent completes:
1. Review outputs against acceptance criteria.
2. Verify APIs are scoped correctly and do not mutate imported-row evidence semantics.
3. Check that native-currency guards are enforced cleanly.
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
