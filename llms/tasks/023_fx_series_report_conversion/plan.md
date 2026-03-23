# Plan: FX Series and Optional Report FX Conversion

## Goal

Implement the first real Exchange Rates foundation for AurumFinance, replacing the current mock FX page with a fully functional system. This includes:

1. `fx_series` and `fx_rate_records` persistence and context API
2. Basic UI for managing FX Series (list, detail, create, edit)
3. CSV upload flow for manual FX series
4. Provider-module based FX series with async backfill/sync jobs
5. Optional FX conversion when generating a single-account report

This is intentionally small and explicit. It is not a general FX engine.

## Status

- **Status**: READY FOR IMPLEMENTATION

---

## Project Context

### Related Entities

- `AurumFinance.Ledger.Account`
  - Location: `lib/aurum_finance/ledger/account.ex`
  - Key fields: `currency_code` (3-letter uppercase ISO), `entity_id`, `name`, `account_type`
  - Relevance: Account `currency_code` determines native currency for FX conversion filtering. The account is the source entity for report-time conversion.

- `AurumFinance.Entities.Entity`
  - Location: `lib/aurum_finance/entities/entity.ex`
  - Key fields: `country_code`, `fiscal_residency_country_code`, `default_tax_rate_type`
  - Relevance: Entity scope is the ownership boundary. FX series are global (not entity-scoped) but report usage is entity-contextual.

- `AurumFinance.Reporting.DailyBalanceSnapshot`
  - Location: `lib/aurum_finance/reporting/daily_balance_snapshot.ex`
  - Key fields: `account_id`, `entity_id`, `snapshot_date`, `closing_balance`
  - Relevance: The balance values that would be converted using FX rates at report time.

- `AurumFinance.Reporting` (context)
  - Location: `lib/aurum_finance/reporting.ex`
  - Relevance: The reporting context provides account-level balance data. FX conversion applies per-account at report generation time.

### Related Features

- **FX Live (mock page)** (`lib/aurum_finance_web/live/fx_live.ex`)
  - Currently a mock-only page at route `/fx` with hardcoded series data.
  - This feature replaces the mock with real persistence and interaction.
  - Pattern: The mock shows a series list + detail panel layout that should inform the real UI.

- **Reporting LiveViews** (`lib/aurum_finance_web/live/net_worth_live.ex`, `lib/aurum_finance/reporting/`)
  - Pattern to follow: `as_of_date` filter form pattern, `load_report/3` → assign derivatives.
  - FX conversion in this iteration is account-scoped, not integrated into multi-account reports like Net Worth.

- **Ingestion CSV Parser** (`lib/aurum_finance/ingestion/parsers/csv.ex`)
  - Demonstrates how CSV parsing is structured in this project (hand-rolled parser, no NimbleCSV).
  - The FX CSV upload will use a simpler schema (just `date` and `value`) but can follow similar parsing patterns.

- **Import Worker** (`lib/aurum_finance/ingestion/import_worker.ex`)
  - Pattern for Oban workers: `use Oban.Worker, queue: :imports`, `new_job/1`, `perform/1`.

- **Daily Balance Snapshot Refresh Worker** (`lib/aurum_finance/reporting/daily_balance_snapshot_refresh_worker.ex`)
  - Pattern for reporting-queue Oban workers with uniqueness constraints and PubSub broadcasting.

### Permissions Model

- **Auth model**: Single root user with session-based authentication (`AurumFinanceWeb.RootAuth`). No role-based access control exists. All authenticated users have full access.
- **Route pipeline**: `:require_authenticated_root` pipeline, within the `:app` live_session.
- **Tenant isolation**: Not applicable. AurumFinance is single-user, self-hosted. Entities provide ownership boundaries for ledger data, but FX series are global resources (not entity-scoped).

### Naming Conventions Observed

- **Contexts**: `AurumFinance.Ledger`, `AurumFinance.Reporting`, `AurumFinance.Ingestion`, `AurumFinance.Classification`
- **Schemas**: `AurumFinance.Ledger.Account`, `AurumFinance.Reporting.DailyBalanceSnapshot`
- **LiveViews**: `AurumFinanceWeb.FxLive`, `AurumFinanceWeb.NetWorthLive`, `AurumFinanceWeb.ReportsLive`
- **Workers**: `AurumFinance.Reporting.DailyBalanceSnapshotRefreshWorker`, `AurumFinance.Ingestion.ImportWorker`
- **Context functions**: `list_*` with `opts` keyword list, `create_*`, `get_*!`, `update_*`, `delete_*`
- **Filtering**: Private `filter_query/2` with multi-clause pattern matching
- **Primary keys**: `{:id, :binary_id, autogenerate: true}`
- **Timestamps**: `timestamps(type: :utc_datetime_usec)`
- **Changesets**: Declare `@required` and `@optional`, cast both, validate with `dgettext("errors", ...)`
- **Slugs**: `AurumFinance.Helpers.slugify/1` already exists for slug generation
- **Gettext domain**: `"fx"` domain already exists at `priv/gettext/en/LC_MESSAGES/fx.po`

### Dependency Note

- `Req` is referenced in `llms/project_context.md` as the preferred HTTP library but is **not currently in `mix.exs` dependencies**. Provider modules that call remote APIs will require adding `{:req, "~> 0.5"}` as a dependency.
- `Oban.Plugins.Cron` is not currently configured. The global FX sync scheduler will need to add it to the Oban plugin config, or use an alternative scheduling approach (e.g., a GenServer with `Process.send_after` or Oban's `Oban.Plugins.Cron`).

### Oban Queue Configuration

- Existing queues: `imports: 5`, `materializations: 5`, `reporting: 5`
- FX background jobs (backfill, sync) will need a queue. Options: reuse `reporting` or add a new `fx` queue.

---

## Key Product Decisions (Closed)

The following decisions are already finalized and must not be revisited during implementation.

### FX Source Kinds

Only two source kinds: `csv_upload` and `provider_module`. No others.

### FX Series Entity

- `name`, `slug` (auto from `Helpers.slugify(name)` at creation; immutable after), `description` (nullable)
- `base_currency_code`, `quote_currency_code` (3-letter uppercase, must differ)
- `from_date`, `to_date` (nullable; `to_date >= from_date` when present; `nil` = still active)
- `source_kind` (enum: `csv_upload`, `provider_module`)
- `provider_module` (nullable; required only when `source_kind = provider_module`)
- `slug` must be unique

### FX Rate Records Entity

- `fx_series_id`, `effective_date`, `rate_value`
- Unique constraint on `(fx_series_id, effective_date)`
- One row per day, no time-of-day support

### Edit/Delete Rules

- **Editable always**: `name`, `description`, `from_date`, `to_date`
- **Immutable always** (set at creation, never editable): `base_currency_code`, `quote_currency_code`, `source_kind`, `provider_module`
- If `fx_series` has records: **cannot delete**
- If `fx_series` has zero records: **can delete**

> **Design decision**: Identity fields (`currencies`, `source_kind`, `provider_module`) are immutable regardless of whether records exist. If the user picked the wrong currency pair or source kind, the correct path is to delete the empty series and create a new one. This avoids ambiguity about what "the same series" means.

### CSV Import Behavior

- Schema: `date`, `value`
- Normalize date to `YYYY-MM-DD`, value to clean decimal
- Reject entire file if any row is invalid
- On overlapping dates: show confirmation dialog, user can cancel or continue with override (upsert)
- No overlap: import directly
- No heuristic validation of inverted values

### Provider Module Behavior

- Stores `provider_module` identifier string
- Initial providers: `bcb_ptax`, `frankfurter_ecb`
- Supported providers list sourced from a central module/config (not hardcoded in changeset or UI); UI combo consumes that list
- Provider module is responsible for: API call, response parsing, normalization to `date` + `value`
- Best effort: invalid pairs fail at job runtime, not at creation
- Credentials in env vars, not DB

### Job/Scheduling Architecture

- On `provider_module` series creation: enqueue initial backfill job (`from_date` to `to_date` or today)
- Global scheduler: runs on app start and daily schedule, scans all series, computes max effective_date per series, enqueues sync for stale series (coverage behind yesterday)
- No per-series recurring jobs

### Report-Time FX Conversion

- Default: reports show native currency, no conversion
- Optional: user chooses to convert at report generation time (temporary, not persisted as preference)
- Form fields when convert enabled: `target_currency_code`, `fx_series_id`
- FX series selection filtered by: connects account currency and target currency (direct or inverted), `from_date <= as_of_date`, `to_date is nil or >= as_of_date`
- If series does not match rules: form is invalid, report must not generate

### FX Lookup Strategy

- `latest on or before` with 4-day max staleness
- Valid if `effective_date <= report_date` and `effective_date >= report_date - 4 days`
- No valid rate in window: report still generates, converted value unavailable, show message: "No FX rate found within 4 days"

### Inverted Series

- Allowed at runtime: use `1 / rate_value`
- Inversion is runtime-only, never during import

### Report Result Data (with conversion)

- Surface: native amount, native currency, converted amount, target currency, selected FX series, rate date used
- Storing `fx_series_id` in report metadata is acceptable if report metadata is persisted

---

## User Stories

### US-1: Create a Manual CSV FX Series

As the **authenticated user**, I want to create a new FX series with source kind `csv_upload`, so that I can manually manage exchange rate data for a currency pair.

### US-2: Create a Provider-Module FX Series

As the **authenticated user**, I want to create a new FX series with source kind `provider_module` and select a supported provider, so that exchange rates are automatically fetched and kept current.

### US-3: View FX Series List

As the **authenticated user**, I want to see all my FX series in a table showing name, currency pair, source, date range, last ingested date, and row count, so that I can manage my rate data at a glance.

### US-4: View FX Series Detail

As the **authenticated user**, I want to view a single FX series showing its metadata and latest rate records, so that I can verify the data is correct.

### US-5: Edit an FX Series

As the **authenticated user**, I want to edit the name, description, from_date, and to_date of an FX series, so that I can correct metadata without losing existing rate data.

### US-6: Upload CSV Rates to a Manual Series

As the **authenticated user**, I want to upload a CSV file with date/value rows to a `csv_upload` series, so that I can populate or update rate data from external sources.

### US-7: Trigger Manual Sync for a Provider Series

As the **authenticated user**, I want to trigger a manual sync for a `provider_module` series, so that I can force a rate update without waiting for the daily schedule.

### US-8: Automatic Backfill on Provider Series Creation

As the **authenticated user**, when I create a `provider_module` series, I expect an initial backfill job to be enqueued automatically, so that historical rates are populated without manual intervention.

### US-9: Daily Global FX Sync

As the **system operator**, I want a global scheduled process to scan all provider-module series and enqueue sync jobs for any series that are behind yesterday's date, so that rates stay current without manual action.

### US-10: Generate Account Report with Optional FX Conversion

As the **authenticated user**, I want to optionally convert a single account's balance to a target currency using a selected FX series when generating an account report, so that I can see the account value in a different currency.

### US-11: Handle Missing FX Rate Gracefully

As the **authenticated user**, when FX conversion is enabled but no valid rate exists within the 4-day staleness window, I want the report to still generate with the native balance visible and a clear message that the converted value is unavailable, so that I am not blocked from seeing my data.

### US-12: Delete an Empty FX Series

As the **authenticated user**, I want to delete an FX series that has no rate records, so that I can clean up series created in error.

---

## Acceptance Criteria

### US-1: Create a Manual CSV FX Series

**Scenario: Happy path creation**
- **Given** I am on the FX Series page at `/fx`
- **When** I click "New FX Series" and fill in name, base currency, quote currency, from_date, source kind = csv_upload
- **Then** the series is created with a slug auto-generated from the name via `Helpers.slugify/1`
- **Then** I see the new series in the list table

**Criteria Checklist:**
- [ ] `slug` is auto-generated at creation, not user-editable, immutable after create
- [ ] `slug` uniqueness is enforced (DB constraint + changeset validation)
- [ ] `base_currency_code != quote_currency_code` validation
- [ ] Currency codes normalized to uppercase 3-letter format
- [ ] `to_date >= from_date` when `to_date` is provided
- [ ] `provider_module` field is nil for `csv_upload` source kind
- [ ] Flash message confirms creation
- [ ] Validation errors shown inline on invalid input

### US-2: Create a Provider-Module FX Series

**Scenario: Happy path creation with provider**
- **Given** I am on the FX Series page at `/fx`
- **When** I click "New FX Series" and fill in name, base currency, quote currency, from_date, source kind = provider_module, provider = bcb_ptax
- **Then** the series is created
- **Then** an initial backfill Oban job is enqueued

**Criteria Checklist:**
- [ ] `provider_module` is required when `source_kind = provider_module`
- [ ] `provider_module` validated against supported providers list from central module/config (initially `bcb_ptax`, `frankfurter_ecb`)
- [ ] UI presents provider options as a select/combo input
- [ ] Initial backfill job is enqueued with range `from_date` to (`to_date` or today)
- [ ] Flash message confirms creation and mentions pending backfill

### US-3: View FX Series List

**Scenario: List with series present**
- **Given** multiple FX series exist in the system
- **When** I navigate to `/fx`
- **Then** I see a table with columns: Name, From, To, Source, Provider, Start Date, End Date, Last Ingested Date, Rows
- **Then** each row has contextual actions

**Criteria Checklist:**
- [ ] "Last Ingested Date" is computed from `max(fx_rate_records.effective_date)` per series (not stored on the series)
- [ ] "Rows" shows the count of `fx_rate_records` for that series
- [ ] Row actions: View, Edit for all series
- [ ] Row action: "Upload CSV" shown only for `csv_upload` series
- [ ] Row action: "Sync Now" shown only for `provider_module` series
- [ ] Top-level "New FX Series" button visible

### US-4: View FX Series Detail

**Scenario: View series with records**
- **Given** an FX series exists with rate records
- **When** I view the series detail
- **Then** I see series metadata (name, slug, description, currencies, dates, source, provider)
- **Then** I see the latest rate records in a simple table (limited count, e.g., last 30)
- **Then** I see Upload action for `csv_upload` series or Sync action for `provider_module` series

**Criteria Checklist:**
- [ ] Rate records table shows: effective_date, rate_value
- [ ] Records are ordered most recent first
- [ ] No complex preview UI or pagination (intentionally minimal)

### US-5: Edit an FX Series

**Scenario: Try to edit identity fields**
- **Given** any FX series exists (with or without records)
- **When** I try to change `base_currency_code`, `quote_currency_code`, `source_kind`, or `provider_module`
- **Then** the change is rejected (identity fields are always immutable)

**Scenario: Edit allowed fields**
- **Given** any FX series exists
- **When** I edit `name`, `description`, `from_date`, `to_date`
- **Then** the changes are saved successfully
- **Then** `slug` remains unchanged (set once at creation, immutable after)

**Criteria Checklist:**
- [ ] Identity fields (`base_currency_code`, `quote_currency_code`, `source_kind`, `provider_module`) are always locked in UI and enforced at changeset level — regardless of whether records exist
- [ ] Wrong identity? Delete the empty series and create a new one
- [ ] `to_date >= from_date` re-validated on edit
- [ ] Flash message confirms update

### US-6: Upload CSV Rates to a Manual Series

**Scenario: Upload with no overlapping dates**
- **Given** a `csv_upload` series exists with some records
- **When** I upload a CSV with new dates only
- **Then** all rows are imported directly
- **Then** the series list updates to reflect the new row count and last ingested date

**Scenario: Upload with overlapping dates**
- **Given** a `csv_upload` series exists with records for dates 2026-01-01 through 2026-01-10
- **When** I upload a CSV containing dates 2026-01-08 through 2026-01-15
- **Then** I see a confirmation dialog stating that overlapping dates exist and will be overridden
- **When** I confirm
- **Then** overlapping rows are upserted, new rows are inserted

**Scenario: Upload with invalid rows**
- **Given** a `csv_upload` series exists
- **When** I upload a CSV where one row has an unparseable date
- **Then** the entire file is rejected
- **Then** I see an error message indicating which row(s) failed validation

**Criteria Checklist:**
- [ ] CSV must have exactly two columns mappable to `date` and `value`
- [ ] Date normalization: multiple common formats accepted, output as `YYYY-MM-DD`
- [ ] Value normalization: string to clean `Decimal`
- [ ] Entire file rejected if any row is invalid (atomic validation)
- [ ] Overlap detection compares uploaded dates against existing `fx_rate_records.effective_date` for the series
- [ ] No full preview UI for overlap; just a confirmation message
- [ ] User can cancel upload on overlap confirmation
- [ ] Upsert on `(fx_series_id, effective_date)` for confirmed overlap
- [ ] Upload action is only available for `csv_upload` source kind
- [ ] Upload is rejected if attempted on a `provider_module` series

### US-7: Trigger Manual Sync for a Provider Series

**Scenario: Manual sync trigger**
- **Given** a `provider_module` series exists
- **When** I click "Sync Now"
- **Then** a sync Oban job is enqueued
- **Then** I see a flash message confirming the sync was enqueued

**Criteria Checklist:**
- [ ] Sync action is only available for `provider_module` series
- [ ] Job computes date range: from `max(existing effective_date) + 1` (or `from_date` if no records) to `to_date` or today
- [ ] Flash message confirms enqueue, not completion

### US-8: Automatic Backfill on Provider Series Creation

**Scenario: Backfill enqueued on create**
- **Given** I create a `provider_module` series with `from_date = 2025-01-01` and `to_date = nil`
- **When** the series is created successfully
- **Then** an Oban job is enqueued to backfill from `2025-01-01` to today

**Criteria Checklist:**
- [ ] Backfill job enqueued in same transaction or immediately after successful insert
- [ ] Backfill range: `from_date` to (`to_date` if set, else `Date.utc_today()`)
- [ ] Job uses the provider module identifier to determine which API to call

### US-9: Daily Global FX Sync

**Scenario: Scheduled sync identifies stale series**
- **Given** three `provider_module` series exist:
  - Series A: last rate record effective_date = yesterday -> not stale
  - Series B: last rate record effective_date = 3 days ago -> stale
  - Series C: no rate records, `from_date` = last week -> stale
- **When** the global sync scheduler runs
- **Then** sync jobs are enqueued for Series B and Series C only

**Criteria Checklist:**
- [ ] Scheduler runs on app start and on a daily cron schedule
- [ ] Scans all `fx_series` where `source_kind = provider_module`
- [ ] Computes `max(fx_rate_records.effective_date)` per series
- [ ] Enqueues sync for series where max effective_date is before yesterday (or has no records)
- [ ] Does not create one recurring job per series; uses global scan approach
- [ ] `csv_upload` series are never synced by the scheduler
- [ ] Series with `to_date` in the past are not synced (already complete)

### US-10: Generate Account Report with Optional FX Conversion

**Scenario: Account report with FX conversion enabled**
- **Given** I have a single account in USD and an FX series for USD/BRL
- **When** I open the account report, select the account, enable the convert toggle, select target currency BRL and the USD/BRL series
- **Then** the report shows the account's native balance and the converted balance
- **Then** the report shows the FX rate date used for the conversion

**Scenario: FX series selection filtering**
- **Given** the selected account is in USD and I select target currency EUR
- **When** I look at the FX series dropdown
- **Then** only series that connect USD and EUR (direct or inverted) are shown
- **Then** only series whose date range covers the `as_of_date` are shown

**Criteria Checklist:**
- [ ] Report is account-scoped: one account, one source currency, one FX series
- [ ] Convert toggle defaults to OFF
- [ ] `target_currency_code` and `fx_series_id` fields only visible when convert is ON
- [ ] FX series dropdown filtered by: connects `account.currency_code` and `target_currency_code` (direct or inverted), `from_date <= as_of_date`, `to_date is nil or >= as_of_date`
- [ ] If selected series does not match filter rules: form is invalid, report blocked
- [ ] Report result includes: native_amount, native_currency, converted_amount, target_currency, fx_series reference, rate_date_used
- [ ] Inverted series: `1 / rate_value` applied at runtime
- [ ] FX conversion is request-time only, not a persisted preference

### US-11: Handle Missing FX Rate Gracefully

**Scenario: No rate in staleness window**
- **Given** FX conversion is enabled with a series that has no rate within 4 days of `as_of_date`
- **When** the report generates
- **Then** native balance is shown normally
- **Then** converted amount shows "unavailable"
- **Then** message displayed: "No FX rate found within 4 days"

**Criteria Checklist:**
- [ ] Lookup strategy: latest `effective_date` on or before `as_of_date`
- [ ] Max staleness: 4 days (`effective_date >= as_of_date - 4`)
- [ ] Report generates successfully even without a valid rate
- [ ] Clear error message shown alongside the unavailable converted value
- [ ] No interpolation or estimation of missing rates

### US-12: Delete an Empty FX Series

**Scenario: Delete series with no records**
- **Given** an FX series with zero rate records
- **When** I click delete and confirm
- **Then** the series is removed

**Scenario: Attempt to delete series with records**
- **Given** an FX series with rate records
- **When** I attempt to delete it
- **Then** the deletion is blocked
- **Then** I see an error message explaining that series with records cannot be deleted

**Criteria Checklist:**
- [ ] Delete action only enabled/shown when series has zero records
- [ ] Backend enforces the rule regardless of UI state
- [ ] Confirmation dialog before deletion
- [ ] Flash error on blocked deletion attempt

---

## Edge Cases

### Empty States

- [ ] No FX series exist -> Show empty state message on `/fx` with CTA to create first series
- [ ] FX series exists but has no rate records -> Show "No rate records yet" in detail view with upload/sync CTA
- [ ] Account report with convert toggle ON but no compatible FX series exist -> Show message in series dropdown: "No compatible series available"

### Error States

- [ ] CSV upload with completely empty file -> Reject with "File is empty" error
- [ ] CSV upload with headers only, no data rows -> Reject with "No data rows found"
- [ ] CSV upload with malformed CSV (unterminated quotes, etc.) -> Reject with parsing error
- [ ] CSV with duplicate dates within the same file -> Reject entire file (same validation as any other invalid row)
- [ ] Provider sync job fails (API down, network error) -> Job retries via Oban max_attempts; series shows stale last_ingested_date
- [ ] Provider sync returns zero rows for the requested range -> No-op, no error; last_ingested_date unchanged
- [ ] Provider returns rates for a different currency pair than the series defines -> Provider module is responsible for correctness; no runtime cross-check in the persistence layer

### Validation Edge Cases

- [ ] Currency code with lowercase input -> Normalize to uppercase before validation
- [ ] `from_date` in the future -> Allow (series can be pre-configured)
- [ ] `to_date` set to today -> Allow (series is complete as of today)
- [ ] `name` that produces duplicate slug -> Slug uniqueness constraint error, displayed to user
- [ ] Two series with same currency pair but different names/providers -> Allowed (N series per pair is by design per `project_context.md`)
- [ ] Editing `name` does NOT regenerate `slug` -> Slug is set once at creation and immutable after
- [ ] `rate_value` must be strictly positive (`rate_value > 0`); zero and negative values are rejected

- [ ] Very large `rate_value` (e.g., 1,000,000) -> Allow (no magnitude validation per spec)

### Concurrent Access

- [ ] Two CSV uploads to same series simultaneously -> Upsert semantics on `(fx_series_id, effective_date)` prevent duplicates; last write wins per date
- [ ] Manual sync triggered while backfill is running -> Oban uniqueness should prevent duplicate jobs or handle overlap gracefully

### Boundary Conditions

- [ ] Maximum series count -> Unlimited (no artificial limit)
- [ ] Maximum rate records per series -> Unlimited; performance relies on DB indexing on `(fx_series_id, effective_date)`
- [ ] `name` field length -> Follow existing pattern: min 2, max 160 characters
- [ ] `description` field length -> Reasonable max (e.g., 500 characters)
- [ ] `slug` field length -> Derived from name; enforce max consistent with name length
- [ ] `rate_value` precision -> Decimal type; at least 10 decimal places for rate accuracy

### FX Conversion Edge Cases

- [ ] Multiple eligible series for the same pair -> User must explicitly choose; no automatic selection
- [ ] Series selected but then `as_of_date` changed to outside series range -> Form becomes invalid; clear error
- [ ] `target_currency_code` == account's `currency_code` -> Form invalid; target currency must differ from native currency

---

## UX States

### FX Series List Page (`/fx`)

| State | Behavior |
|-------|----------|
| **Loading** | Show skeleton/spinner while series list loads |
| **Empty** | Show "No FX series yet" with "New FX Series" CTA button |
| **Populated** | Show table with all series, contextual row actions |
| **Error** | Show error flash if list load fails |

### FX Series Create/Edit Form (modal or inline)

| State | Behavior |
|-------|----------|
| **New** | All fields enabled, source kind selection controls provider visibility |
| **Edit** | Identity fields (`currencies`, `source_kind`, `provider_module`) always locked; only `name`, `description`, `from_date`, `to_date` editable |
| **Validation error** | Inline errors per field, form remains open |
| **Saving** | Submit button disabled/loading |
| **Success** | Flash confirmation, return to list or detail |

### CSV Upload Flow

| State | Behavior |
|-------|----------|
| **File selected** | Show file name, upload button enabled |
| **Validating** | Show processing indicator |
| **Validation failed** | Show error details (which rows, what went wrong), file rejected |
| **No overlap** | Import directly, show success flash with row count |
| **Overlap detected** | Show confirmation dialog: "X dates overlap with existing records. Continue with override?" with Cancel/Continue actions |
| **Import in progress** | Show progress indicator |
| **Import complete** | Flash success with imported/updated row counts |

### Account Report with FX Conversion

| State | Behavior |
|-------|----------|
| **Convert OFF** | Report form shows only account selector and as_of_date |
| **Convert ON** | Additional fields appear: target_currency_code, fx_series_id |
| **No compatible series** | Series dropdown shows "No compatible series" message |
| **Valid configuration** | Report generates with native balance + converted balance for the single account |
| **Rate unavailable** | Report generates, converted value shows "unavailable" with "No FX rate found within 4 days" message |

---

## Out of Scope

Explicitly excluded from this feature:

1. **Automatic provider selection** - User must always explicitly choose which FX series to use for conversion
2. **Global FX defaults/preferences** - No persisted "always convert to X currency" setting
3. **Generalized FX policy engine** - No rules about which series applies to which account automatically
4. **Rate interpolation** - Missing dates within a series are not interpolated; only "latest on or before" lookup
5. **Heuristic validation of rate magnitudes** - No checks for "suspicious" rate values (e.g., USD/BRL = 0.001)
6. **Extra source kinds** - Only `csv_upload` and `provider_module`; no API, no manual entry per record
7. **Advanced FX dashboards** - No charts, trend analysis, or comparison views
8. **Report preview workflows** - No "preview before generating" for converted reports
9. **Delete-and-recreate shortcuts** - Cannot delete a series with records; no bulk-delete-records action
10. **Multi-account FX conversion (e.g., Net Worth with mixed currencies)** - This iteration is account-scoped only; multi-account aggregated reports with FX are a future iteration
11. **Tax event FX snapshots** - Referenced in project context but deferred to a future tax-specific feature
12. **Entity-scoped FX series** - Series are global; entity scoping may come later if needed

---

## Terminology Alignment

| External Spec Term | Codebase Term | Notes |
|---|---|---|
| `Helper.sluglify()` | `AurumFinance.Helpers.slugify/1` | Function exists at `lib/aurum_finance/helpers.ex:39`; external spec had typo "sluglify" |
| "user" | authenticated root user | No roles exist; single-user auth via `AurumFinanceWeb.RootAuth` |
| "provider module" (concept) | Provider behaviour module | Will need a new `AurumFinance.Fx.Provider` behaviour |
| "account report" | Account-scoped report with optional FX | Single-account report; not the multi-account Net Worth report |
| "FX series" entity | `AurumFinance.Fx.FxSeries` | New context `AurumFinance.Fx` following naming convention |
| "FX rate records" entity | `AurumFinance.Fx.FxRateRecord` | Nested under the new `Fx` context |
| "last ingested date" | Computed: `max(fx_rate_records.effective_date)` | Not stored; computed via query as specified |

---

## Involved Roles (Agent Catalog)

The following agents from the catalog should be involved in implementation:

- `tl-architect` - Transform this spec into executable technical plan with tasks and dependencies
- `dev-backend-elixir-engineer` - Implement schemas, contexts, changesets, provider behaviour, CSV import service, background jobs
- `dev-db-performance-architect` - Review migration design, index strategy for rate record lookups
- `dev-frontend-ui-engineer` - Implement FX LiveView pages, CSV upload flow, account report conversion form additions
- `qa-test-scenarios` - Define detailed test scenarios from acceptance criteria
- `qa-elixir-test-author` - Write ExUnit tests for all layers
- `loc-i18n-ptbr-gettext-guardian` - Add Gettext entries to the `fx` domain and `reports` domain for new strings
