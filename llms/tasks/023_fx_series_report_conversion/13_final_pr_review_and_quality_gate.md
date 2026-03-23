# Task 13: Final PR Review and Quality Gate

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 12
- **Blocks**: None

## Assigned Agent
`audit-pr-elixir` - Staff-level PR reviewer for correctness, performance, test coverage, and maintainability

## Agent Invocation
Invoke the `audit-pr-elixir` agent with instructions to perform a full PR review of all FX/report-conversion changes after the security audit is complete.

## Objective
Perform the final implementation review across the full feature branch: correctness, schema/query quality, provider/job behavior, UI behavior, i18n completeness, test coverage, and readiness for human merge.

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] Completed outputs from Tasks 02-12
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] All modified files in the feature branch
- [ ] Test results from `mix test`
- [ ] Output from `mix precommit`

## Expected Outputs

- [ ] Written review with findings organized by severity
- [ ] Confirmation of correctness, performance, and coverage expectations
- [ ] Final pass/fail recommendation for human sign-off

## Acceptance Criteria

- [ ] Reviews backend correctness for CRUD, lookup, CSV import, provider sync, and account-report conversion
- [ ] Reviews query/index quality and absence of obvious N+1 issues on list/detail/report surfaces
- [ ] Reviews worker/scheduler behavior and config changes for maintainability
- [ ] Reviews LiveView UX for invalid, empty, and success states
- [ ] Reviews i18n completeness and test coverage against the approved scope
- [ ] Confirms `mix precommit` passed and no debug noise or scope creep remains
- [ ] Produces a clear quality-gate recommendation for the human reviewer

## Technical Notes

### Review Checklist
1. FX persistence and lookup semantics match the approved spec
2. CSV overlap and provider sync behavior remain explicit and bounded
3. Account-report conversion stays single-account and request-time only
4. Missing-rate handling is explicit and non-silent
5. UI/test/i18n quality is sufficient for merge

## Execution Instructions

### For the Agent
1. Review the complete change set and prior audit outputs.
2. Prioritize correctness, regressions, and missing tests/findings.
3. Classify findings as blocking, warning, or note.

### For the Human Reviewer
1. Review the final findings.
2. Decide whether follow-up fixes are needed or the feature is ready to merge.

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*
