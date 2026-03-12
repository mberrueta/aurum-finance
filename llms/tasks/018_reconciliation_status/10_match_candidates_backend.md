# Task 10: Backend Candidate Matching API

## Status
- **Status**: COMPLETED
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

The internal design should explicitly separate:

- candidate retrieval
- candidate scoring
- candidate shaping / presentation

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
- [ ] Internal design separates candidate retrieval from candidate scoring and output shaping
- [ ] Candidate search is scoped to the posting's account and entity
- [ ] Candidates come from imported rows, not arbitrary UI-only structs
- [ ] Imported rows are filtered to a small date window around the posting date, default `+/- 2` days
- [ ] Imported rows are filtered to likely amount matches using both exact match and a tolerance rule
- [ ] Tolerance is modeled for future reuse, not hardcoded only as `+/- 20%`
- [ ] Returned candidates include an overall numeric `score`
- [ ] Returned candidates expose a stable qualitative band such as `:exact_match`, `:near_match`, `:weak_match`, or `:below_threshold`
- [ ] Returned candidates include a machine-readable `signals` / `score_breakdown`
- [ ] Returned candidates include human-usable `reasons` or badges derived from the score
- [ ] Ranking prioritizes amount exactness and date closeness over description similarity
- [ ] Description similarity cannot rescue an otherwise poor amount/date candidate into a strong match band
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

The backend implementation should be split into small focused modules, for example:

- `CandidateFinder` - loads candidate imported rows within scope and retrieval window
- `CandidateScorer` - computes weighted signals and final score
- `CandidatePresenter` or `CandidateShape` - normalizes the result contract returned by the context

Exact names may vary, but the responsibility split should remain clear.

Suggested shape:

```elixir
%{
  posting_id: posting.id,
  imported_row_id: imported_row.id,
  score: 0.87,
  match_band: :near_match,
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

`score` should be a normalized numeric heuristic in the range `0.0..1.0`.

The `match_band` contract should be stable and explicit even if the underlying scoring weights evolve. Suggested baseline bands:

- `:exact_match`
- `:near_match`
- `:weak_match`
- `:below_threshold`

Prefer neutral terminology such as `match_strength` over authoritative terminology such as `confidence` unless the latter is explicitly documented as derived UI language only.

Prefer `match_band` as the stable backend qualitative contract. Additional UI wording such as `match_strength` should be derived only if needed and should not introduce a second competing classification model.

The scorer may classify rows into all bands, including `:below_threshold`, but the public API should filter out below-threshold rows by default and return only actionable candidate rows unless explicitly configured otherwise. A future-friendly option such as `include_below_threshold?: true` is acceptable for debugging or deeper inspection.

### Scoring Guidance

- Amount score should carry the highest weight.
- Date proximity should carry the second-highest weight.
- Description similarity should be supportive, not dominant.
- Description similarity should act as a tie-breaker or confidence booster, not as a primary rescue signal.
- Use absolute amount comparison for cross-sign normalization if imported evidence and ledger postings differ in sign conventions.
- Keep thresholds configurable through small private helpers or module attributes.
- Map the numeric score and/or signals into a stable qualitative band for UI and tests.
- Keep the public `score` contract normalized to `0.0..1.0`.

Recommended mental rule:

- amount
- date
- description

If amount/date are materially weak, description similarity alone must not produce `:exact_match` or `:near_match`.

### Suggested Public API

- `list_match_candidates_for_posting(posting_id, opts)`
- optional companion helper: `list_match_candidates_for_posting_query/2` only if composition is genuinely useful

The public context function should orchestrate the internal pipeline rather than owning the scoring logic inline.

### Constraints

- Do not introduce auto-clear or auto-reconcile behavior in this task
- Do not add persistence for accepted/rejected matches in this task unless strictly necessary and explicitly documented
- Web layer must remain a consumer of the context API, not `Repo`
- Prefer dedicated modules over embedding all logic in the context or LiveView

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
### Work Performed
- Added `list_match_candidates_for_posting/2` to `AurumFinance.Reconciliation`
- Added `MatchCandidateFinder` to retrieve raw imported-row candidates within account/date/amount scope
- Added `MatchCandidateScorer` to calculate weighted score, `match_band`, `reasons`, and `signals`
- Kept the public contract read-only and filtered `:below_threshold` candidates by default, with opt-in inclusion
- Added context tests for ranking, threshold filtering, and entity/account isolation

### Outputs Created
- `lib/aurum_finance/reconciliation.ex`
- `lib/aurum_finance/reconciliation/match_candidate_finder.ex`
- `lib/aurum_finance/reconciliation/match_candidate_scorer.ex`
- `test/aurum_finance/reconciliation_test.exs`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Candidate retrieval should operate only on `ImportedRow` records with `status: :ready` | Reconciliation assistance should rely on usable imported evidence, not duplicates/invalid rows |
| The default public API should hide `:below_threshold` rows | Keeps the operator-facing contract focused on useful candidates while preserving scorer breadth for future work |
| Score should be exposed as a normalized float in the range `0.0..1.0` | Simplifies UI formatting, tests, and future documentation |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Separated retrieval and scoring into dedicated modules | Keeping all logic inline in `AurumFinance.Reconciliation` | Avoids a monolithic context function and leaves room for future tuning |
| Removed `MatchCandidatePresenter` after initial implementation | Keeping a third shaping module | The shaping concern was too small to justify a separate module at this stage |
| Weighted scoring as `amount > date > description` | Heavier description similarity or flatter scoring | Matches product intent and reduces noisy bank-description influence |

### Blockers Encountered
- None beyond small compile/test adjustments while tuning the threshold fixture and scorer shape

### Questions for Human
- None

### Ready for Next Task
- [x] All outputs complete
- [x] Summary documented
- [x] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
