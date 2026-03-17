# Task 13: Final PR Audit

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 12
- **Blocks**: None

## Assigned Agent
`audit-pr-elixir` - Staff-level PR reviewer for Elixir/Phoenix backends

## Agent Invocation
Invoke the `audit-pr-elixir` agent with instructions to read this task file, the spec, the execution plan, and the completed implementation/test diffs before starting the review.

## Objective
Perform a final code review of the full rules engine implementation with emphasis on correctness, regressions, security, performance, auditability, and test sufficiency before human sign-off and git operations.

## Inputs Required

- [ ] `llms/tasks/019_rules_engine/plan.md` - Full feature spec
- [ ] `llms/tasks/019_rules_engine/execution_plan.md` - Planned task sequencing and assumptions
- [ ] Completed outputs from Tasks 01 through 12
- [ ] `llms/constitution.md` - Review baseline
- [ ] `llms/project_context.md` - Domain and audit invariants
- [ ] Relevant diffs/files under `lib/`, `test/`, and `priv/repo/migrations/`

## Expected Outputs

- [ ] Review findings documented in this task file's `Execution Summary`
- [ ] Severity-ordered findings list with file references and recommended fixes
- [ ] Explicit statement if no material findings remain

## Acceptance Criteria

- [ ] Review covers schema/migration correctness for both commits
- [ ] Review covers engine determinism and fail-safe behavior
- [ ] Review covers entity scoping, authorization boundaries, and cross-entity leakage risk
- [ ] Review covers manual override correctness and audit event integrity
- [ ] Review covers LiveView regression risk in RulesLive and TransactionsLive
- [ ] Review covers test sufficiency and identifies any missing high-value cases
- [ ] Findings are severity-ordered and actionable
- [ ] If no findings remain, the review says so explicitly and notes residual risks/test gaps

## Technical Notes

### Relevant Code Locations
```text
lib/aurum_finance/classification/
lib/aurum_finance_web/live/rules_live.ex
lib/aurum_finance_web/live/transactions_live.ex
lib/aurum_finance_web/components/transactions_components.ex
test/aurum_finance/
test/aurum_finance_web/live/
priv/repo/migrations/
```

### Patterns to Follow
- Review as a code reviewer, not as an implementer
- Focus findings on bugs, regressions, missing tests, performance risks, and security gaps
- Keep summaries brief; findings come first

### Constraints
- Do NOT implement fixes in this task
- Do NOT perform git operations
- If the review depends on unresolved human decisions from earlier tasks, call them out explicitly

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Review the full implementation against the spec and execution plan
3. Produce severity-ordered findings with concrete file references
4. Note residual risks even if the review is clean
5. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Review findings and decide whether follow-up tasks are required
2. Confirm all blocking issues are resolved or accepted with waiver
3. Only after approval should git operations or merge preparation begin

---

## Execution Summary
Final PR audit completed against `feat/classification_rules` compared to `origin/main`, using the `audit-pr-elixir` review framing and the project constitution as baseline.

### Findings
- `BLOCKER` Same-field additive rules inside one group are broken. `stop_processing: false` does not allow additive same-field behavior because the first proposal claims the field immediately and later matches are skipped as already claimed.
  - Where: `lib/aurum_finance/classification/engine.ex` (`evaluate_group/4`, `merge_group_outcome/2`)
  - Impact: contradicts spec semantics for additive rule composition inside a group
  - Recommended fix: accumulate per-group working classification first, then claim fields only after the group-level merge result is finalized
- `BLOCKER` Invalid `category` actions are accepted at write time and silently dropped at apply time.
  - Where: `lib/aurum_finance/classification.ex`, `lib/aurum_finance_web/live/rules_live.ex`
  - Impact: broken rules can persist, category actions can target invalid/foreign accounts, and global category rules can degrade into silent no-ops
  - Recommended fix: validate category action UUIDs and entity/scope compatibility during create/update, and reject invalid/global category actions unless the model changes
- `BLOCKER` The migration does not enforce the explicit scope model at DB level.
  - Where: `priv/repo/migrations/20260313080823_create_rule_groups_and_rules.exs`
  - Impact: invalid `scope_type` + FK combinations can exist if data bypasses changesets, while engine/query code assumes those states are impossible
  - Recommended fix: add DB check constraints for valid `scope_type` / `entity_id` / `account_id` combinations and cover them with migration/integration tests
- `BLOCKER` The targeted feature suite is not green because `RulesLive` selector contracts drifted from the tests.
  - Where: `lib/aurum_finance_web/live/rules_live.html.heex`, `test/aurum_finance_web/live/rules_live_test.exs`
  - Impact: branch is not merge-ready while changed-area tests fail
  - Recommended fix: restore prior DOM IDs or update tests and any downstream automation consistently
- `MAJOR` The per-transaction classification history view from the spec is still missing.
  - Where: `lib/aurum_finance_web/live/transactions_live.ex`, `lib/aurum_finance_web/components/transactions_components.ex`
  - Impact: current UI shows provenance badges but not the expected audit/event history for rule-then-manual-edit sequences
  - Recommended fix: surface `audit_events` history for the classification record with field, old/new value, source, and timestamp
- `MAJOR` Bulk apply is implemented as a per-transaction loop with repeated DB reads.
  - Where: `lib/aurum_finance/classification.ex`
  - Impact: poor scaling on large date ranges; repeated classification/rule loading will make bulk apply slower than necessary
  - Recommended fix: batch-load classification records and visible rule groups once per run, or reuse grouped evaluation inputs across transactions

### Work Performed
- Read the task spec, full feature plan, execution plan, constitution, and project context
- Reviewed the branch diff against `origin/main` with focus on correctness, regressions, security, performance, auditability, and test sufficiency
- Audited the rules engine, classification writes, migrations, `RulesLive`, `TransactionsLive`, and changed-area tests
- Ran the targeted changed-area suite referenced by the reviewer and incorporated those failures into the audit conclusion

### Outputs Created
- This `Execution Summary`
- Severity-ordered review findings with recommended fixes
- Merge recommendation for human review

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| Review baseline is `origin/main...HEAD` for `feat/classification_rules` | Task 13 is defined as a final branch/PR audit rather than a review of one isolated commit |
| The current local branch state is the review target, including manual-review UX adjustments | Those changes are part of the active branch and affect merge readiness |
| If there were local/unpushed fixes outside the reviewed diff, they were not in scope | The audit was based on the diff visible at review time |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Treat failing changed-area tests as merge blockers | Downgrade to major if failures were purely stale tests | The task requires correctness/regression review and zero-warning/green-suite discipline from the constitution |
| Keep missing classification history as `MAJOR`, not `BLOCKER` | Escalate to blocker because it is in the spec | It is a meaningful spec gap, but the more immediate merge blockers are semantic correctness, DB integrity, and red tests |
| Do not propose implementation patches in this task | Inline code changes during review | Task 13 explicitly says review only, not implementation |

### Blockers Encountered
- None blocking the review itself
- Review outcome contains merge blockers that should be resolved before human sign-off

### Questions for Human
1. Should the missing per-transaction classification history UI be accepted as deferred follow-up, or do you want it treated as required before merge?
2. Do you want global category-setting rules to remain a supported concept, or should Task 13 resolution explicitly ban them at validation time?

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
- [ ] APPROVED - Plan complete
- [ ] REJECTED - See feedback below

### Feedback

### Git Operations Performed
```bash
```
