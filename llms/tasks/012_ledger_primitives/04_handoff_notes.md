# Task 04 Handoff Notes

## Delivered in Issue #12

- `AurumFinance.Ledger.Transaction` and `AurumFinance.Ledger.Posting` are now the canonical ledger fact model.
- `AurumFinance.Ledger` now exposes transaction creation, retrieval, listing, void-and-reverse, and posting-backed balance derivation.
- Transaction creation enforces:
  - explicit entity scope,
  - account existence,
  - same-entity account membership,
  - zero-sum per effective currency group,
  - minimum posting count.
- Void uses `voided_at` plus a generated reversal transaction linked by `correlation_id`.
- The Transactions UI is now a read-only ledger explorer backed by real DB data and compact URL filters.
- Test coverage now exists at schema, context, and LiveView levels.

## Ledger API Surface

Public transaction-facing functions in [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex):

- `create_transaction(attrs, opts \\ [])`
- `get_transaction!(entity_id, transaction_id)`
- `list_transactions(opts \\ [])`
- `void_transaction(transaction, opts \\ [])`
- `get_account_balance(account_id, opts \\ [])`

Related account APIs remain in the same context and still require explicit entity scope for reads.

## Non-Negotiable Design Rules for Downstream Work

- No `currency_code` on postings.
  Currency is always derived from `posting.account.currency_code` via join.
- No `entity_id` on postings.
  Posting scope is derived from `transaction.entity_id`.
- No `memo` on transactions.
  Notes/annotations belong in a future overlay/classification layer.
- No `status` enum on transactions.
  `voided_at` is the only void marker.
- No `updated_at` on transactions or postings.
  Both are immutable fact tables apart from the set-once `voided_at` mutation.
- Postings are fully immutable.
  There is no posting update/delete path.
- Void-and-reverse is the only correction mechanism.
- Balances are computed from postings on read.
  There is no cached balance field in the ledger write model.
- `voided_at IS NULL` means active.
  `voided_at IS NOT NULL` means voided.

## What This Unblocks

- Transaction write UI.
  A future LiveView/form task can call `create_transaction/2` and `void_transaction/2` instead of inventing ledger logic in the web layer.
- Import approval pipeline.
  Staged import rows can now materialize final ledger facts by calling `create_transaction/2`.
- Reconciliation.
  Reconciliation workflows can operate on immutable postings without redefining ledger semantics.
- Reporting/read models.
  Reporting can consume `list_transactions/1` and `get_account_balance/2` as canonical sources.
- Classification overlays.
  Category/tag/memo overlays can reference `transaction_id` without polluting immutable ledger facts.

## Known Limitations / Follow-ups

- There is no DB-level zero-sum safety net anymore.
  Enforcement currently lives only in the application layer.
- `create_transaction/2` returns postings preloaded, but not `posting.account`; callers needing currency/name details should refetch through `get_transaction!/2` or `list_transactions/1`.
- Transactions LiveView currently supports compact `q=` filters and date presets, not free-form `from/to` date fields in the UI.
- No write UI exists yet for manual transaction entry or void actions.
