# Task 11: Audit Event Integration

## Status
- **Status**: COMPLETED
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

## Implemented Narrow Addition
- imported-file hard delete audit event

The delete audit event stays intentionally narrow:

- actor
- account/imported-file identifiers
- no sensitive raw CSV payloads

## Implementation Notes
- `materialization_requested` is appended atomically with creation of the pending `import_materialization`
- `materialization_completed` is appended atomically with terminal success updates, including `completed_with_errors`
- `materialization_failed` is appended atomically with terminal failed updates
- imported-file hard delete is audited as `deleted` on `imported_file`
- audit metadata stays narrow and excludes raw CSV content or row payloads
