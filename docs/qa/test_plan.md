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
