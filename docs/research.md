# Research

Research outcomes that inform product and architecture decisions.

## Purpose

- `llms/tasks/**` contains working research artifacts used during LLM execution.
- `docs/**` contains durable project documentation for humans.
- This file is the bridge: concise outcomes, references, and decision promotion status.

## Canonical sources for Phase 1

- Working artifact (full tables, comparisons, and detailed notes):
  - `llms/tasks/001_research_landscape_analysis/plan.md`
- External products analyzed:
  - Firefly III
  - GnuCash
  - Actual Budget

## Distilled findings (no duplication of full tables)

- Internal ledger correctness should remain double-entry, even with a simple personal-finance UX.
- Rules should be grouped and independently evaluable per transaction, with deterministic order inside each group.
- Imported statement data should remain immutable facts; classification should be mutable and user-correctable.
- Manual classification edits must be protected from accidental overwrite during re-import or re-classification.
- Product direction is retrospective plus projection-based, not envelope/zero-sum forward budgeting.
- Multi-jurisdiction and multi-rate FX are first-class concerns from early design, not late add-ons.

## Promoted ADRs

All five core decisions from Phase 1 research have been accepted and captured as ADRs:

- [ADR 0002](adr/0002-ledger-as-internal-double-entry-model.md) — Ledger as internal double-entry model with personal-finance UX mapping.
- [ADR 0003](adr/0003-grouped-rules-engine.md) — Grouped rules engine execution and explainability model.
- [ADR 0004](adr/0004-immutable-facts-mutable-classification.md) — Immutable facts vs mutable classification with manual override protection.
- [ADR 0005](adr/0005-multi-jurisdiction-fx-model.md) — Multi-jurisdiction FX model with named rate series and immutable tax snapshots.
- [ADR 0006](adr/0006-retrospective-projection-posture.md) — Retrospective + projection product posture (non-envelope budgeting).

## Phase completion criteria for documentation

- Detailed research remains in `llms/tasks/**` as historical execution artifact.
- `docs/research.md` contains only durable summaries and references.
- Accepted decisions are captured as ADRs and linked from this file.
