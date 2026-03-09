# Project Context

This file captures project-specific context used by agents.

## Precedence
- `llms/constitution.md` is the baseline for all LLM agents (Codex, Claude, Gemini, and others).
- This file extends that baseline with project-specific context and must not conflict with it.

## App identity
- App name: `aurum_finance`
- Web module: `AurumFinanceWeb`
- Framework: Phoenix + LiveView

## Domain focus
AurumFinance is a self-hosted personal finance operating system focused on:
- ledger correctness
- reconciliation workflows
- privacy-first data ownership
- import-first ingestion from real statements
- retrospective analysis with automatic projection (not envelope budgeting)

## Product invariants (planning baseline)
- Rules engine is grouped, not flat:
  - independent rule groups can match the same transaction simultaneously
  - first matching rule wins within each group
  - explainability is mandatory: group, rule, and field-level changes
- Imported data is split into:
  - immutable facts (amount, date, original description, account, institution identifiers)
  - mutable classification (category, tags, investment type, notes, splits)
- Manual user edits are protected from automation re-runs via classification override flags.
- Multi-jurisdiction support is first-class and extensible without schema redesign.
- FX model supports N named rate series per currency pair, scoped by jurisdiction/purpose.
- Fiscal residency determines default tax-relevant FX rates.
- Tax event FX snapshots are immutable once recorded.
- Ledger stores original amounts/currencies; conversions are derived on read.

## Engineering conventions
- Follow `AGENTS.md` as the primary instruction source.
- Use `Req` for HTTP integrations.
- Run `mix precommit` before finishing tasks.
- Public ledger/account query APIs should require explicit entity scope by default.
- Ledger posting sign convention is internal and fixed:
  - positive amount = debit
  - negative amount = credit
- Postings do not store `currency_code` or `entity_id`:
  - effective currency comes from `posting.account.currency_code`
  - entity scope comes from `transaction.entity_id`
- Ledger balances are derived on read from postings; there is no cached balance field in the write model today.
- Accounts use a dual classification model:
  - `account_type` for accounting semantics
  - `operational_subtype` for operational meaning
  - `management_group` for management/presentation grouping
- Public backend APIs that are non-trivial should have `@doc`; important public
  backend functions should include executable-style examples when practical.
- Audit scope in v1 is intentionally narrow:
  - audit operationally meaningful actions
  - do not emit audit events for normal transaction/posting creation
  - keep DB immutability protections for `audit_events`, `postings`, and restricted `transactions`
- Current audit helper entry points are:
  - `AurumFinance.Audit.insert_and_log/2`
  - `AurumFinance.Audit.update_and_log/3`
  - `AurumFinance.Audit.archive_and_log/3`
  - `AurumFinance.Audit.Multi.append_event/4`
- Audit snapshots use targeted redaction before persistence.
- `audit_events.metadata` is non-sensitive only; it is not redacted in the
  current implementation.
