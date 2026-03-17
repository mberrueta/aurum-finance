# Task 06: Preview API (`preview_classification/1`)

## Status
- **Status**: APPROVED
- **Approved**: [X] Human sign-off
- **Blocked by**: Task 05
- **Blocks**: Task 07, Task 08

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix

## Agent Invocation
Invoke the `dev-backend-elixir-engineer` agent with instructions to read this task file and all listed inputs before starting implementation.

## Objective
Implement the read-only preview API in `AurumFinance.Classification` that loads entity-scoped transactions and the visible active rule groups for those transactions, runs the pure engine, and returns structured preview results for a date range without mutating any classification data.

## Inputs Required

- [ ] `llms/tasks/019_rules_engine/plan.md` - Full spec (Issue #20, US-9 through US-12)
- [ ] `llms/tasks/019_rules_engine/05_classification_engine.md` - Engine output contract
- [ ] `llms/constitution.md` - Context API conventions
- [ ] `llms/project_context.md` - Entity scoping and audit conventions
- [ ] `llms/coding_styles/elixir.md` - Elixir style guide
- [ ] `lib/aurum_finance/classification.ex` - Context from Task 02
- [ ] `lib/aurum_finance/classification/engine.ex` - Engine from Task 05
- [ ] `lib/aurum_finance/ledger.ex` - Query patterns and transaction listing behavior
- [ ] `lib/aurum_finance/ledger/transaction.ex` - Preload requirements

## Expected Outputs

- [ ] Updated context: `lib/aurum_finance/classification.ex` with `preview_classification/1`
- [ ] Query helpers or preload helpers needed to fetch preview inputs efficiently
- [ ] Preview result struct/module if it is not already defined in Task 05

## Acceptance Criteria

- [ ] `preview_classification/1` requires `entity_id`, `date_from`, and `date_to`
- [ ] Transactions are loaded entity-scoped only, with all preloads required by the engine and preview UI
- [ ] Rule groups loaded for preview include global groups, entity-scoped groups for the selected entity, and account-scoped groups whose `account_id` matches any posting account present in the previewed transactions
- [ ] Matching groups used for preview respect runtime scope precedence `account > entity > global`, then `priority ASC`, then `name ASC`
- [ ] API performs no writes to `classification_records`, `audit_events`, or any other table
- [ ] API returns a structured list of preview rows keyed by transaction
- [ ] Each preview row includes enough data for UI display: transaction identity, matched groups/rules, per-field proposed values, protected indicators, and no-match state
- [ ] Existing classification state is considered when determining protected/skipped fields for preview
- [ ] Empty-range behavior is explicit and stable: returns `[]` rather than error for no transactions
- [ ] Invalid rule expressions or invalid action payloads are surfaced in a fail-safe manner without crashing the whole preview
- [ ] Public function includes `@doc` with example usage
- [ ] Query code follows project conventions (`list_*` composition or private query helpers rather than repo access from the web layer)

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/classification.ex         # Preview API home
lib/aurum_finance/classification/engine.ex  # Pure evaluation
lib/aurum_finance/ledger.ex                 # Existing query/preload patterns
lib/aurum_finance/ledger/transaction.ex     # Transaction preload shape
```

### Patterns to Follow
- Keep DB loading and engine execution clearly separated
- Use explicit preloads instead of relying on lazy-loaded associations
- Scope everything by `entity_id`
- Gather the set of posting account ids needed to resolve account-scoped groups before invoking the engine
- Return stable application structs/maps that the LiveView can consume directly

### Constraints
- Do NOT implement any UI here
- Do NOT write classification records or audit events here
- Do NOT fold this into `TransactionsLive`; keep the web layer calling the context API only

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Define the query inputs needed by the engine and preview UI
3. Implement `preview_classification/1` in the context using Task 05 output shapes
4. Ensure protected/manual-override preview state is surfaced without mutating data
5. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Verify the API is read-only
2. Verify entity scoping and date-range filtering
3. Review preview payload shape for UI completeness
4. Verify no web-layer repo access was introduced
5. If approved: mark `[x]` on "Approved" and update `execution_plan.md` status

---

## Execution Summary
Completed on 2026-03-14.

### Work Performed
- Added `preview_classification/1` to `AurumFinance.Classification` context as a read-only function
- Added three private helpers: `load_preview_transactions/3`, `load_preview_rule_groups/2`, `extract_posting_account_ids/1`
- Added aliases for `Engine`, `Transaction`, and `Posting` to the context module
- Added `@type preview_opt` for documentation clarity
- Added `@doc` with example usage and `@spec` returning `[Engine.Result.t()]`

### Outputs Created
- Updated: `lib/aurum_finance/classification.ex` with `preview_classification/1` and supporting private helpers

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| `ClassificationRecord` does not exist yet, so `current_classifications` is not passed to the engine | ClassificationRecord is a Task/Issue #21 deliverable; the engine defaults to `%{}` which means no fields are protected |
| Voided transactions are excluded from preview | Voided transactions should not be classified; consistent with `list_transactions` default behavior |
| Preview transactions are ordered by `date ASC, inserted_at ASC` | Chronological order is most natural for a preview list; differs from `list_transactions` which uses `DESC` for recency |
| `list_visible_rule_groups/3` with `is_active: true` provides the correct rule group loading with preloaded rules | Reuses the existing visibility query which already handles global + entity + account scope filtering and includes `[:entity, :account, :rules]` preloads |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Reuse `list_visible_rule_groups/3` for rule group loading | Write a separate query helper | The existing function already implements the exact visibility logic needed (global + entity + account scope), includes the correct preloads for the engine, and applies the deterministic ordering. Adding `is_active: true` filter is sufficient. |
| Return `Engine.Result.t()` structs directly | Define a separate `ClassificationPreview` struct | The `Engine.Result` struct already contains all fields needed by the preview UI (transaction, matched_groups, matched_rules, proposed_changes, claimed_fields, no_match?). A wrapper struct would add indirection without value at this stage. When `ClassificationRecord` is added in Task #21, `current_classifications` can be wired in and the result will include protected field indicators. |
| No `ClassificationPreview` wrapper struct | Creating one as the task output spec mentions | The plan mentions `%ClassificationPreview{}` but the engine `Result` struct already satisfies every preview UI data need. A thin wrapper can be added later if the apply workflow needs different shapes. |

### Blockers Encountered
- None

### Questions for Human
1. When `ClassificationRecord` is implemented in Task #21, `preview_classification/1` should be updated to load existing records and pass `current_classifications` to the engine so protected fields are surfaced in preview. Should this be tracked as a subtask of Task #21 or noted here?

### Ready for Next Task
- [x] All outputs complete
- [x] Summary documented
- [x] Questions listed (if any)

---

## Human Review

### Decision
- [X] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
```
