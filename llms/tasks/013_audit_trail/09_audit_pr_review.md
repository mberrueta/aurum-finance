# Task 09: Audit Trail PR Review

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 08
- **Blocks**: Task 10

## Assigned Agent
`audit-pr-elixir` - Staff-level PR reviewer for Elixir/Phoenix backends. Reviews correctness, design quality, security, performance, logging, and test coverage.

## Agent Invocation
```
Act as a Staff-Level Elixir PR Reviewer following llms/constitution.md.

Read and execute Task 09 from llms/tasks/013_audit_trail/09_audit_pr_review.md

Before starting, read:
- llms/constitution.md
- llms/project_context.md
- llms/tasks/013_audit_trail/plan.md (full spec for design intent verification)
- llms/tasks/013_audit_trail/08_security_findings.md (security review findings)
- This task file in full
```

## Objective
Perform a comprehensive PR review of the complete audit trail feature before merge. Verify correctness, design quality, performance, test coverage, code style, and compliance with the constitution. Ensure all security findings from Task 08 have been addressed. Produce a review report with approval/rejection decision.

## Inputs Required

- [ ] `llms/tasks/013_audit_trail/plan.md` - Full spec and design decisions for intent verification
- [ ] `llms/tasks/013_audit_trail/08_security_findings.md` - Security findings (from Task 08)
- [ ] All modified/created source files (output of Tasks 01-06)
- [ ] All test files (output of Tasks 04, 06)
- [ ] `llms/constitution.md` - Quality gates, conventions, compliance rules

## Expected Outputs

- [ ] **PR review report** written to `llms/tasks/013_audit_trail/09_pr_review_report.md`

## Acceptance Criteria

### Correctness
- [ ] All design decisions from the plan are correctly implemented (D1-D9)
- [ ] `with_event/3` and `log_event/1` are fully removed -- no references remain
- [ ] All audited domain writes produce atomic audit events
- [ ] Append-only enforcement is in place (trigger + no app-level update/delete)
- [ ] Redaction is applied inside Audit helpers
- [ ] Date-range and offset filters work correctly
- [ ] `distinct_entity_types/0` returns correct data

### Design Quality
- [ ] New Audit API (`insert_and_log`, `update_and_log`, `archive_and_log`, `Multi.append_event`) follows clean, composable design
- [ ] No boilerplate leaked into domain contexts
- [ ] Error handling follows constitution conventions (`{:ok, _}` / `{:error, _}`)
- [ ] Module boundaries are respected (LiveView calls context, not Repo)
- [ ] No dead code from the migration

### Performance
- [ ] No N+1 queries in the audit log viewer
- [ ] `list_audit_events/1` query is efficient with existing indexes
- [ ] `distinct_entity_types/0` query is lightweight
- [ ] Pagination prevents loading unbounded result sets
- [ ] Snapshot serialization does not trigger unnecessary preloads

### Test Coverage
- [ ] Schema changeset tests exist
- [ ] Helper API tests cover success, domain failure, and audit failure paths
- [ ] Atomicity tests verify actual rollback behavior
- [ ] Append-only tests use raw SQL
- [ ] LiveView tests cover mount, filters, pagination, empty states, read-only invariant
- [ ] Caller migration tests verify all domain contexts produce correct audit events
- [ ] Coverage is adequate for a financial audit feature

### Code Style and Conventions
- [ ] Follows Elixir style: 2-space indent, snake_case, PascalCase modules
- [ ] No grouped aliases
- [ ] HEEx uses `{}` interpolation and `:if`/`:for` attributes
- [ ] All user-visible strings use gettext
- [ ] All validation messages use `dgettext("errors", ...)`
- [ ] `@required` / `@optional` / `changeset/2` pattern followed
- [ ] `@doc` and `@spec` on public functions

### Compliance
- [ ] `mix precommit` passes (format, Credo, Dialyzer, Sobelow)
- [ ] `mix test` passes with zero warnings
- [ ] No secrets hardcoded
- [ ] No debug prints or log noise committed
- [ ] Migration is reversible
- [ ] Security findings from Task 08 are resolved or have documented waivers

### PR Description Quality
- [ ] Summary of changes
- [ ] Migration notes (schema changes, trigger)
- [ ] Breaking changes documented (with_event/3 removal)
- [ ] Test plan included

### Review Report Format
The report should include:
- **Overall assessment**: Approve / Request Changes / Reject
- **Strengths**: What was done well
- **Issues found**: Categorized by severity (Must Fix / Should Fix / Nit)
- **Security findings status**: Which findings from Task 08 are resolved
- **Suggested PR description**: Draft for the human to use when creating the PR
- **Checklist compliance**: Which constitution rules are satisfied

## Technical Notes

### Files to Review
```
# Schema and migration
lib/aurum_finance/audit/audit_event.ex
priv/repo/migrations/*harden_audit_events*

# Context API
lib/aurum_finance/audit.ex
lib/aurum_finance/audit/multi.ex

# Migrated callers
lib/aurum_finance/entities.ex
lib/aurum_finance/ledger.ex

# LiveView
lib/aurum_finance_web/live/audit_log_live.ex
lib/aurum_finance_web/router.ex
lib/aurum_finance_web/components/layouts.ex

# Tests
test/aurum_finance/audit_test.exs
test/aurum_finance/audit/audit_event_test.exs
test/aurum_finance_web/live/audit_log_live_test.exs

# Gettext
priv/gettext/en/LC_MESSAGES/audit_log.po
priv/gettext/audit_log.pot
```

### Key Things to Verify via Code Reading
1. Grep for `with_event` across the entire codebase -- must return zero results
2. Grep for `log_event` as a public call -- must return zero results (may exist as private helper)
3. Grep for `Repo.insert` or `Repo.update` inside `entities.ex` and `ledger.ex` -- audited domain writes should go through Audit helpers (except within Multi pipelines); normal transaction/posting creation may remain unaudited by design in v1
4. Verify the Postgres trigger SQL is syntactically correct
5. Verify `timestamps(type: :utc_datetime_usec, updated_at: false)` in `AuditEvent`

### Constraints
- This is a review task -- produce a report, do not modify code
- If "Must Fix" issues are found, the task is rejected and the human decides whether to create a remediation task or fix inline
- The agent should run `mix precommit` and `mix test` as part of the review

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Run `mix test` and capture results
3. Run `mix precommit` and capture results
4. Read every file listed in "Files to Review"
5. Grep for `with_event`, `log_event`, and verify removal
6. Check each acceptance criterion systematically
7. Write the review report to `llms/tasks/013_audit_trail/09_pr_review_report.md`
8. Summarize findings in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Read the PR review report
2. If "Approve": proceed to create the PR and merge
3. If "Request Changes": create remediation tasks or fix issues
4. If security findings are unresolved: block merge until resolved
5. Execute git operations to create the PR
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
- [ ] APPROVED - Proceed to merge
- [ ] REJECTED - See feedback below

### Feedback
[Human's notes, corrections, or rejection reasons]

### Git Operations Performed
```bash
# [Commands human executed]
```
