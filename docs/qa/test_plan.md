# Ledger Primitives Test Plan

## Scenario Mapping

| Scenario | Layer | File |
|---|---|---|
| S01: Transaction changeset required fields, enum, immutability, absent fields | Unit | `test/aurum_finance/ledger/transaction_test.exs` |
| S02: Posting changeset required fields and absent fields | Unit | `test/aurum_finance/ledger/posting_test.exs` |
| S03: `create_transaction/2` happy paths, split postings, multi-currency, invalid inputs, atomicity | Integration | `test/aurum_finance/ledger_test.exs` |
| S04: `get_transaction!/2`, `list_transactions/1`, `void_transaction/2`, `get_account_balance/2` | Integration | `test/aurum_finance/ledger_test.exs` |
| S05: Transactions LiveView read-only rendering, URL filters, voided toggle, empty state | LiveView | `test/aurum_finance_web/live/transactions_live_test.exs` |

## Notes

- The original plan mentioned a DB-level zero-sum trigger. That trigger was intentionally removed and the invariant now lives in the application layer only.
- The Transactions LiveView currently uses compact URL filters via `q=` and date presets (`this_week`, `this_month`, `this_year`, `all`) instead of manual `date_from`/`date_to` inputs in the UI.

## Audit Trail Scenario Mapping

| Scenario | Layer | File |
|---|---|---|
| S01-S05: `AuditEvent` changeset validity, required fields, metadata casting, length validation, no `updated_at` | Unit | `test/aurum_finance/audit/audit_event_test.exs` |
| S06-S15: `Audit` helper atomicity (`insert_and_log`, `update_and_log`, `archive_and_log`, `Audit.Multi.append_event`) including rollback on audit failure | Integration | `test/aurum_finance/audit_test.exs` |
| S26-S34: exhaustive `Audit.Multi.append_event/4` insert/update/archive-style pass/fail/rollback scenarios, inferred vs explicit `entity_id` | Integration | `test/aurum_finance/audit/multi_test.exs` |
| S16-S19: DB immutability triggers for `audit_events`, `postings`, and `transactions` via raw SQL | Integration | `test/aurum_finance/audit_test.exs` |
| S20-S21: caller migration verification for removed legacy APIs, no default transaction-create audit event, and retained transaction void audit emission | Integration | `test/aurum_finance/audit_test.exs`, `test/aurum_finance/entities_test.exs`, `test/aurum_finance/ledger_test.exs` |
| S22-S25: query extensions for date range, offset pagination, unknown filters, and distinct entity types | Integration | `test/aurum_finance/audit_test.exs` |
| S35-S36: Audit log mount, default render, and auth protection | LiveView | `test/aurum_finance_web/live/audit_log_live_test.exs`, `test/aurum_finance_web/live/auth_protection_test.exs` |
| S37-S41: Audit log filter interactions for owner entity, entity type, action, channel, date preset, and clear-filters reset | LiveView | `test/aurum_finance_web/live/audit_log_live_test.exs` |
| S42-S43: Audit log URL hydration and graceful fallback for invalid compact-query values | LiveView | `test/aurum_finance_web/live/audit_log_live_test.exs` |
| S44-S45: Audit log pagination boundaries and page navigation | LiveView | `test/aurum_finance_web/live/audit_log_live_test.exs` |
| S46-S47: Audit log expandable rows, JSON snapshots, and nil-before placeholder rendering | LiveView | `test/aurum_finance_web/live/audit_log_live_test.exs` |
| S48: Audit log empty states and read-only invariant (no mutation controls or write handlers) | LiveView | `test/aurum_finance_web/live/audit_log_live_test.exs` |

## Audit Trail Notes

- Raw SQL trigger assertions live in a non-async `DataCase` module because they intentionally bypass Ecto and exercise the database protections directly.
- Existing entity/account lifecycle audit assertions remain in `entities_test.exs` and `ledger_test.exs`; Task 04 adds the missing foundation-level coverage around the shared `Audit` context itself.

## Classification Engine Scenario Mapping (Task 07)

### Engine Tests (pure, no DB)

| Scenario | Test Name | File |
|---|---|---|
| S01 | account-scoped groups outrank entity-scoped which outrank global | `test/aurum_finance/classification/engine_test.exs` |
| S02 | matched_groups are ordered account, entity, global | `test/aurum_finance/classification/engine_test.exs` |
| S03 | inactive groups are excluded from matching | `test/aurum_finance/classification/engine_test.exs` |
| S04 | groups ordered by priority ASC within same scope | `test/aurum_finance/classification/engine_test.exs` |
| S05 | tie-break by name ASC when priority is equal | `test/aurum_finance/classification/engine_test.exs` |
| S06 | rules ordered by position ASC, tie-break by name ASC | `test/aurum_finance/classification/engine_test.exs` |
| S07 | inactive rules are skipped | `test/aurum_finance/classification/engine_test.exs` |
| S08 | stop_processing true halts after first match in the group | `test/aurum_finance/classification/engine_test.exs` |
| S09 | stop_processing false continues evaluating subsequent rules | `test/aurum_finance/classification/engine_test.exs` |
| S10 | stop_processing only affects current group, not subsequent groups | `test/aurum_finance/classification/engine_test.exs` |
| S11 | rule matches if any posting satisfies all conditions | `test/aurum_finance/classification/engine_test.exs` |
| S12 | rule does not match when no single posting satisfies all conditions | `test/aurum_finance/classification/engine_test.exs` |
| S13 | memo field is not supported in v1 | `test/aurum_finance/classification/engine_test.exs` |
| S14 | currency_code reads from posting.account.currency_code | `test/aurum_finance/classification/engine_test.exs` |
| S15 | currency_code does not match when account has different currency | `test/aurum_finance/classification/engine_test.exs` |
| S16 | first group to propose a field wins, later proposals are skipped_claimed | `test/aurum_finance/classification/engine_test.exs` |
| S17 | different fields from different groups can all be proposed | `test/aurum_finance/classification/engine_test.exs` |
| S18 | add tags without duplicates | `test/aurum_finance/classification/engine_test.exs` |
| S19 | add to existing tags preserves existing and deduplicates | `test/aurum_finance/classification/engine_test.exs` |
| S20 | remove tag from existing set | `test/aurum_finance/classification/engine_test.exs` |
| S21 | notes append adds newline-separated content | `test/aurum_finance/classification/engine_test.exs` |
| S22 | append to nil/empty notes sets the value directly | `test/aurum_finance/classification/engine_test.exs` |
| S23 | notes set replaces entirely | `test/aurum_finance/classification/engine_test.exs` |
| S24 | protected fields are marked as protected and currently_overridden | `test/aurum_finance/classification/engine_test.exs` |
| S25 | protected_fields accepts MapSet | `test/aurum_finance/classification/engine_test.exs` |
| S26 | invalid expression does not crash; other groups still evaluate | `test/aurum_finance/classification/engine_test.exs` |
| S27 | invalid action payload produces :invalid status without crash | `test/aurum_finance/classification/engine_test.exs` |
| S28 | empty tag value produces :invalid status | `test/aurum_finance/classification/engine_test.exs` |
| S29 | no_match? is true when no rule matches | `test/aurum_finance/classification/engine_test.exs` |
| S30 | empty transactions returns empty results | `test/aurum_finance/classification/engine_test.exs` |
| S31 | transactions with no matching groups still produce results | `test/aurum_finance/classification/engine_test.exs` |
| S32 | category values are UUID strings | `test/aurum_finance/classification/engine_test.exs` |
| S33 | investment_type set works with valid string | `test/aurum_finance/classification/engine_test.exs` |
| S34 | investment_type rejects blank value | `test/aurum_finance/classification/engine_test.exs` |
| S35 | each transaction is evaluated independently | `test/aurum_finance/classification/engine_test.exs` |
| S36 | result contains transaction, matched data, and claimed fields | `test/aurum_finance/classification/engine_test.exs` |
| S37 | proposed_change struct has all required fields | `test/aurum_finance/classification/engine_test.exs` |
| S38 | action with unknown field is ignored | `test/aurum_finance/classification/engine_test.exs` |

### Preview API Tests (DB integration)

| Scenario | Test Name | File |
|---|---|---|
| S39 | only returns transactions for the specified entity | `test/aurum_finance/classification/preview_test.exs` |
| S40 | only returns transactions within the date range | `test/aurum_finance/classification/preview_test.exs` |
| S41 | empty date range returns empty list | `test/aurum_finance/classification/preview_test.exs` |
| S42 | voided transactions are excluded from preview | `test/aurum_finance/classification/preview_test.exs` |
| S43 | loads global + entity + account-scoped groups | `test/aurum_finance/classification/preview_test.exs` |
| S44 | does not load groups from a different entity | `test/aurum_finance/classification/preview_test.exs` |
| S45 | no-match rows have no_match? true | `test/aurum_finance/classification/preview_test.exs` |
| S46 | matched rows have no_match? false and proposed_changes | `test/aurum_finance/classification/preview_test.exs` |
| S47 | protected indicators are surfaced when current_classifications provided | `test/aurum_finance/classification/preview_test.exs` |
| S48 | preview does not write to any table | `test/aurum_finance/classification/preview_test.exs` |
| S49 | inactive groups are excluded from preview results | `test/aurum_finance/classification/preview_test.exs` |

### Classification Engine Notes

- Engine tests (S01-S38) use `ExUnit.Case` with in-memory structs only -- no DB access.
- Preview tests (S39-S49) use `DataCase, async: true` with the SQL sandbox.
- S47 originally covered the engine-only protected-field path; after Task 09 introduced persisted `ClassificationRecord` loading in `preview_classification/1`, the regression now lives in Task 10 scenario S12.
- Transactions require double-entry balanced postings; preview tests use an expense-type contra account for the second posting leg.

## Classification Record Scenario Mapping (Task 10)

| Scenario | Acceptance Criteria Covered | Layer | File |
|---|---|---|---|
| S01 | `ClassificationRecord` changeset required fields, tag count/length, notes length, unique `transaction_id` | DataCase / schema integration | `test/aurum_finance/classification/classification_record_test.exs` |
| S02 | `get_classification_record/1` returns `nil` when absent | DataCase / context | `test/aurum_finance/classification/classification_record_test.exs` |
| S03 | single-transaction apply creates a new record, writes rule provenance, emits per-field audit metadata | DataCase / context | `test/aurum_finance/classification/classification_record_test.exs` |
| S04 | single-transaction apply updates an existing unlocked record in place and refreshes `*_classified_by` | DataCase / context | `test/aurum_finance/classification/classification_record_test.exs` |
| S05 | bulk apply summary counts `classified`, `fields_applied`, `fields_skipped_manual`, `no_match`; locked category skipped while unlocked tags/notes update | DataCase / context | `test/aurum_finance/classification/classification_record_test.exs` |
| S06 | bulk apply reports `failed` transactions without rolling back successful ones | DataCase / context | `test/aurum_finance/classification/classification_record_test.exs` |
| S07 | scope-aware apply precedence across `account > entity > global` groups | DataCase / context | `test/aurum_finance/classification/classification_record_test.exs` |
| S08 | `set_manual_field/4` supports all persisted fields (`category`, `tags`, `investment_type`, `notes`) and emits audit entries | DataCase / context | `test/aurum_finance/classification/classification_record_test.exs` |
| S09 | `clear_manual_override/3` retains the current value while unlocking automation for future apply runs | DataCase / context | `test/aurum_finance/classification/classification_record_test.exs` |
| S10 | category validation accepts only same-entity category accounts | DataCase / context | `test/aurum_finance/classification/classification_record_test.exs` |
| S11 | persisted provenance remains readable and non-blocking after referenced rule/group deletion | DataCase / context | `test/aurum_finance/classification/classification_record_test.exs` |
| S12 | persisted manual protection still surfaces through preview results | DataCase / context regression | `test/aurum_finance/classification/classification_record_test.exs` |

## Classification Record Notes

- Task 10 intentionally stays at the context/schema layer. LiveView coverage for apply and per-field display remains in Task 12.
- Intra-scope conflict ordering (`priority ASC`, `name ASC`) is already covered by Task 07 engine tests and is not duplicated here.
- No changes were required in `test/support/factory.ex` or `test/aurum_finance/classification_test.exs`; the existing factory surface was sufficient for deterministic Task 10 scenarios.
