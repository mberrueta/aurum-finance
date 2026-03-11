# Task 11: Audit Event Integration

## Status
- **Status**: UPDATED
- **Approved**: [ ] Human sign-off

## Objective
Keep audit focused on workflow-level events, not row-review actions.

## Keep
- `materialization_requested`
- `materialization_completed`
- `materialization_failed`

## Remove
- row approval audit
- row rejection audit
- duplicate override audit

## Optional Narrow Addition
- imported-file hard delete audit event, if Task 02 is implemented in code

If included, keep it narrow:

- actor
- account/imported-file identifiers
- no sensitive raw CSV payloads

## Remaining Open Question
1. Should imported-file hard delete be audited in v1, or is standard DB traceability sufficient for this milestone?
