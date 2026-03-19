# Task 05: Reporting Context API

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 04
- **Blocks**: Task 06

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file, Task 04 outputs, and the reporting plan before starting implementation.

## Objective
Create `AurumFinance.Reporting` as the public API surface for snapshot listing, querying, synchronous refresh execution, and manual rebuild entrypoints.

## Inputs Required

- [ ] `llms/tasks/020_daily_balance_snapshots/plan.md`
- [ ] `llms/tasks/020_daily_balance_snapshots/04_projection_engine.md`
- [ ] Completed outputs from Task 04
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `llms/coding_styles/elixir.md`
- [ ] Existing context patterns such as `lib/aurum_finance/ledger.ex` and `lib/aurum_finance/ingestion.ex`

## Expected Outputs

- [ ] New context module `lib/aurum_finance/reporting.ex`
- [ ] Public list/query/rebuild API
- [ ] Internal helper structure matching project conventions

## Acceptance Criteria

- [ ] Exposes `list_daily_balance_snapshots/1`
- [ ] Exposes `list_daily_balance_snapshots_query/1`
- [ ] Exposes synchronous refresh/rebuild entrypoints for worker/manual use
- [ ] Query APIs use `opts` and `filter_query/2` style where appropriate
- [ ] Rebuild entrypoints are account-scoped and explicit
- [ ] Public rebuild/refresh APIs define `from_date` explicitly:
- [ ] `nil` means bootstrap from the account’s first effective ledger date
- [ ] dates earlier than `first_effective_date` clamp to `first_effective_date`
- [ ] dates later than `last_effective_date` return a no-op result and do not delete existing snapshots
- [ ] older requested dates expand rebuild scope backward and force forward-range replacement from that earlier effective start date
- [ ] Public functions have `@doc`
- [ ] No report-rendering semantics are embedded in this context

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/reporting.ex
lib/aurum_finance/ledger.ex
lib/aurum_finance/ingestion.ex
```

### Constraints
- Keep context focused on projection access and rebuild orchestration
- Do not add job uniqueness implementation details beyond what the plan requires
- Do not leave `from_date` behavior implicit in public API contracts

## Execution Instructions

### For the Agent
1. Read Task 04 outputs first.
2. Model the context API after existing `list_*` and scoped helper patterns.
3. Keep rebuild entrypoints explicit and small.
4. Make the `from_date` contract explicit in `@doc` and return semantics.
5. Leave queue merge and runtime safety behavior to Task 06, but keep the API contract compatible with it.
6. Document any public API tradeoffs in the execution summary.

### For the Human Reviewer
1. Review context naming and public API surface.
2. Confirm no report-layer semantics leaked into the base context.
3. Approve before Task 06 begins.

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
| [To be filled] | [To be filled] |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| [To be filled] | [To be filled] | [To be filled] |

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
[Human notes]

### Git Operations Performed
```bash
# [Commands human executed]
```
