# Task 10: Backend Candidate Matching API

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 03, Task 07
- **Blocks**: Task 11, Task 12, Task 13

## Assigned Agent
`dev-backend-elixir-engineer` - Senior Elixir/Phoenix backend engineer for query design, domain services, and performance-aware APIs

## Agent Invocation
```text
Act as dev-backend-elixir-engineer following llms/constitution.md.

Execute Task 10 from llms/tasks/018_reconciliation_status/10_match_candidates_backend.md

Read these files before starting:
- llms/constitution.md
- llms/coding_styles/elixir.md
- llms/tasks/018_reconciliation_status/plan.md
- docs/adr/0013-reconciliation-workflow-model.md
- lib/aurum_finance/reconciliation.ex
- lib/aurum_finance/ingestion.ex
- lib/aurum_finance/ingestion/imported_row.ex
- lib/aurum_finance/ledger/posting.ex
- lib/aurum_finance/ledger/transaction.ex
```

## Objective
Add a backend API that, given a posting in a reconciliation session, returns ranked imported-row candidates from the same account with an explainable match score. This is read-only assistance for operators and a foundation for future auto-suggest and auto-clear workflows.

## Inputs Required

- [ ] `docs/adr/0013-reconciliation-workflow-model.md` - matching model and scoring rationale
- [ ] `lib/aurum_finance/reconciliation.ex` - current reconciliation context
- [ ] `lib/aurum_finance/ingestion.ex` - imported-row query patterns
- [ ] `lib/aurum_finance/ingestion/imported_row.ex` - available evidence fields
- [ ] `lib/aurum_finance/ledger/posting.ex` and `lib/aurum_finance/ledger/transaction.ex` - posting facts and transaction metadata

## Expected Outputs

- [ ] `lib/aurum_finance/reconciliation.ex` - public candidate API
- [ ] One or more new backend modules under `lib/aurum_finance/reconciliation/` for scoring / candidate shaping, if needed

## Acceptance Criteria

- [ ] Public API added to `AurumFinance.Reconciliation` for listing candidates for one posting, scoped by `entity_id`
- [ ] API is read-only: it does not create matches, clear postings, or mutate reconciliation state
- [ ] Candidate search is scoped to the posting's account and entity
- [ ] Candidates come from imported rows, not arbitrary UI-only structs
- [ ] Imported rows are filtered to a small date window around the posting date, default `+/- 2` days
- [ ] Imported rows are filtered to likely amount matches using both exact match and a tolerance rule
- [ ] Tolerance is modeled for future reuse, not hardcoded only as `+/- 20%`
- [ ] Returned candidates include an overall numeric `score`
- [ ] Returned candidates include a machine-readable `signals` / `score_breakdown`
- [ ] Returned candidates include human-usable `reasons` or badges derived from the score
- [ ] Ranking prioritizes amount exactness and date closeness over description similarity
- [ ] Description similarity is included when data is available, but does not dominate the score
- [ ] API supports a sensible default limit (for example top 5 or top 10 candidates)
- [ ] Public function has `@doc` and `@spec`
- [ ] Query and scoring design are written so the same result shape can later support auto-suggest / auto-reconciliation

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/reconciliation.ex
lib/aurum_finance/reconciliation/
lib/aurum_finance/ingestion.ex
lib/aurum_finance/ingestion/imported_row.ex
```

### Design Direction

Use a stable, explainable candidate shape rather than returning raw imported rows only.

Suggested shape:

```elixir
%{
  posting_id: posting.id,
  imported_row_id: imported_row.id,
  score: 0.87,
  confidence: :high,
  reasons: [:exact_amount, :same_day, :description_similarity],
  signals: %{
    amount_exact: true,
    amount_absolute_distance: Decimal.new("0.00"),
    amount_relative_distance: 0.0,
    date_distance_days: 0,
    description_similarity: 0.62
  },
  imported_row: imported_row
}
```

### Scoring Guidance

- Amount score should carry the highest weight.
- Date proximity should carry the second-highest weight.
- Description similarity should be supportive, not dominant.
- Use absolute amount comparison for cross-sign normalization if imported evidence and ledger postings differ in sign conventions.
- Keep thresholds configurable through small private helpers or module attributes.

### Suggested Public API

- `list_match_candidates_for_posting(posting_id, opts)`
- optional companion helper: `list_match_candidates_for_posting_query/2` only if composition is genuinely useful

### Constraints

- Do not introduce auto-clear or auto-reconcile behavior in this task
- Do not add persistence for accepted/rejected matches in this task unless strictly necessary and explicitly documented
- Web layer must remain a consumer of the context API, not `Repo`
- Prefer small dedicated scorer helpers over embedding all logic in the LiveView

## Execution Instructions

### For the Agent
1. Read the required inputs
2. Read `llms/coding_styles/elixir.md`
3. Design the public API and result shape first
4. Implement query + scoring in backend modules
5. Keep the output explainable and future-proof for auto-rec
6. Run `mix compile --warnings-as-errors`
7. Document assumptions in the Execution Summary

### For the Human Reviewer
1. Verify the API is read-only and properly entity-scoped
2. Verify candidate ranking is explainable
3. Verify the result shape is reusable for future auto-rec
4. Check that amount/date similarity dominate the score
5. Check docs/specs on public functions

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
### Outputs Created
### Assumptions Made
| Assumption | Rationale |
|------------|-----------|

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|

### Blockers Encountered
### Questions for Human
### Ready for Next Task
- [ ] All outputs complete
- [ ] Summary documented
- [ ] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
