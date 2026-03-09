# Task 08: Audit Trail Security Review

## Status
- **Status**: ✅ COMPLETE
- **Approved**: [ ] Human sign-off
- **Blocked by**: None
- **Blocks**: Task 09

## Assigned Agent
`audit-security` - Security reviewer for features and code changes. Analyzes authentication, authorization, input validation, secrets management, OWASP risks, and PII safety.

## Agent Invocation
```
Act as a Security Reviewer following llms/constitution.md.

Read and execute Task 08 from llms/tasks/013_audit_trail/08_audit_security_review.md

Before starting, read:
- llms/constitution.md
- llms/project_context.md
- llms/tasks/013_audit_trail/plan.md (full spec — especially "Redaction / Privacy Rules" and "Permissions Model" sections)
- This task file in full
```

## Objective
Perform a security audit of the complete audit trail implementation, focusing on: PII redaction enforcement, append-only guarantee integrity, access control on the audit viewer, input validation on filters, and data leakage risks in before/after snapshots. The review should explicitly respect the reduced v1 scope: operational/manual/admin audit events, not every ledger insert. Produce a security findings report with severity ratings and remediation recommendations.

## Inputs Required

- [ ] `llms/tasks/013_audit_trail/plan.md` - Redaction rules, permissions model, privacy principles
- [ ] `lib/aurum_finance/audit.ex` - Audit helpers, redaction logic, query functions
- [ ] `lib/aurum_finance/audit/audit_event.ex` - Schema and changeset
- [ ] `lib/aurum_finance/audit/multi.ex` - Multi helper
- [ ] `lib/aurum_finance/entities.ex` - Redact fields declaration and usage
- [ ] `lib/aurum_finance/ledger.ex` - Redact fields declaration and usage
- [ ] `lib/aurum_finance_web/live/audit_log_live.ex` - LiveView (filter inputs, data display)
- [ ] `lib/aurum_finance_web/router.ex` - Route protection
- [ ] `priv/repo/migrations/*harden_audit_events*` - Trigger migration
- [ ] `test/aurum_finance/audit_test.exs` - Tests verifying security properties

## Expected Outputs

- [ ] **Security findings report** written to `llms/tasks/013_audit_trail/08_security_findings.md`

## Acceptance Criteria

### Redaction Enforcement
- [ ] Verify `redact_snapshot/2` is called inside the Audit helpers (not delegated to callers)
- [ ] Verify all known sensitive fields are declared in their respective contexts:
  - `Entities`: `[:tax_identifier]`
  - `Ledger` (accounts): `[:institution_account_ref]`
- [ ] Verify redacted values use `"[REDACTED]"` -- not empty strings, not nil, not omitted keys
- [ ] Verify redaction is applied at write time (irreversible -- no way to recover original from audit log)
- [ ] Check for any code paths where snapshots could bypass redaction (e.g., any raw internal audit insert path escaping the helpers)

### DB Immutability Integrity

**`audit_events`** — append-only:
- [ ] Verify trigger `audit_events_append_only` exists and fires on BEFORE UPDATE OR DELETE
- [ ] Verify no application code path can update or delete audit events
- [ ] Verify no raw audit insert API is exposed with update/delete semantics

**`postings`** — append-only:
- [ ] Verify trigger `postings_append_only` exists and fires on BEFORE UPDATE OR DELETE
- [ ] Verify no application code path can update or delete postings
- [ ] Confirm `Posting.changeset/2` is insert-only (no update changeset exists)

**`transactions`** — protected facts:
- [ ] Verify trigger `transactions_immutability` exists and fires on BEFORE UPDATE OR DELETE
- [ ] Verify trigger blocks DELETE unconditionally
- [ ] Verify trigger blocks UPDATE of fact fields (`entity_id`, `date`, `description`, `source_type`, `inserted_at`)
- [ ] Verify trigger enforces `voided_at` set-once (cannot un-void or change once set)
- [ ] Verify trigger allows the void lifecycle UPDATE (`voided_at` NULL → non-NULL, `correlation_id`)
- [ ] Verify no application code path uses raw SQL that could bypass the trigger
- [ ] Cross-check with `Transaction.void_changeset/2` — app-layer and DB-layer protections should be consistent

### Access Control
- [ ] Verify `/audit-log` route is inside the `:require_authenticated_root` pipeline
- [ ] Verify `/audit-log` is inside the `:app` live session with `on_mount: [{AurumFinanceWeb.RootAuth, :ensure_authenticated}]`
- [ ] Verify no API endpoints expose audit data without authentication
- [ ] Verify the LiveView does not expose any write actions

### Input Validation
- [ ] Filter inputs (entity_type, action, channel, entity_id) are validated/sanitized before being passed to Ecto queries
- [ ] Entity ID filter is validated as a UUID format
- [ ] Date range inputs are validated as valid dates
- [ ] No SQL injection risk via filter parameters (all queries use parameterized Ecto queries)

### Data Leakage
- [ ] Before/after snapshots do not contain sensitive fields that should be redacted
- [ ] The `metadata` field does not leak sensitive data (review what is stored)
- [ ] JSON rendering of snapshots in the LiveView does not expose server-side data (e.g., Ecto metadata, database IDs that should be hidden)
- [ ] Error messages do not leak internal system information

### Sobelow Compliance
- [ ] Run `mix sobelow --config .sobelow-conf` and report any new findings related to audit trail code
- [ ] Document any Sobelow waivers needed with justification

### Findings Report Format
Each finding should include:
- **ID**: SEC-NNN
- **Severity**: Critical / High / Medium / Low / Informational
- **Category**: Redaction / Access Control / Input Validation / Data Leakage / Append-Only
- **Description**: What was found
- **Affected files**: List of files
- **Remediation**: Specific recommendation
- **Status**: Open / Mitigated / Accepted Risk

## Technical Notes

### Key Security Properties to Verify

1. **Defense in depth for append-only**: Both application layer (no update/delete functions) AND database layer (trigger) must be verified.

2. **Redaction completeness**: Check that ALL code paths that create audit events go through the helpers that apply redaction. Watch for:
   - Direct `Repo.insert(%AuditEvent{})` calls (should not exist)
   - Any raw internal audit insert path that bypasses helper-level redaction
   - `Audit.Multi.append_event/4` applying redaction to the `before_snapshot` parameter

3. **PII in snapshots**: Review the snapshot serializer functions to ensure they don't accidentally include sensitive associations or fields not in the redact list.

4. **Channel validation**: The `channel` field is an Ecto.Enum -- verify it cannot be spoofed or set to arbitrary values from the web layer.

### Constraints
- This is a review task -- no code changes. Findings are documented for remediation in a follow-up.
- If critical findings are discovered, flag them as blocking for Task 09 (PR review).
- Run Sobelow but do not modify `.sobelow-conf` -- only report findings.

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Systematically review each security area listed in acceptance criteria
3. Run `mix sobelow --config .sobelow-conf` and capture output
4. Write findings to `llms/tasks/013_audit_trail/08_security_findings.md`
5. Summarize critical/high findings in the Execution Summary
6. Document all assumptions

### For the Human Reviewer
After agent completes:
1. Review the security findings report
2. Assess severity ratings for accuracy
3. Decide which findings require remediation before merge (Critical/High) vs. accepted risk (Medium/Low/Informational)
4. If critical findings exist: reject and request remediation before Task 09
5. If no critical findings: approve and proceed to Task 09
6. If approved: mark `[x]` on "Approved" and update plan.md status
7. If rejected: add rejection reason and specific feedback

---

## Execution Summary
Task completed using the available `audit-security` agent definition (`llms/agents/audit_security.md`), because the referenced `security_elixir_reviewer.md` file does not exist in this repository.

### Work Performed
- Reviewed the audit trail implementation across the `Audit` context, `AuditEvent` schema, `Audit.Multi`, `Entities`, `Ledger`, `AuditLogLive`, router wiring, trigger migration, and audit-focused tests.
- Verified the reduced v1 scope remained intact: no default audit events for normal transaction/posting creation, with void actions still audited.
- Ran `mix sobelow --config .sobelow-conf` and incorporated the relevant output into the findings report.
- Produced a structured findings report with severity, evidence, remediation, and status.

### Outputs Created
- `llms/tasks/013_audit_trail/08_security_findings.md`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| The intended deployment model is still single-user self-hosted root access | This remains the explicit permissions model in `plan.md` and materially affects access-control severity |
| Review findings should focus on current production call sites, while still flagging latent API misuse risks | The task asked for a security review of the implementation, not speculative redesign, but append-only audit APIs need future-safe guardrails |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Use `llms/agents/audit_security.md` as the designated security reviewer | Stop on the missing `security_elixir_reviewer.md` reference | The repository clearly ships `audit_security.md` as the available security-review agent and it matches the task intent |
| Treat any raw audit insert redaction bypass as a real finding even though current production callers do not misuse it | Ignore it because only tests call it today | Append-only audit storage makes future misuse costly and irreversible, so the API surface itself matters |
| Record the app-wide CSP Sobelow warning separately from audit-specific findings | Escalate it as an audit-trail blocker | The warning is real but not introduced by this audit feature; keeping it separate preserves signal in the task report |

### Blockers Encountered
- Referenced agent file `llms/agents/security_elixir_reviewer.md` does not exist. Resolution: used `llms/agents/audit_security.md`, which is the repository’s actual security-review agent.

### Questions for Human
1. None.

### Ready for Next Task
- [x] All outputs complete
- [x] Summary documented
- [x] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
[YYYY-MM-DD]

### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
[Human's notes, corrections, or rejection reasons]

### Git Operations Performed
```bash
# [Commands human executed]
```
