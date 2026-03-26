# Task 09: I18n Gettext Pass for FX and Reports

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 06, Task 08
- **Blocks**: Task 10

## Assigned Agent
`loc-i18n-ptbr-gettext-guardian` - Gettext and locale-quality guardian for Phoenix apps

## Agent Invocation
Invoke the `loc-i18n-ptbr-gettext-guardian` agent with instructions to read this task file and the completed FX/report UI/backend tasks before normalizing all new user-facing strings and translation keys.

## Objective
Ensure the feature's new strings are consistently internationalized across the `fx`, `reports`, and `errors` domains, with translation updates aligned to repo conventions.

This task is a completeness and consistency pass; prior implementation tasks should already use Gettext for all new user-facing strings instead of treating i18n as a later retrofit step.

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] Completed outputs from Tasks 05-08
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] `priv/gettext/en/LC_MESSAGES/fx.po`
- [ ] `priv/gettext/en/LC_MESSAGES/reports.po`
- [ ] `priv/gettext/en/LC_MESSAGES/errors.po`

## Expected Outputs

- [ ] Gettext coverage review for new strings
- [ ] Required translation catalog updates
- [ ] Notes on any inconsistent domain placement or naming

## Acceptance Criteria

- [ ] New FX-management strings live in the `fx` domain unless clearly report-specific
- [ ] Report conversion strings live in the `reports` domain
- [ ] Validation/changeset messages continue to use the `errors` domain
- [ ] No new user-facing hardcoded strings remain in the implemented feature paths
- [ ] Translation keys and phrasing stay consistent with current repo patterns

## Technical Notes

### Relevant Code Locations
```text
priv/gettext/en/LC_MESSAGES/fx.po
priv/gettext/en/LC_MESSAGES/reports.po
priv/gettext/en/LC_MESSAGES/errors.po
lib/aurum_finance_web/live/
lib/aurum_finance/fx/
```

### Constraints
- Keep domain assignment pragmatic and consistent
- Do not rewrite unrelated translation catalogs
- Do not treat this task as permission to introduce hardcoded strings earlier; Tasks 02-08 should already use Gettext at implementation time

## Execution Instructions

### For the Agent
1. Review completed FX/report implementation files for hardcoded strings and misplaced domains.
2. Normalize Gettext usage and update catalogs as needed.
3. Document any remaining naming concerns for QA/final review.

### For the Human Reviewer
1. Confirm the new feature is fully internationalized.
2. Confirm domain placement is sensible and maintainable.
3. Approve before Task 10 begins.

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*
