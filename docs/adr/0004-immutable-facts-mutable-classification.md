# ADR 0004: Immutable Facts vs Mutable Classification with Manual Override Protection

- Status: Accepted
- Date: 2026-03-04
- Decision Makers: Maintainer(s)
- Phase: 1 — Research & Landscape Analysis
- Source: `llms/tasks/001_research_landscape_analysis/plan.md`

## Context

When a transaction is imported from a bank or broker statement, two distinct
concerns arise: preserving what the institution reported (facts) and interpreting
what it means (classification). These have fundamentally different mutability
requirements.

If both are stored and edited together, rule re-runs and re-imports can silently
overwrite corrections the user made manually, destroying intent without trace.

## Decision Drivers

1. Imported statement data is legal evidence — it must be preserved exactly as received.
2. Classification (category, tags, notes) is always correctable by rules and users.
3. Manual user corrections must survive automated re-classification without explicit user action.
4. Every classification change must be auditable: who or what changed it, from what value, when.

## Decision

Every transaction has two explicit, non-overlapping layers:

### Immutable facts

Sourced directly from the bank/broker statement. Never modified by the system or the user after import:

- Original amount and currency
- Original transaction date
- Original description (as provided by the institution)
- Source account
- Institution transaction ID / reference

### Mutable classification

The interpretation layer applied on top of facts. Editable by both rules and users:

- Category
- Tags
- Investment type
- Friendly description / notes
- Split assignments

### Manual override protection

- A classification field edited manually is flagged `manually_overridden = true`.
- Rules pipelines **must skip** fields with `manually_overridden = true` on re-runs and re-imports.
- The `classified_by` field records whether the current value was set by a rule (and which one) or by the user.
- Overrides are visible in the audit trail and can be cleared explicitly by the user to allow rules to re-apply.

### Example

| Field | Value | Layer | Editable? |
|---|---|---|---|
| Original description | "UBER TRIP #4821" | Fact | ❌ never |
| Amount | -$1500 | Fact | ❌ never |
| Date | 2025-03-03 | Fact | ❌ never |
| Category | Transport → corrected to Supermarket | Classification | ✅ user |
| `classified_by` | rule_1.1 → user | Classification | auto |
| `manually_overridden` | true (after user correction) | Classification | auto |

## Rationale

This distinction resolves the tension between automation and user intent. Rules
provide a deterministic classification baseline; users correct where rules are wrong;
neither overwrites the other without explicit action.

GnuCash's principle that accounting records are authoritative evidence validates
the immutable-facts posture. The classification layer as a separate mutable overlay
is AurumFinance's design to enable automated workflows without sacrificing user control.

## Consequences

### Positive
- Source evidence is never destroyed or modified.
- User corrections are durable across re-imports and rule re-runs.
- Full audit trail: what was imported, what was classified automatically, what was corrected manually.
- Users can clear overrides to let rules re-apply when they want automation to take over again.

### Negative / Trade-offs
- Data model must explicitly separate fact fields from classification fields.
- Rule engine must check `manually_overridden` before writing to any classification field.

### Mitigations
- Schema design enforces the boundary: fact fields are write-once at import time.
- Rules engine implementation has a mandatory pre-write guard: skip fields where `manually_overridden = true`.

## Implementation Notes

- Fact fields: immutable after insert; no update path exposed.
- Classification fields: versioned; each write records `classified_by`, `manually_overridden`, and timestamp.
- Audit log entries reference the field name, old value, new value, source (rule ID or user ID), and timestamp.
- UI must surface `classified_by` and `manually_overridden` state visibly to the user.
