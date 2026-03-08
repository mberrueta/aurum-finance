# Task 10: Documentation and ADR Sync

## Status
- **Status**: 🔒 BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 09
- **Blocks**: None (final task)

## Assigned Agent
`docs-feature-documentation-author` - Feature documentation writer. Creates and updates documentation aligned with actual application behavior — not aspirational design.

## Agent Invocation

```
Act as docs-feature-documentation-author following llms/constitution.md.

Execute Task 09 from llms/tasks/013_audit_trail/09_audit_documentation_sync.md.

Read all inputs listed in the task file before writing anything.
Documentation must reflect the implementation as shipped, not the plan's aspirational design.
Verify field names and API functions against actual source files before documenting them.
Do NOT modify plan.md or any task file.
```

## Objective

Update project documentation to accurately reflect the audit trail feature as implemented in Tasks 01–08. This includes the domain model document, relevant ADRs, privacy and security docs, and project context conventions. Documentation must match the actual code, not the plan's aspirational design.

---

## Inputs Required

- [ ] `llms/tasks/013_audit_trail/plan.md` — canonical design decisions, terminology, field definitions
- [ ] `llms/tasks/013_audit_trail/08_audit_pr_review.md` — PR review findings and any approved deviations from plan
- [ ] `llms/constitution.md` — documentation rules
- [ ] `llms/project_context.md` — project context (update if new conventions were established)
- [ ] `lib/aurum_finance/audit/audit_event.ex` — source of truth for the AuditEvent schema
- [ ] `lib/aurum_finance/audit.ex` — source of truth for the Audit context API (actual function names and signatures)
- [ ] `lib/aurum_finance/entities/entity.ex` — source of truth for Entities redact fields
- [ ] `lib/aurum_finance/ledger/account.ex` — source of truth for Ledger account redact fields
- [ ] `docs/domain-model.md` — primary update target
- [ ] `docs/adr/0004-immutable-facts-mutable-classification.md` — review: audit trail is an immutable fact store
- [ ] `docs/adr/0007-bounded-context-boundaries.md` — review: Audit as a bounded context
- [ ] `docs/adr/0018-financial-data-security-boundaries.md` — update: redaction rules and append-only enforcement
- [ ] `docs/privacy.md` — update: redaction fields and privacy-by-design principle
- [ ] `docs/security.md` — update: append-only DB enforcement, access control for audit viewer

---

## Expected Outputs

### `docs/domain-model.md` — Update

Add or update the **Audit** section with the `AuditEvent` entity:

- All canonical fields as implemented:
  - `id` (binary UUID, PK)
  - `entity_type` (string — free-form, lowercase singular, e.g. `"entity"`, `"account"`, `"transaction"`, `"transaction_classification"`)
  - `entity_id` (binary UUID — references the audited record)
  - `action` (string — free-form, e.g. `"created"`, `"updated"`, `"archived"`, `"voided"`, `"classified"`)
  - `actor` (string — e.g. `"system"`, `"person"`, `"scheduler"`)
  - `channel` (enum — `:web`, `:system`, `:mcp`, `:ai_assistant`)
  - `before` (map, nullable — full entity snapshot before the operation; nil for inserts; sensitive fields redacted)
  - `after` (map, nullable — full entity snapshot after the operation; nil for hard deletes; sensitive fields redacted)
  - `occurred_at` (utc_datetime_usec — business timestamp, caller-set)
  - `metadata` (map, nullable — catch-all for correlation IDs, import batch refs, rule match context)
  - `inserted_at` (utc_datetime_usec — Ecto automatic)
  - **Explicitly: NO `updated_at`** — append-only; an `updated_at` field is semantically meaningless on an immutable record
- Snapshot model: `before` / `after` are full entity snapshots, not computed diffs or a `changes` field
- Append-only guarantee: enforced at both application layer (no update/delete functions) and database layer (Postgres trigger)
- Redaction: sensitive fields replaced with `"[REDACTED]"` at write time (irreversible)
- Classification event convention: `entity_type: "transaction_classification"` with actions `"classified"`, `"reclassified"`, `"manual_override"`, `"rule_applied"` — classification is not transaction lifecycle

### `docs/adr/0018-financial-data-security-boundaries.md` — Update

Add implementation notes for:

- Redaction fields per entity type (as implemented): Entity → `tax_identifier`; Account → `institution_account_ref`
- Redaction is write-time and irreversible — the audit log cannot be used to reconstruct sensitive values
- Append-only enforcement at the DB level (Postgres trigger on `audit_events` raising on UPDATE/DELETE)
- Audit viewer access: root-authenticated users only; no write/replay/edit actions in UI

### `docs/privacy.md` — Update

Add or update the audit trail section:

- Which fields are redacted and in which contexts (Entity: `tax_identifier`; Account: `institution_account_ref`)
- Principle: auditability does not override privacy-by-design
- The audit log records that a change happened and its type — not a permanent copy of sensitive field values
- Future contexts must declare `@audit_redact_fields` before audit integration

### `docs/adr/0004-immutable-facts-mutable-classification.md` — Review

Verify that the audit trail as implemented aligns with the immutable-facts principle:

- `audit_events` is itself an immutable fact store (append-only)
- Classification audit events (`transaction_classification`) follow the same principle
- Add an implementation note if any deviation or clarification is warranted

### `docs/adr/0007-bounded-context-boundaries.md` — Review

Verify that `AurumFinance.Audit` is correctly described as a bounded context (if referenced). Add a note if the audit context boundary or its cross-cutting nature needs clarification.

### `llms/project_context.md` — Update (if conventions were established)

Document any new project-level conventions, specifically:

- The canonical `Audit` helper API: `Audit.insert_and_log/2`, `Audit.update_and_log/3`, `Audit.archive_and_log/3`, `Audit.Multi.append_event/4` — replacing `with_event/3` and `log_event/1`
- Convention: each domain context declares `@audit_redact_fields` and passes them via `meta[:redact_fields]`
- Classification event naming convention: use `entity_type: "transaction_classification"` (not `"transaction"`) for classification-specific audit events

---

## Acceptance Criteria

- [ ] `docs/domain-model.md` includes `AuditEvent` with all canonical fields, explicit NO `updated_at` note, snapshot model description, append-only guarantee, and classification event convention
- [ ] `docs/domain-model.md` documents that `before`/`after` are full snapshots — not diffs, not a `changes` field
- [ ] `docs/adr/0018-financial-data-security-boundaries.md` has implementation notes for redaction fields and DB-level append-only trigger
- [ ] `docs/privacy.md` documents redaction fields per entity and the privacy-by-design principle
- [ ] ADR-0004 reviewed; implementation note added if any deviation or clarification is needed
- [ ] ADR-0007 reviewed; implementation note added if any deviation or clarification is needed
- [ ] `llms/project_context.md` updated with new Audit helper API conventions (if not already present)
- [ ] No aspirational features documented as if they exist (e.g., CSV export, structured diff view, retention policy)
- [ ] Deferred items noted as deferred with reference to the plan's "Out of Scope" section
- [ ] All field names and function names verified against actual source files (not plan.md alone)

---

## Technical Notes

### Relevant Code Locations

```
lib/aurum_finance/audit/audit_event.ex     # Source of truth for schema fields
lib/aurum_finance/audit.ex                 # Source of truth for context API functions
lib/aurum_finance/entities/entity.ex       # Source of truth for Entities redact fields
lib/aurum_finance/ledger/account.ex        # Source of truth for Account redact fields
docs/domain-model.md                       # Primary update target
docs/adr/0004-immutable-facts-mutable-classification.md  # Review for alignment
docs/adr/0007-bounded-context-boundaries.md              # Review for Audit context boundary
docs/adr/0018-financial-data-security-boundaries.md      # Update with redaction/enforcement notes
docs/privacy.md                            # Update with redaction fields
docs/security.md                           # Update with append-only enforcement
llms/project_context.md                    # Update with Audit helper API conventions
```

### Patterns to Follow

- Match documentation to the actual implementation, not the plan's aspirational design
- Use exact field names and function names from source files
- ADR modifications are additive ("Implementation Notes" section appended) — never rewrite original ADR text
- Mark deferred items explicitly as deferred, with reference to the plan's "Out of Scope" section
- Do not document features that do not exist yet (e.g., CSV export, structured diff view, retention policy, replay)

### Constraints

- Read the actual schema and context files before writing documentation — do not rely on plan.md alone for field names
- If the PR review (Task 08) identified any approved deviations from the plan, document the implemented state, not the plan's intent
- Keep existing documentation structure and formatting conventions

---

## Execution Instructions

### For the Agent

1. Read all inputs listed above — especially `audit_event.ex` and `audit.ex` as the source of truth for field names and API functions
2. Read the PR review task output (Task 08) to identify any deviations from the plan that were approved
3. Read existing `docs/domain-model.md` to understand the current structure and find the right insertion point for `AuditEvent`
4. Update `docs/domain-model.md` with the AuditEvent entity section
5. Read `docs/adr/0018-financial-data-security-boundaries.md` and append implementation notes
6. Read `docs/privacy.md` and add redaction field documentation
7. Review `docs/adr/0004-immutable-facts-mutable-classification.md` for alignment
8. Review `docs/adr/0007-bounded-context-boundaries.md` for alignment
9. Update `llms/project_context.md` with Audit helper API conventions if not already present
10. Cross-check all documentation against actual source files (not plan.md) for accuracy
11. Document all assumptions in the Execution Summary

### For the Human Reviewer

After the agent completes:

1. Verify `docs/domain-model.md` accurately reflects the implemented `AuditEvent` schema — check field names against the actual source file
2. Verify no aspirational features (CSV export, diff view, retention, replay) are documented as existing
3. Verify ADR-0018 implementation notes are accurate (redaction fields, trigger)
4. Verify `docs/privacy.md` redaction section is complete and correct
5. Verify `llms/project_context.md` conventions match the actual API (no references to `with_event/3`)
6. If approved: mark `[x]` on "Approved" and update plan.md status to COMPLETED
7. If rejected: add rejection reason and specific feedback

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- [What was actually done]

### Outputs Created
- [List of files updated]

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| [Assumption 1] | [Why this was assumed] |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| [Decision 1] | [Options] | [Why chosen] |

### Blockers Encountered
- [Blocker 1] - Resolution: [How resolved or "Needs human input"]

### Questions for Human
1. [Question needing human input]

### Ready for Next Task
- [ ] All outputs complete
- [ ] Summary documented
- [ ] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
[YYYY-MM-DD]

### Decision
- [ ] ✅ APPROVED — Feature complete, plan.md status → COMPLETED
- [ ] ❌ REJECTED — See feedback below

### Feedback
[Human's notes, corrections, or rejection reasons]

### Git Operations Performed
```bash
# [Commands human executed]
```
