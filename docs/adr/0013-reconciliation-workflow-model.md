# ADR 0013: Reconciliation Workflow Model

- Status: Accepted
- Date: 2026-03-05
- Decision Makers: Maintainer(s)
- Phase: 2 — Architecture & System Design
- Source: `llms/tasks/002_architecture_system_design/plan.md` (Step 7, DP-7)

## Context

Reconciliation in AurumFinance confirms that ledger postings align with
institution statements and imported evidence. Phase 1 validated the
GnuCash-style reconciliation posture with three states:

- `unreconciled`
- `cleared`
- `reconciled`

ADR-0008 established immutable postings and correction-through-reversal.
ADR-0010 defined ingestion provenance and deduplication. This ADR defines the
reconciliation state machine, transition triggers/guards, matching strategy,
discrepancy tracking, and correction impact behavior.

ADR-0007 placed reconciliation in `AurumFinance.Reconciliation` (Tier 2),
depending on `Ledger`, `Ingestion`, and `Entities`.

### Inputs

- ADR-0002: Internal double-entry ledger posture.
- ADR-0008: Ledger schema design and immutable posting facts.
- ADR-0010: Ingestion pipeline, row provenance, and deduplication.
- ADR-0007: Bounded contexts and dependency direction.
- Phase 1 references: GnuCash reconciliation workflow semantics.

## Decision Drivers

1. Reconciliation state changes must be explicit, traceable, and reversible.
2. Automatic matching should reduce user workload without hiding uncertainty.
3. Discrepancies must be recorded as first-class domain objects, not UI-only
   warnings.
4. Reconciliation must remain compatible with immutable ledger facts.
5. Corrections to reconciled data must preserve history and force explicit
   re-validation.

## Decision

### 1. Reconciliation State Machine

Reconciliation state is tracked per posting (and surfaced at transaction level
as a derived aggregate).

Allowed states:

- `unreconciled` (default)
- `cleared`
- `reconciled`

#### Semantics

- `unreconciled`: Posting exists in ledger but has no trusted external match.
- `cleared`: Posting has an external candidate match with sufficient confidence
  or has been marked pending by user.
- `reconciled`: Posting has been explicitly confirmed against a statement
  balance/event and closed for the session.

### 2. Transition Triggers and Guards

Transitions are event-driven and constrained:

| From | To | Trigger | Guard |
|------|----|---------|-------|
| unreconciled | cleared | Auto-match from import or manual "mark cleared" | Candidate match exists OR user override reason provided |
| cleared | reconciled | User confirms in reconciliation session | Session open; statement line linked; no unresolved discrepancies |
| reconciled | cleared | Correction or manual "reopen" | Must create audit log entry with reason |
| cleared | unreconciled | User unmatches or candidate invalidated | Match link removed |
| reconciled | unreconciled | Not allowed direct | Must pass through `cleared` reopen first |

Additional rules:

1. Reconciliation transitions are append-only events in audit history.
2. `reconciled` is never set automatically by import.
3. Session closure requires no outstanding critical discrepancies.

### 3. Matching Model (Statement-to-Posting)

Matching compares statement lines (from import rows) to existing postings using
a weighted score, producing candidate matches.

#### MatchResult Entity

| Field | Description | Mutability |
|-------|-------------|------------|
| id | Primary key (UUID) | Immutable |
| entity_id | Owning entity | Immutable |
| reconciliation_session_id | Parent session | Immutable |
| statement_row_reference | Import row / statement line reference | Immutable |
| posting_id | Candidate ledger posting | Immutable |
| match_status | `candidate`, `accepted`, `rejected`, `superseded` | Mutable |
| confidence_score | Numeric score 0..100 | Immutable |
| score_breakdown | JSON explanation by feature | Immutable |
| matched_by | `auto` or `user` | Immutable |
| matched_at | Match timestamp | Immutable |

#### Matching Features

Scoring features:
- amount exact match (highest weight),
- date distance (same day / +/- N days),
- description similarity,
- institution reference equality when available,
- account scope consistency.

Candidate generation rules:

1. Matching scope is per entity and account.
2. Accepted match uniqueness:
   - one statement row may accept at most one posting,
   - one posting may accept at most one statement row within an open session.
3. Auto-matches can set `cleared`, never `reconciled`.

### 4. Discrepancy Tracking

Discrepancies are persistent records tied to a reconciliation session.

#### Discrepancy Entity

| Field | Description | Mutability |
|-------|-------------|------------|
| id | Primary key (UUID) | Immutable |
| entity_id | Owning entity | Immutable |
| reconciliation_session_id | Parent session | Immutable |
| discrepancy_type | `missing_posting`, `unmatched_statement_line`, `amount_mismatch`, `date_mismatch`, `duplicate_match`, `balance_gap` | Immutable |
| severity | `info`, `warning`, `critical` | Mutable |
| statement_row_reference | Optional statement line reference | Immutable |
| posting_id | Optional posting reference | Immutable |
| details | JSON payload with diagnostic context | Mutable |
| status | `open`, `acknowledged`, `resolved` | Mutable |
| raised_at | Creation timestamp | Immutable |
| resolved_at | Optional resolution timestamp | Mutable |
| resolved_by | `auto` or `user` | Mutable |

#### Discrepancy Rules

1. Critical discrepancies block session close.
2. Resolution requires an explicit action (accept match, reject row, correction,
   or documented override).
3. Resolved discrepancies remain in history; they are never deleted.

### 5. Correction Impact on Reconciliation State

Because postings are immutable (ADR-0008), corrections are modeled as void +
replacement transactions. Reconciliation impact is explicit:

1. If a reconciled posting is voided/corrected, its state transitions
   `reconciled -> cleared` with reason `correction_pending_review`.
2. The original accepted MatchResult is marked `superseded`.
3. A new discrepancy (`superseded_reconciled_posting`) is raised until the
   replacement posting is matched and reconciled.
4. Reconciliation is re-confirmed in a subsequent session; no automatic
   promotion to `reconciled`.

### 6. Reconciliation Session Model

Reconciliation occurs within explicit sessions, usually statement-period scoped.

#### ReconciliationSession Entity

| Field | Description | Mutability |
|-------|-------------|------------|
| id | Primary key (UUID) | Immutable |
| entity_id | Owning entity | Immutable |
| account_id | Account being reconciled | Immutable |
| statement_identifier | Statement reference (period/end-date/bank id) | Immutable |
| opened_at | Session open timestamp | Immutable |
| closed_at | Session close timestamp | Mutable |
| opening_balance | Statement opening balance | Immutable |
| closing_balance_expected | Statement closing balance | Immutable |
| closing_balance_computed | Computed balance from reconciled postings | Mutable |
| status | `open`, `balanced`, `closed`, `closed_with_exceptions` | Mutable |
| notes | Optional operator notes | Mutable |

Session close rules:

- `balanced`: computed and expected balances match and no critical discrepancies.
- `closed_with_exceptions`: allowed only when policy permits unresolved
  warnings, never critical discrepancies.
- `closed`: terminal state after balance validation and audit finalization.

## Rationale

The model separates:

- **matching** (probabilistic candidate generation),
- **state transitions** (deterministic workflow),
- **discrepancy management** (evidence and resolution trail).

This keeps reconciliation auditable and resilient to correction workflows while
reducing operator effort through automatic `cleared` suggestions.

It also preserves the immutable-fact posture: reconciliation never edits
postings; it overlays workflow state and audit events.

## Consequences

### Positive

- Deterministic state machine with clear operational semantics.
- Full evidence trail for matching and discrepancy resolution.
- Safe integration with immutable ledger correction patterns.
- Supports both auto-assist and strict human confirmation.

### Negative / Trade-offs

- Additional domain objects and audit data increase model complexity.
- Confidence scoring must be tuned to avoid noisy candidate matches.
- Operators must manage session lifecycle explicitly.

### Mitigations

- Provide default score thresholds and explainable score breakdowns.
- Keep `reconciled` as explicit user confirmation only.
- Use discrepancy severity to prioritize workflow and prevent silent drift.

## Implementation Notes

- Reconciliation state should be stored on postings (or a posting-state table)
  and rolled up to transactions for UI.
- Enforce accepted-match uniqueness constraints in the persistence model.
- Record all transition events in append-only reconciliation audit logs.
- Keep ingestion deduplication and reconciliation matching separate concerns:
  dedup prevents duplicate imports; reconciliation confirms ledger correctness
  against statements.
