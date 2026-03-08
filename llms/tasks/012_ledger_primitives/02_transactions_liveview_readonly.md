# Task 02: Transactions LiveView — Read-Only Ledger Explorer

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 01
- **Blocks**: Task 03 (LiveView test coverage)

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, LiveViews, and components.

## Agent Invocation
Activate the `dev-backend-elixir-engineer` agent with the following prompt:

> Act as `dev-backend-elixir-engineer` following `llms/constitution.md`.
>
> Execute Task 02 from `llms/tasks/012_ledger_primitives/02_transactions_liveview_readonly.md`.
>
> Read all inputs listed in the task. Update the existing `TransactionsLive` to replace hardcoded mock data with real ledger data loaded from the `AurumFinance.Ledger` context. Implement DB-backed filters (entity, account, date range, source type). Add expandable posting detail per transaction. Remove all mutation UI. Follow the patterns established by `AccountsLive`. Do NOT modify `plan.md`.

---

## Objective

Replace the hardcoded mock data in `TransactionsLive` with real data from `AurumFinance.Ledger`. Make the page a read-only ledger explorer: entity-scoped transaction list, DB-backed filters, expandable posting detail per transaction. Remove every mutation path (buttons, forms, actions).

This page validates the ledger model implemented in Task 01. It must work with the seed data from `priv/repo/seeds.exs` (6 transaction scenarios including a void pair).

---

## Inputs Required

- [ ] `llms/tasks/012_ledger_primitives/plan.md` — Canonical field definitions, invariants, and UX States spec
- [ ] `llms/tasks/012_ledger_primitives/01_domain_data_model_foundation.md` — Ledger context API deliverables (source of truth for available functions)
- [ ] `llms/constitution.md` — Global rules
- [ ] `llms/project_context.md` — Project conventions
- [ ] `lib/aurum_finance_web/live/transactions_live.ex` — Existing file to update (hardcoded mock data, mutation buttons)
- [ ] `lib/aurum_finance_web/components/transactions_components.ex` — Existing component file to rewrite
- [ ] `lib/aurum_finance_web/live/accounts_live.ex` — Reference: entity selection pattern, `load_accounts/1`, `handle_event("select_entity", ...)`, filter form patterns
- [ ] `lib/aurum_finance/ledger.ex` — Ledger context (delivered by Task 01); verify `list_transactions/1`, `list_accounts/1` signatures before use
- [ ] `lib/aurum_finance/ledger/transaction.ex` — Transaction schema (delivered by Task 01)
- [ ] `lib/aurum_finance/ledger/posting.ex` — Posting schema (delivered by Task 01)
- [ ] `lib/aurum_finance/ledger/account.ex` — Account schema (for preload reference)
- [ ] `lib/aurum_finance/entities.ex` — `Entities.list_entities/0` (for entity selector)
- [ ] `priv/gettext/en/LC_MESSAGES/transactions.po` — Existing i18n keys (remove stale; add new)
- [ ] `priv/gettext/transactions.pot` — POT file (keep in sync)

---

## Expected Outputs

- [ ] **Updated**: `lib/aurum_finance_web/live/transactions_live.ex`
  - Real data from `Ledger.list_transactions/1` (entity-scoped, postings preloaded)
  - DB-backed filters: entity, account, date_from, date_to, source_type
  - Expandable posting detail per row (toggle on row click via `phx-click`)
  - No mutation UI (no Add Transaction, no Import, no Edit, no Delete, no Void buttons)
  - Follows `AccountsLive` pattern: entity selector, `load_transactions/1`, filter form

- [ ] **Rewritten**: `lib/aurum_finance_web/components/transactions_components.ex`
  - `tx_row/1` — renders one transaction row with correct real-data fields (date, description, source_type, voided indicator, posting count)
  - `tx_posting_detail/1` — renders the expanded postings table (account name, account type, amount, currency)
  - Remove all mock-data-specific fields (`category`, `tags`, `overridden`, `currency` as flat field)

- [ ] **Updated**: `priv/gettext/en/LC_MESSAGES/transactions.po` and `priv/gettext/transactions.pot`
  - Remove stale keys: `btn_add_manual`, `btn_import`, `col_category`, `col_currency`, `col_tags`, `filter_category`, `overlay_manual`, `overlay_rule`
  - Add new keys as needed (see Technical Notes — Gettext section)

- [ ] `mix test` passes (existing tests still green; LiveView-specific tests added in Task 03)
- [ ] `mix precommit` passes

---

## Acceptance Criteria

### Read-Only Invariant
- [ ] No "Add Transaction" button exists in the rendered HTML
- [ ] No "Import" button exists in the rendered HTML
- [ ] No "Edit", "Delete", "Void", or any mutation button exists
- [ ] No `phx-submit` form that targets a create, update, or delete action
- [ ] No `handle_event` clause in the LiveView for mutation operations

### Data Loading
- [ ] `mount/3` loads real transactions from `Ledger.list_transactions/1`
- [ ] Transactions are scoped to `current_entity` (entity_id required by Ledger context)
- [ ] Postings are preloaded on each transaction (use `include_postings: true` or the default preload from `list_transactions/1`)
- [ ] When no entity exists, page renders empty state gracefully (no crash)
- [ ] When no transactions exist for the entity, empty state message is displayed

### Entity Selector
- [ ] Entity selector dropdown renders all entities from `Entities.list_entities/0`
- [ ] Selecting a different entity reloads the transaction list for that entity
- [ ] `handle_event("select_entity", ...)` pattern follows `AccountsLive` exactly

### Filters
- [ ] Filter form uses `phx-change` to update assigns and reload on change (no page reload)
- [ ] **Account filter**: dropdown of all accounts for the current entity; filters transactions with at least one posting to that account
- [ ] **Date from / Date to**: date inputs; filter by `transaction.date >= date_from` and `transaction.date <= date_to`
- [ ] **Source type**: select of `:manual`, `:import`, `:system`, or "All"; filters by `source_type`
- [ ] **Include voided toggle**: checkbox; default off (excludes transactions where `voided_at IS NOT NULL`); when checked, includes voided transactions
- [ ] Filters are passed through to `Ledger.list_transactions/1` opts — no filtering in the LiveView

### Transaction Table
- [ ] Columns: Date, Description, Source Type, Postings count, Voided indicator
- [ ] Date renders `transaction.date` (a `Date` struct, formatted as ISO 8601 or locale date)
- [ ] Source type renders a badge: `:manual` → "Manual", `:import` → "Import", `:system` → "System"
- [ ] Voided indicator: if `transaction.voided_at` is not nil, display a "Voided" badge; otherwise nothing
- [ ] Posting count: shows the number of postings (`length(transaction.postings)`)
- [ ] No `category`, `tags`, `currency`, or `overridden` column (these do not exist in the schema)
- [ ] Clicking a row expands/collapses the posting detail section for that transaction
- [ ] Only one row expanded at a time (or multiple — implementation choice, document the decision)

### Posting Detail (Expanded Row)
- [ ] Shows transaction metadata: date, description, source_type, `voided_at` (if present)
- [ ] Shows a postings sub-table with columns: Account Name, Account Type, Amount, Currency
- [ ] Amount shows the signed value (positive or negative decimal)
- [ ] Currency is derived from `account.currency_code` (joining the preloaded account association)
- [ ] No edit affordance anywhere in the expanded detail

### Seed Data Compatibility
- [ ] Page works when seeded with the 6 scenarios from `priv/repo/seeds.exs`:
  - Simple expense (checking → groceries expense)
  - Transfer between two accounts (checking → savings)
  - Credit card purchase (dining expense → credit card liability)
  - Credit card payment (credit card liability → checking)
  - Split transaction (checking → multiple expense accounts, 3+ postings)
  - Voided transaction + reversal (`voided_at` set on original, reversal linked via `correlation_id`)
  - System transaction (`source_type: :system`)
- [ ] Voided transaction shows "Voided" badge and can be toggled visible/invisible via include-voided filter
- [ ] Multi-currency postings display correct currency per posting (derived from `account.currency_code`)

### Code Organization
- [ ] No business logic or filtering in the LiveView — all filtering in `Ledger.list_transactions/1` opts
- [ ] `transactions_live.ex` only calls `Ledger.*` and `Entities.*` context functions
- [ ] `transactions_components.ex` contains only rendering logic; no queries
- [ ] If `list_transactions/1` does not yet support a filter opt needed, add the `filter_query/2` clause to `ledger.ex` (keep context as source of all query logic)

### Quality
- [ ] `mix precommit` passes (format, Credo, Sobelow)
- [ ] All new i18n strings use `dgettext("transactions", "key")`
- [ ] All removed i18n keys are deleted from both `.po` and `.pot` files
- [ ] No unused assigns in the LiveView socket

---

## Technical Notes

### Schema Alignment — Canonical Field Names

The user specification uses `occurred_at` but **the canonical field is `date`** (a `:date` type, not a datetime). Use `transaction.date` everywhere. There is no `occurred_at` on the `Transaction` schema.

```
transaction.date           # :date — the user-facing transaction date
transaction.description    # :string
transaction.source_type    # Ecto.Enum: :manual | :import | :system
transaction.voided_at      # :utc_datetime_usec | nil — nil = active, non-nil = voided
transaction.inserted_at    # :utc_datetime_usec — when the row was created
transaction.postings       # has_many Posting (preloaded by list_transactions/1)
```

```
posting.account_id         # UUID FK
posting.amount             # Decimal — signed (positive = debit, negative = credit)
posting.account            # belongs_to Account (must be preloaded)
posting.account.name       # string
posting.account.account_type  # Ecto.Enum
posting.account.currency_code  # string (ISO 4217) — the posting's effective currency
```

**There is no `posting.currency_code` field.** Currency is always derived from `account.currency_code`. The account association must be preloaded when rendering postings. Confirm that `list_transactions/1` preloads `[postings: :account]` (nested preload).

### Relevant Code Locations

```
lib/aurum_finance_web/live/transactions_live.ex          # Update: primary target
lib/aurum_finance_web/components/transactions_components.ex  # Rewrite: rendering logic
lib/aurum_finance/ledger.ex                              # Extend if needed: list_transactions/1
lib/aurum_finance_web/live/accounts_live.ex              # Reference: entity selector pattern
priv/gettext/en/LC_MESSAGES/transactions.po              # Update: remove/add keys
priv/gettext/transactions.pot                            # Update: keep in sync
```

### LiveView Pattern (from AccountsLive)

Follow the `AccountsLive` pattern exactly:

```elixir
# mount/3
def mount(_params, _session, socket) do
  entities = Entities.list_entities()
  current_entity = List.first(entities)

  socket =
    socket
    |> assign(
      active_nav: :transactions,
      page_title: dgettext("transactions", "page_title"),
      entities: entities,
      current_entity: current_entity,
      filters: default_filters(),           # %{source_type: nil, account_id: nil, date_from: nil, date_to: nil, include_voided: false}
      accounts: [],                          # populated after entity is selected
      expanded_transaction_id: nil           # for row expand/collapse
    )
    |> load_transactions()

  {:ok, socket}
end

# Entity selection
def handle_event("select_entity", %{"entity_id" => entity_id}, socket) do
  current_entity = find_entity(socket.assigns.entities, entity_id)
  {:noreply, socket |> assign(:current_entity, current_entity) |> reset_filters() |> load_transactions()}
end

# Filter change
def handle_event("filter", params, socket) do
  filters = parse_filters(params)
  {:noreply, socket |> assign(:filters, filters) |> load_transactions()}
end

# Row expand/collapse
def handle_event("toggle_transaction", %{"id" => id}, socket) do
  expanded =
    if socket.assigns.expanded_transaction_id == id, do: nil, else: id
  {:noreply, assign(socket, :expanded_transaction_id, expanded)}
end

# Data loading
defp load_transactions(%{assigns: %{current_entity: nil}} = socket) do
  assign(socket, :transactions, [])
end

defp load_transactions(%{assigns: %{current_entity: entity, filters: filters}} = socket) do
  opts =
    [entity_id: entity.id]
    |> Keyword.merge(filter_opts(filters))

  transactions = Ledger.list_transactions(opts)
  accounts = Ledger.list_accounts(entity_id: entity.id)

  socket
  |> assign(:transactions, transactions)
  |> assign(:accounts, accounts)
end
```

### Preload Depth

`list_transactions/1` must preload `[postings: :account]` — i.e., each posting's account association must be loaded so the component can access `posting.account.name` and `posting.account.currency_code`. Verify this is the case. If `list_transactions/1` only preloads postings (not accounts), add a nested preload in the context function:

```elixir
|> Repo.preload([postings: :account])
```

### Filters Implementation

Filters are passed as opts to `Ledger.list_transactions/1`. The LiveView parses form params into a filters map; the context handles the query. No filtering in the LiveView itself.

```elixir
# Filters map in socket assigns
%{
  source_type: nil | :manual | :import | :system,
  account_id: nil | UUID,
  date_from: nil | Date,
  date_to: nil | Date,
  include_voided: false | true
}

# Converted to list_transactions opts
[
  entity_id: entity.id,
  source_type: :manual,         # or omit if nil
  account_id: account_id,       # or omit if nil
  date_from: ~D[2026-01-01],    # or omit if nil
  date_to: ~D[2026-03-31],      # or omit if nil
  include_voided: false          # always passed; default false in list_transactions/1
]
```

### Row Expand Pattern

Use a simple `expanded_transaction_id` assign to track which row is expanded:

```html
<tr phx-click="toggle_transaction" phx-value-id={tx.id} class="cursor-pointer">
  ...
</tr>
<tr :if={@expanded_transaction_id == tx.id}>
  <td colspan="5">
    <.tx_posting_detail transaction={tx} />
  </td>
</tr>
```

### Gettext Keys

**Remove** (stale — no longer used):
- `btn_add_manual` — mutation button removed
- `btn_import` — mutation button removed
- `col_category` — category does not exist on Transaction schema
- `col_currency` — no top-level currency column (currency is per-posting)
- `col_tags` — tags do not exist on Transaction schema
- `filter_category` — category filter removed
- `overlay_manual` / `overlay_rule` — classification overlay concept removed

**Keep**:
- `page_title`, `page_subtitle`
- `col_date`, `col_description`, `col_source`
- `filter_date`, `filter_source`, `filter_account`

**Add** (new):
- `col_postings` — "Postings" column header
- `col_status` — "Status" column header (for voided badge)
- `filter_date_from` — "From" date filter label
- `filter_date_to` — "To" date filter label
- `filter_include_voided` — "Include voided" toggle label
- `filter_source_all` — "All sources" default option
- `badge_voided` — "Voided" badge text
- `badge_manual` / `badge_import` / `badge_system` — source type badges
- `empty_transactions` — empty state message when no transactions exist
- `posting_detail_title` — "Postings" heading in the expand detail
- `col_account` — "Account" column header in posting detail
- `col_account_type` — "Account Type" column header in posting detail
- `col_amount` — "Amount" column header in posting detail (reuse existing key if present)

### Constraints
- Do NOT implement any mutation `handle_event` clauses
- Do NOT call `Ledger.create_transaction/2`, `Ledger.void_transaction/2`, or any write operation
- Do NOT add forms that submit data changes
- Do NOT render `transaction.category`, `transaction.tags`, `transaction.memo` — these fields do not exist on the schema
- Do NOT render `posting.currency_code` as a field — always use `posting.account.currency_code`
- Keep all query logic in the Ledger context; LiveView only calls context functions
- If a filter opt is missing from `Ledger.list_transactions/1`, add it via a `filter_query/2` clause in `ledger.ex`

---

## Execution Instructions

### For the Agent
1. Read all inputs listed above; verify the `list_transactions/1` signature and preload depth from the delivered `ledger.ex`
2. Update `transactions_live.ex`:
   - Remove `mock_transactions/0`
   - Add `mount/3` with entity loading and filter assigns (follow `AccountsLive` pattern)
   - Add `handle_event("select_entity", ...)`, `handle_event("filter", ...)`, `handle_event("toggle_transaction", ...)`
   - Add `load_transactions/1` private function
   - Remove all mutation `handle_event` clauses
3. Rewrite `transactions_components.ex`:
   - `tx_row/1` — real `Transaction` struct (date, description, source_type, voided_at, posting count)
   - `tx_posting_detail/1` — expanded postings table (account name, account type, amount, `account.currency_code`)
   - Remove `tx_row/1` fields that reference non-existent schema fields (category, tags, overridden, currency)
4. Update filter form in the template — real `phx-change` form with account dropdown, date inputs, source select, include-voided checkbox
5. Update gettext files — remove stale keys, add new ones, run `mix gettext.extract` to sync POT
6. If `list_transactions/1` needs additional filter opts (e.g., `date_from`, `date_to`), add `filter_query/2` clauses to `ledger.ex`
7. Verify nested preload depth: `[postings: :account]` must be preloaded for `posting.account.currency_code` to work
8. Run `mix test` to verify existing tests pass
9. Run `mix precommit` to verify format, Credo, Sobelow
10. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Visually verify the page at `/transactions` — real rows appear, not mock data
2. Verify no mutation buttons are present (inspect DOM)
3. Verify filters update the query (check network or Ecto log)
4. Expand a transaction row — postings must show account name, amount, and correct currency (from `account.currency_code`)
5. Verify voided transaction shows "Voided" badge; include-voided toggle shows/hides it
6. Verify multi-currency scenario shows correct currency per posting (USD posting shows USD, EUR posting shows EUR)
7. Verify seed data scenarios render correctly
8. Run `mix test` and `mix precommit` locally
9. If approved: mark `[x]` on "Approved" and update plan.md status
10. If rejected: add rejection reason and specific feedback

---

## Execution Summary
Implemented the transactions page as a real read-only ledger explorer backed by `AurumFinance.Ledger`, replacing all mock transaction data and mutation affordances.

### Work Performed
- Replaced the mock `TransactionsLive` page with entity-scoped, DB-backed transaction loading.
- Added entity selection, account/date/source filters, and include-voided toggle, all delegated to `Ledger.list_transactions/1`.
- Rewrote `TransactionsComponents` to render real transaction rows and expandable posting detail using preloaded account data.
- Updated the transactions gettext domain to match the new read-only UI.
- Added focused LiveView tests for rendering, filtering, and posting-detail expansion.
- Updated `Ledger.get_transaction!/2` and `Ledger.list_transactions/1` to preload `[postings: :account]`.

### Outputs Created
- Updated `lib/aurum_finance_web/live/transactions_live.ex`
- Updated `lib/aurum_finance_web/components/transactions_components.ex`
- Updated `lib/aurum_finance/ledger.ex`
- Updated `priv/gettext/en/LC_MESSAGES/transactions.po`
- Updated `priv/gettext/transactions.pot`
- Added `test/aurum_finance_web/live/transactions_live_test.exs`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| A single expanded transaction row is enough for this milestone | It keeps state simple and matches the task’s “single or multiple is implementation choice” allowance. |
| Entity selection should mirror `AccountsLive` rather than invent a transactions-specific scope control | The project already has that pattern and it keeps page behavior consistent. |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Keep all filtering in the Ledger context | Filtering in LiveView assigns | Preserves context ownership of query logic and avoids duplicated ledger rules in the UI. |
| Render expandable detail inline below the summary row | Side panel, modal, or separate show page | Lowest-cost way to inspect postings while keeping the explorer read-only. |
| Add focused LiveView tests now | Waiting until Task 03 only | The constitution requires tests for executable logic changes, and these checks are small and stable. |

### Blockers Encountered
- Existing smoke/component tests assumed the old mock transaction component API - Resolution: updated them to the real transaction struct/component shape.

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
