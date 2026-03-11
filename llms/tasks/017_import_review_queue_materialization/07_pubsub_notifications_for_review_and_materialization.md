# Task 07: PubSub Notifications for Materialization

## Status
- **Status**: UPDATED
- **Approved**: [ ] Human sign-off

## Objective
Keep PubSub focused on materialization lifecycle refreshes and any imported-file deletion refresh needed by the UI.

## Keep
- `materialization_requested`
- `materialization_processing`
- `materialization_completed`
- `materialization_failed`

Optional:
- imported-file deleted notification if the UI needs to redirect or refresh lists cleanly

## Remove
- review-decision PubSub events
- any PubSub contract tied to row approval state

## Rules
- PubSub is notification-only
- LiveView reloads durable state after receiving the event
- topics stay account/imported-file scoped

## Remaining Open Question
1. If hard delete is implemented in this milestone, should deletion publish only the existing imported-file topic or both imported-file and account-level history topics?
