# Task 04: Security/Architecture Review + Handoff

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 03
- **Blocks**: Task 05

## Assigned Agent
`audit-security` - Security reviewer for features and code changes. Analyzes authentication, authorization, input validation, secrets management, OWASP risks, and PII safety.

## Agent Invocation
Activate the `audit-security` agent with the following prompt:

> Act as `audit-security` following `llms/constitution.md`.
>
> Execute Task 04 from `llms/tasks/012_ledger_primitives/04_security_architecture_handoff.md`.
>
> Read all inputs listed in the task. Perform a security and architecture review of the ledger primitives implementation (Transaction, Posting, zero-sum invariant, balance derivation, void workflow). Focus on entity scoping discipline, data integrity invariants, immutability enforcement, audit completeness, and the absence of currency/entity fields on postings. Then produce handoff notes documenting how this issue unblocks downstream work. Do NOT modify `plan.md`.

## Objective
Validate that the ledger primitives implementation meets security, data integrity, and architectural requirements. Produce a security review report and handoff notes documenting how this issue unblocks transaction UI, import integration, reconciliation, and reporting.

## Inputs Required

- [ ] `llms/tasks/012_ledger_primitives/plan.md` - Master plan with domain invariants, security-relevant decisions, and architectural constraints
- [ ] `llms/constitution.md` - Security and configuration hygiene rules
- [ ] `llms/project_context.md` - Project conventions
- [ ] `llms/tasks/010_entity_model/04_ownership_boundary_contract_output.md` - Entity ownership boundary contract (if exists)
- [ ] `lib/aurum_finance/ledger.ex` - Context API (from Task 01) -- verify entity scoping, audit integration, no delete paths, zero-sum validation, balance derivation
- [ ] `lib/aurum_finance/ledger/transaction.ex` - Transaction schema (from Task 01) -- verify field types, immutability guards
- [ ] `lib/aurum_finance/ledger/posting.ex` - Posting schema (from Task 01) -- verify no currency_code, no entity_id, no updated_at, immutability
- [ ] `lib/aurum_finance/ledger/account.ex` - Account schema -- verify association integrity
- [ ] `priv/repo/migrations/*_create_transactions_and_postings.exs` - Migration (from Task 01) -- verify FK constraints, indexes, trigger
- [ ] `test/aurum_finance/ledger_test.exs` - Context tests (from Task 03) -- verify scoping and invariant tests exist
- [ ] `test/aurum_finance/ledger/transaction_test.exs` - Transaction changeset tests (from Task 03)
- [ ] `test/aurum_finance/ledger/posting_test.exs` - Posting changeset tests (from Task 03)
- [ ] `docs/adr/0008-ledger-schema-design.md` - Ledger schema design ADR
- [ ] `docs/adr/0009-multi-entity-ownership-model.md` - Entity ownership ADR
- [ ] `docs/adr/0018-financial-data-security-boundaries.md` - Security boundaries ADR

## Expected Outputs

- [ ] **Security review report**: Completed in the "Execution Summary" section below, organized by category
- [ ] **Handoff notes file**: `llms/tasks/012_ledger_primitives/04_handoff_notes.md` -- separate file documenting how this issue unblocks downstream work

### Security Review Categories

The review MUST cover each of the following categories with explicit PASS/FAIL findings:

1. **Entity scoping discipline**
   - All transaction query functions enforce `entity_id` scope
   - `get_transaction!/2` takes `entity_id` as first argument
   - `list_transactions/1` requires `entity_id` (raises on missing)
   - `create_transaction/2` validates that all posting accounts belong to the same entity as the transaction
   - No path allows cross-entity data access
   - FK constraint exists on `transactions.entity_id`
   - Indexes cover entity-scoped queries

2. **Zero-sum invariant integrity**
   - Application-level validation in `create_transaction/2` groups by `account.currency_code` (via join), not by a posting field
   - Database-level trigger joins accounts for currency grouping
   - Trigger is `DEFERRABLE INITIALLY DEFERRED` (fires at commit time)
   - No path bypasses both enforcement levels
   - All accounts loaded in a single query (no N+1)

3. **Posting immutability**
   - No update function for postings exists in the context
   - No delete function for postings exists in the context
   - `postings` table has no `updated_at` column
   - `transactions` table also has no `updated_at` column
   - No `Repo.update` or `Repo.delete` calls target postings
   - The only `Repo.update` in the Ledger context targets `transactions` via `void_changeset/1` in `void_transaction/2`
   - No `currency_code` column on `postings` table
   - No `entity_id` column on `postings` table
   - No `memo` column on `transactions` table
   - No `status` column on `transactions` table

4. **Transaction lifecycle integrity**
   - No hard-delete function for transactions in context
   - No `Repo.delete` calls target transactions
   - No `status` enum exists on transactions — void state tracked by `voided_at` (nullable timestamp)
   - `voided_at` is set once via `void_changeset/1`; it is never cleared or overwritten
   - Void workflow creates reversing transaction atomically
   - Guard against double-void: `void_transaction/2` rejects transactions where `voided_at IS NOT NULL`
   - Immutable fields (`entity_id`, `date`, `description`, `source_type`) are guarded in `changeset/2`

5. **Audit completeness**
   - Transaction creation emits audit event with `entity_type: "transaction"`, `action: "created"`
   - Void emits two audit events: `"voided"` on original, `"created"` on reversal
   - Audit events include: `entity_type`, `entity_id`, `action`, `actor`, `channel`, `before`, `after`, `occurred_at`
   - Audit snapshots include posting summaries
   - No sensitive data in audit snapshots (postings have no PII)

6. **Input validation**
   - `description` length constrained (max 500)
   - No `memo` field exists on transactions (confirmed absent from schema and migration)
   - `amount` on postings uses Decimal (no floating point)
   - `Ecto.Enum` restricts `source_type` to valid values (`:manual`, `:import`, `:system`); no `status` enum
   - No raw SQL or string interpolation in queries (parameterized only)
   - FK constraints on `transaction_id` and `account_id` in postings

7. **Balance derivation correctness**
   - `get_account_balance/2` joins accounts for currency_code (does not assume a posting currency field)
   - Joins transactions for `as_of_date` filtering on `transaction.date`
   - Returns `%{}` for accounts with no postings
   - No FX conversion logic present
   - Read-only query with no side effects

### Handoff Notes Content

The handoff document (`04_handoff_notes.md`) MUST cover:
- What this issue delivered (schemas, context APIs, invariants, tests, seed data, read-only Transactions LiveView)
- The `AurumFinance.Ledger` context API surface after this issue
- Key design decisions that downstream consumers must respect:
  - No `currency_code` on postings (always derive from account join)
  - No `entity_id` on postings (derive from transaction)
  - No `memo` on transactions (annotations belong in a future overlay context)
  - No `status` enum on transactions (`voided_at` nullable timestamp is the void marker)
  - No `updated_at` on either transactions or postings
  - Postings are fully immutable; `void_changeset/1` is the only changeset that mutates a transaction
  - Void-and-reverse is the only correction mechanism
  - Balance is computed on read from postings (no cached balance field)
  - `voided_at IS NULL` = active; `voided_at IS NOT NULL` = voided
- What downstream issues are now unblocked:
  - Transaction write UI (LiveView for creating/voiding transactions — requires a future write-UI issue)
  - Import/ingestion integration (calling `create_transaction/2` after staging approval)
  - Reconciliation workflows (operating on postings)
  - Reporting/read models (consuming balance derivation)
  - Classification/overlay layer (category/tag/memo overlays referencing `transaction_id`)
- Any known limitations or technical debt to address in future issues

## Acceptance Criteria

- [ ] Security review covers all 7 categories listed above
- [ ] Each category has explicit PASS/FAIL findings with evidence (file paths, line references)
- [ ] Any FAIL findings include severity (Critical/High/Medium/Low) and recommended fix
- [ ] No Critical or High severity findings remain unresolved
- [ ] Handoff notes file created at `llms/tasks/012_ledger_primitives/04_handoff_notes.md`
- [ ] Handoff notes document the complete Ledger context API surface
- [ ] Handoff notes list all downstream issues that are unblocked
- [ ] Review confirms no `Repo.delete` calls in the Ledger context for transactions or postings
- [ ] Review confirms `postings` table has no `currency_code` or `entity_id` columns
- [ ] `mix precommit` passes (no code changes expected, but verify clean state)

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance/ledger.ex                            # Primary review target: context API
lib/aurum_finance/ledger/transaction.ex                # Review: schema, changeset, immutability
lib/aurum_finance/ledger/posting.ex                    # Review: schema, no currency/entity fields
lib/aurum_finance/ledger/account.ex                    # Review: association integrity
lib/aurum_finance/audit.ex                             # Review: audit integration pattern
priv/repo/migrations/*_create_transactions_and_postings.exs  # Review: trigger, constraints, indexes
test/aurum_finance/ledger_test.exs                     # Review: test coverage completeness
test/aurum_finance/ledger/transaction_test.exs          # Review: changeset test coverage
test/aurum_finance/ledger/posting_test.exs              # Review: changeset test coverage
docs/adr/0008-ledger-schema-design.md                  # Architecture alignment
docs/adr/0009-multi-entity-ownership-model.md          # Entity scoping reference
docs/adr/0018-financial-data-security-boundaries.md    # Security boundaries reference
```

### Patterns to Follow

**Security review pattern** (from `llms/tasks/011_account_model/04_security_architecture_handoff.md`):
- Organize findings by category
- Use PASS/FAIL with evidence for each check
- Reference specific file paths and line numbers
- Severity ratings for any failures
- Actionable recommendations

**Handoff notes pattern** (from `llms/tasks/011_account_model/04_handoff_notes.md` if it exists):
- List delivered artifacts
- Document API surface
- Note design constraints for consumers
- List unblocked downstream work

### Constraints
- This task produces documentation only -- no code changes
- Security review must be thorough enough for an external auditor
- Handoff notes must be actionable for agents working on downstream issues
- Do not re-debate design decisions locked in plan.md (no currency_code on postings, etc.)

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Systematically review each of the 7 security categories
3. For each check, note the file path and evidence (pass/fail)
4. If any failures are found, classify severity and suggest remediation
5. Create `llms/tasks/012_ledger_primitives/04_handoff_notes.md` with downstream unblock documentation
6. Document all findings in the "Execution Summary" section
7. Run `mix precommit` to verify clean state (no code changes expected)

### For the Human Reviewer
After agent completes:
1. Review security findings for completeness across all 7 categories
2. Verify no Critical or High findings are left unresolved
3. Review handoff notes for accuracy and completeness
4. Verify handoff notes correctly describe the API surface
5. If approved: mark `[x]` on "Approved" and update plan.md status
6. If rejected: add rejection reason and specific feedback

---

## Execution Summary
### Work Performed
- Reviewed the ledger primitives implementation against the 7 requested security/architecture categories.
- Verified migration shape, schema shape, Ledger context behavior, and test coverage.
- Compared the implemented model with ADR-0008, ADR-0009, and ADR-0018.
- Created downstream handoff notes in `llms/tasks/012_ledger_primitives/04_handoff_notes.md`.

### Outputs Created
- `llms/tasks/012_ledger_primitives/04_handoff_notes.md`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| The current implementation is the review target even where it intentionally diverges from the original task plan | This PR already removed the DB trigger by product direction; the review must assess the code that actually exists |
| A missing DB trigger is a Medium issue, not High | Application-level validation, transactional writes, and test coverage still protect normal app paths; the gap is in defense-in-depth against direct DB writes |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Recorded one Medium FAIL for the missing DB trigger instead of forcing PASS against the outdated plan | Mark everything PASS, or reopen implementation here | The task explicitly asks for PASS/FAIL findings with evidence; the code no longer matches the original two-layer invariant requirement |
| Treated the rest of the review as PASS when enforced by application code + tests | Requiring DB-only enforcement for all integrity checks | The implemented architecture clearly centralizes writes in the Ledger context and the current tests verify those invariants |

### Security / Architecture Findings

#### 1. Entity Scoping Discipline
- PASS: `get_transaction!/2` requires `entity_id` and scopes by `transaction.entity_id` in [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex#L369).
- PASS: `list_transactions/1` requires explicit entity scope via `require_entity_scope!/2` in [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex#L395) and [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex#L570).
- PASS: `create_transaction/2` validates that all posting accounts belong to the same entity in [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex#L784).
- PASS: FK on `transactions.entity_id` exists in [20260307203018_create_transactions_and_postings.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/priv/repo/migrations/20260307203018_create_transactions_and_postings.exs#L6).
- PASS: entity-scoped indexes exist in [20260307203018_create_transactions_and_postings.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/priv/repo/migrations/20260307203018_create_transactions_and_postings.exs#L17).

#### 2. Zero-Sum Invariant Integrity
- PASS: application-level zero-sum validation groups by `account.currency_code` loaded in one query in [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex#L743) and [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex#L803).
- PASS: account loading is batched with `WHERE id IN ^account_ids` in [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex#L743).
- FAIL, Medium: there is no DB-level trigger anymore, so direct SQL writes are no longer protected by a second enforcement layer. Evidence: the migration only defines tables/indexes in [20260307203018_create_transactions_and_postings.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/priv/repo/migrations/20260307203018_create_transactions_and_postings.exs).
  Recommended fix: add a deferred DB constraint trigger or an equivalent DB-side invariant if defense-in-depth against direct SQL manipulation is still required.

#### 3. Posting Immutability
- PASS: no update/delete API for postings exists in [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex).
- PASS: `postings` schema has no `updated_at`, `currency_code`, or `entity_id` in [posting.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger/posting.ex#L21).
- PASS: `transactions` schema has no `updated_at`, `memo`, or `status` in [transaction.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger/transaction.ex#L24).
- PASS: no `Repo.update` or `Repo.delete` targets postings; inserts happen in [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex#L848).

#### 4. Transaction Lifecycle Integrity
- PASS: there is no hard-delete path for transactions in the Ledger context.
- PASS: `voided_at` is the only void marker and immutable fields are guarded in [transaction.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger/transaction.ex#L84).
- PASS: double-void is rejected in [transaction.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger/transaction.ex#L154) and exercised in [ledger_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance/ledger_test.exs#L655).
- PASS: void-and-reverse runs atomically through `Repo.transaction` in [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex#L888).

#### 5. Audit Completeness
- PASS: create emits `entity_type: "transaction"` and `action: "created"` in [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex#L920).
- PASS: void emits `voided` for the original and `created` for the reversal in [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex#L932) and [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex#L981).
- PASS: audit snapshots include posting summaries in [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex#L504).
- PASS: posting snapshots contain account ids and amounts only; no obvious PII is included.

#### 6. Input Validation
- PASS: transaction description length is constrained in [transaction.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger/transaction.ex#L91).
- PASS: `source_type` is restricted by `Ecto.Enum` in [transaction.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger/transaction.ex#L14).
- PASS: posting amounts use `:decimal` in [posting.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger/posting.ex#L22).
- PASS: queries are parameterized through Ecto; no raw SQL or string interpolation path was found in the Ledger context.
- PASS: FK constraints exist on posting references in [20260307203018_create_transactions_and_postings.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/priv/repo/migrations/20260307203018_create_transactions_and_postings.exs#L25).

#### 7. Balance Derivation Correctness
- PASS: `get_account_balance/2` joins accounts for currency and transactions for `as_of_date` filtering in [ledger.ex](/mnt/data4/matt/code/personal_stuffs/aurum-finance/lib/aurum_finance/ledger.ex#L451).
- PASS: it returns `%{}` when no postings exist, covered in [ledger_test.exs](/mnt/data4/matt/code/personal_stuffs/aurum-finance/test/aurum_finance/ledger_test.exs#L279).
- PASS: there is no FX conversion logic in the Ledger context.
- PASS: the query is read-only and side-effect free.

### Overall Decision
- PASS with 1 Medium finding.
- No Critical or High findings remain unresolved.

### Blockers Encountered
- The task document still assumes a DB trigger that was intentionally removed earlier in the PR. Resolution: recorded as a Medium FAIL in the review instead of forcing the implementation back in this task.

### Questions for Human
1. Do you want to keep the current app-only zero-sum enforcement as the final architecture, or should a future issue restore a DB-side safety net?

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
