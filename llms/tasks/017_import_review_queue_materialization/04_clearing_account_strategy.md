# Task 04: Clearing Account Strategy

## Status
- **Status**: COMPLETED
- **Approved**: [x] Human sign-off

## Objective
Define the balancing-account strategy used during import materialization.

## V1 Decision
Use one system-managed import clearing account per `entity_id + currency_code`.

## Resolution Rules
1. Resolve the imported account.
2. Read `entity_id` and `account.currency_code`.
3. Find the matching system-managed clearing account for that entity and currency.
4. If none exists, auto-create it.
5. If multiple matches exist, fail loudly and do not materialize rows until corrected.

## Posting Shape
Each committed imported row creates one transaction with two postings:

- posting on the imported institution account using the row amount
- offsetting posting on the clearing account with the negated amount

## Currency Rule
The clearing account must always use the same currency as the imported account.

- `account.currency_code` is authoritative
- `imported_row.currency` never selects or overrides the clearing account currency
- no FX conversion is allowed

## Notes
- This task has no dependency on row-review workflow concepts.
- Any uniqueness support for the clearing account identity belongs in the branch's single consolidated migration if needed.

## Remaining Open Question
1. Confirm auto-creation on first use as the preferred v1 behavior over manual provisioning.
