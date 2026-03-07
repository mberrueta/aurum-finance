# Task 02: Accounts CRUD LiveView

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Task 03, Task 04, Task 05

## Assigned Agent
`dev-frontend-ui-engineer` - Frontend engineer for Phoenix LiveView. Implements UI components, Tailwind styling, LiveView hooks, and responsive accessible interfaces.

## Agent Invocation
Activate the `dev-frontend-ui-engineer` agent with the following prompt:

> Act as `dev-frontend-ui-engineer` following `llms/constitution.md`.
>
> Execute Task 02 from `llms/tasks/011_account_model/02_accounts_crud_liveview.md`.
>
> Read all inputs listed in the task. Replace the existing mock-based AccountsLive with a fully functional CRUD LiveView backed by the Ledger context from Task 01. Follow the EntitiesLive patterns for event handling, form management, and archive behavior.

## Objective
Replace the existing mock-data `AccountsLive` with a fully functional entity-scoped CRUD LiveView for account management. The UI presents three distinct management surfaces (tabs/sections) for institution-backed accounts, category accounts, and system-managed accounts, all backed by the same `AurumFinance.Ledger.Account` model and `AurumFinance.Ledger` context APIs.

## Inputs Required

- [ ] `llms/tasks/011_account_model/plan.md` - Master plan, especially sections "UI presentation model", "Account classification", and "Canonical Domain Decisions"
- [ ] `llms/tasks/011_account_model/01_domain_data_model_foundation.md` - Task 01 output (schema, context API, helpers)
- [ ] `llms/constitution.md` - HEEx rules (`{}` interpolation, `:if`/`:for` attributes, no `<%= %>`)
- [ ] `lib/aurum_finance_web/live/entities_live.ex` - Reference LiveView pattern (mount, handle_event, form handling, archive toggle, persist result handling)
- [ ] `lib/aurum_finance_web/live/accounts_live.ex` - Existing mock-based file to replace
- [ ] `lib/aurum_finance_web/components/accounts_components.ex` - Existing account components (will need significant rework)
- [ ] `lib/aurum_finance_web/components/ui_components.ex` - Shared UI components (badge, au_card, etc.)
- [ ] `lib/aurum_finance_web/router.ex` - Route already exists at `/accounts` pointing to `AccountsLive`
- [ ] `lib/aurum_finance/ledger.ex` - Context API (created in Task 01)
- [ ] `lib/aurum_finance/ledger/account.ex` - Schema with helpers (created in Task 01)
- [ ] `priv/gettext/accounts.pot` and `priv/gettext/en/LC_MESSAGES/accounts.po` - Gettext domain for accounts UI

## Expected Outputs

- [ ] **LiveView file**: `lib/aurum_finance_web/live/accounts_live.ex` (replaced, no longer mock-based)
  - Entity-scoped mount (reads current entity from socket assigns or session)
  - Tab/section navigation for: Institution, Category, System-managed
  - List view per tab showing relevant accounts filtered by classification
  - Create form with `operational_subtype` as primary user-facing type selector
  - `account_type` auto-derived from selected subtype (not user-editable in form)
  - Edit form with immutable fields shown as read-only (account_type, currency_code, operational_subtype)
  - Archive/unarchive actions
  - Show-archived toggle per tab
  - Stable DOM IDs for testability
- [ ] **Components file**: `lib/aurum_finance_web/components/accounts_components.ex` (updated)
  - Components adapted for real Account structs instead of mock maps
  - Form components for account create/edit
  - Tab navigation component
- [ ] **Gettext entries**: Updated `priv/gettext/accounts.pot` and `priv/gettext/en/LC_MESSAGES/accounts.po` with all new UI strings

## Acceptance Criteria

- [ ] `/accounts` route renders the accounts management page when authenticated
- [ ] Page shows three distinct sections/tabs: Institution, Category, System-managed
- [ ] Institution tab lists accounts where `operational_subtype` is one of: `bank_checking`, `bank_savings`, `cash`, `brokerage_cash`, `brokerage_securities`, `crypto_wallet`, `credit_card`, `loan`, `other_asset`, `other_liability`
- [ ] Category tab lists accounts where `account_type` is `income` or `expense` (no operational_subtype)
- [ ] System-managed tab lists accounts where `account_type` is `equity` and `operational_subtype` is nil
  > **Implementation note (temporary heuristic):** In this first implementation, the System-managed tab is operationally approximated as equity accounts without `operational_subtype`. This is a heuristic, not a domain definition. Not all equity accounts are necessarily system-managed forever, and future issues may introduce an explicit `is_system` marker to replace this approximation. Document this assumption in the Execution Summary.
- [ ] Create form shows `operational_subtype` dropdown as primary type selector for institution-backed accounts
- [ ] Create form shows `account_type` dropdown (income/expense only) for category accounts
- [ ] `account_type` is auto-derived from `operational_subtype` selection and displayed as read-only
- [ ] `currency_code` input validates ISO 4217 format (3 uppercase letters)
- [ ] After creation, `account_type`, `operational_subtype`, and `currency_code` display as read-only in edit mode
- [ ] Archive action calls `Ledger.archive_account/2` and removes account from default list
- [ ] Unarchive action available on archived accounts
- [ ] Show-archived toggle works per tab
- [ ] All accounts are scoped to the current entity
- [ ] All text uses `dgettext("accounts", ...)` Gettext calls
- [ ] HEEx templates use `{}` interpolation and `:if`/`:for` attributes (no `<%= %>` blocks)
- [ ] Stable DOM IDs present: `#accounts-page`, `#accounts-list`, `#account-{id}`, `#account-form`, `#edit-account-{id}`, `#archive-account-{id}`, `#unarchive-account-{id}`, `#toggle-archived-btn`
- [ ] `institution_account_ref` value is NOT shown in flash messages
- [ ] `mix test` passes
- [ ] `mix precommit` passes

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance_web/live/entities_live.ex          # Reference LiveView pattern
lib/aurum_finance_web/live/accounts_live.ex          # File to replace (currently mock-based)
lib/aurum_finance_web/components/accounts_components.ex  # Components to update
lib/aurum_finance_web/components/ui_components.ex    # Shared components (badge, au_card, page_header)
lib/aurum_finance_web/components/core_components.ex  # Core Phoenix components (form, input, etc.)
lib/aurum_finance_web/router.ex                      # Route already defined: live "/accounts", AccountsLive, :index
lib/aurum_finance/ledger.ex                          # Context API (from Task 01)
lib/aurum_finance/ledger/account.ex                  # Schema + helpers (from Task 01)
priv/gettext/accounts.pot                            # Gettext domain template
priv/gettext/en/LC_MESSAGES/accounts.po              # English translations
```

### Patterns to Follow

**LiveView event handling** (from `EntitiesLive`):
- `mount/3` assigns `:active_nav`, `:page_title`, form state, and loads data
- `handle_event("toggle_archived", ...)` toggles `:show_archived` and reloads
- `handle_event("new_entity", ...)` resets editing state and assigns fresh form
- `handle_event("edit_entity", %{"id" => id}, ...)` loads entity and assigns form
- `handle_event("archive_entity", %{"id" => id}, ...)` calls context archive with audit opts
- `handle_event("validate", %{"account" => params}, ...)` for live validation
- `handle_event("save", %{"account" => params}, ...)` branches on editing vs new
- `handle_persist_result/3` handles `{:ok, _}`, `{:error, {:audit_failed, ...}}`, and `{:error, changeset}`

**Form pattern** (from `EntitiesLive`):
- `assign_form/2` creates form via `to_form(changeset, as: :account)`
- Forms use `<.form for={@form}>` with `<.input>` components
- Validation event name: `"validate"`, save event name: `"save"`

**Entity scoping**:
- The current entity must be available in socket assigns (e.g., `@current_entity` or `@current_entity_id`)
- All `Ledger.list_accounts/1` calls must pass `entity_id: @current_entity_id`
- NOTE: The entity selection mechanism may need to be introduced or stubbed if it does not yet exist in the app shell. Document this as an assumption.

**Tab/section approach**:
- Tabs can be implemented as assigns-based state (`@active_tab` with values like `:institution`, `:category`, `:system`)
- Each tab filters the account list differently when calling `Ledger.list_accounts/1`
- The create form adapts based on the active tab (different field visibility)

**Operational subtype to account_type derivation** (from plan.md):
- When user selects an `operational_subtype`, the `account_type` is automatically set
- Use `Account.operational_subtypes_for_type/1` or a reverse lookup to derive the type
- This derivation should happen in the LiveView event handler or via a helper

### Constraints
- The existing `AccountsLive` at `lib/aurum_finance_web/live/accounts_live.ex` uses mock data and must be fully replaced
- The existing `AccountsComponents` at `lib/aurum_finance_web/components/accounts_components.ex` uses mock map shapes and must be adapted for real `Account` structs
- Do NOT add balance display to account rows (balance derivation returns `%{}` until postings exist)
- Do NOT show `institution_account_ref` values in flash messages or console logs
- Route is already defined in router.ex -- do not modify the router
- The `<%= %>` EEx syntax is forbidden in HEEx templates per constitution

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Read `lib/aurum_finance_web/live/entities_live.ex` thoroughly as the primary pattern reference
3. Read `lib/aurum_finance/ledger.ex` and `lib/aurum_finance/ledger/account.ex` (Task 01 outputs) to understand the context API
4. Replace `lib/aurum_finance_web/live/accounts_live.ex` with a fully functional CRUD LiveView
5. Update `lib/aurum_finance_web/components/accounts_components.ex` to work with real Account structs
6. Add/update Gettext entries in `priv/gettext/accounts.pot` and `priv/gettext/en/LC_MESSAGES/accounts.po`
7. Ensure all DOM IDs are stable and follow the naming convention
8. Verify the page renders by checking template compilation
9. Run `mix test` and `mix precommit`
10. Document assumptions about entity selection/scoping mechanism
11. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Review LiveView for correct entity-scoped behavior
2. Verify tab navigation works and filters accounts correctly per classification
3. Verify create form derives `account_type` from `operational_subtype` selection
4. Verify immutable fields are read-only in edit mode
5. Verify archive/unarchive flow matches entities pattern
6. Check that `institution_account_ref` does not appear in flash messages
7. Verify all HEEx uses `{}` interpolation (no `<%= %>`)
8. Verify stable DOM IDs are present for testability
9. Check Gettext usage for all user-facing strings
10. Run `mix test` and `mix precommit` locally
11. If approved: mark `[x]` on "Approved" and update plan.md status
12. If rejected: add rejection reason and specific feedback

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- [What was actually done]

### Outputs Created
- [List of files/artifacts created]

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| | |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| | | |

### Blockers Encountered
- [Blocker] - Resolution: [How resolved or "Needs human input"]

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
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
[Human's notes, corrections, or rejection reasons]

### Git Operations Performed
```bash
# [Commands human executed]
```
