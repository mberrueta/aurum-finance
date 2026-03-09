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

## Audit Trail Notes

- Raw SQL trigger assertions live in a non-async `DataCase` module because they intentionally bypass Ecto and exercise the database protections directly.
- Existing entity/account lifecycle audit assertions remain in `entities_test.exs` and `ledger_test.exs`; Task 04 adds the missing foundation-level coverage around the shared `Audit` context itself.
