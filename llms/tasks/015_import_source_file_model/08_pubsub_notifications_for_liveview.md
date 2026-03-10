# Task 08: PubSub Notifications for LiveView Updates

## Status
- **Status**: DONE
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 07
- **Blocks**: Tasks 09, 10, 12

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, background jobs, observability, and performance optimizations.

## Agent Invocation
Activate `dev-backend-elixir-engineer` with:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 08 from `llms/tasks/015_import_source_file_model/08_pubsub_notifications_for_liveview.md`.
>
> Read the full plan and Task 07 outputs first. Implement the PubSub side of lifecycle notifications for import updates.

## Objective
Add PubSub-based notifications so LiveView can react to import lifecycle changes and completed results without polling-only assumptions.

## Inputs Required

- [ ] `llms/tasks/015_import_source_file_model/plan.md`
- [ ] Task 07 outputs
- [ ] existing PubSub patterns in the app, if any

## Expected Outputs

- [ ] PubSub topic design
- [ ] Broadcast integration in async orchestration
- [ ] Tests for PubSub notifications

## Acceptance Criteria

- [ ] Notifications are published for `pending`, `processing`, `complete`, and `failed`
- [ ] Notifications are durable-state-driven, not ad hoc state containers
- [ ] Topic design works for account-scoped history/preview UI

## Execution Summary
- Added `AurumFinance.Ingestion.PubSub` as the import-specific PubSub boundary.
- Defined account and imported-file topics so history and detail UIs can subscribe independently.
- Broadcasted durable-state-driven `{:import_updated, %{account_id, imported_file_id, status}}` notifications.
- Wired `pending` notifications from `store_imported_file/1`.
- Wired `processing`, `complete`, and `failed` notifications from `ImportProcessor` after transactional status transitions commit.
- Added tests covering `pending`, `processing`, `complete`, and `failed` notifications.

## Human Review
*[Filled by human reviewer]*
