# Task 13: Test Implementation and Scope Guardrails

## Status
- **Status**: PLANNED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Tasks 06, 08, 09, 10, 11, 12
- **Blocks**: None

## Assigned Agent
`qa-elixir-test-author` - QA-driven Elixir test writer. Converts approved scenarios into ExUnit, Oban, and LiveView tests with deterministic fixtures and actionable failures.

## Agent Invocation
Activate `qa-elixir-test-author` with:

> Act as `qa-elixir-test-author` following `llms/constitution.md`.
>
> Execute Task 13 from `llms/tasks/017_import_review_queue_materialization/13_test_implementation_and_scope_guardrails.md`.
>
> Read the full milestone plan, Tasks 06-12 outputs, and then implement the final automated test coverage for review/materialization along with any last scope-guardrail documentation updates inside `llms/`.

## Objective
Write the final deterministic test coverage that proves the review queue and ledger materialization workflow is safe, retry-resistant, native-currency only, and traceable end-to-end.

## Inputs Required

- [ ] `llms/tasks/017_import_review_queue_materialization/plan.md`
- [ ] Tasks 06-12 outputs
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] scenario matrix from Task 12
- [ ] existing import/ledger test suites

## Expected Outputs

- [ ] Backend tests for review persistence and materialization
- [ ] Oban tests for async processing and retry/idempotency
- [ ] LiveView tests for review queue and results UI
- [ ] Coverage for native-currency mismatch handling and traceability
- [ ] Any final `llms/` notes needed to preserve issue boundaries

## Acceptance Criteria

- [ ] Tests cover review decisions, duplicate override, bulk approval, and rejection flows
- [ ] Tests cover materialization progress and final outcomes
- [ ] Tests prove rows with conflicting `imported_row.currency` produce failed row outcomes without conversion
- [ ] Tests prove the same imported row cannot be committed twice
- [ ] Tests prove row-to-transaction traceability exists after commit
- [ ] Tests prove PubSub-driven refresh paths work from durable state
- [ ] Any final `llms/` notes keep issue #15, #17, and #43 boundaries explicit

## Technical Notes

### Relevant Code Locations
```text
test/aurum_finance/
test/aurum_finance/ingestion/
test/aurum_finance_web/live/
llms/tasks/017_import_review_queue_materialization/
```

### Patterns to Follow
- Use deterministic DB-sandbox-safe tests
- Use Oban testing helpers for async verification
- Use `Phoenix.LiveViewTest` element assertions rather than raw HTML snapshots

### Constraints
- No debug prints or log noise
- Do not broaden scope into institution-profile work or reconciliation

## Execution Instructions

### For the Agent
1. Read all inputs listed above.
2. Implement the approved test matrix across backend, async, and LiveView layers.
3. Add any final `llms/` guardrail note needed to preserve milestone boundaries.
4. Document all assumptions in "Execution Summary".
5. List any blockers or questions.

### For the Human Reviewer
After agent completes:
1. Review outputs against acceptance criteria.
2. Verify the tests cover native-currency, retry, and traceability safety.
3. Confirm no hidden scope expansion was introduced.
4. If approved: mark `[x]` on "Approved" and mark the milestone implementation-ready.
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
