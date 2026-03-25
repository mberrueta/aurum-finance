# Task 05 — FX LiveView: CRUD and Detail UI

## Status
- **Status**: COMPLETE
- **Approved**: [X] Human sign-off

## Scope

Replace the mock `FxLive` with a real implementation that calls the `AurumFinance.Fx` context API.

Route: `/fx` (unchanged — `FxLive, :index`).

## What was built

### List view (`/fx`)
- Table with columns: Name, Pair, Source, Provider, From, To, Last Ingested, Rows
- Row actions: View (navigates to detail), Edit (opens sidebar form), Delete (only when `row_count == 0`)
- Delete requires confirmation via inline modal (`id="fx-delete-confirm"`)
- Blocked with flash error if backend returns `{:error, :has_records}`
- "New FX Series" button at top
- Empty state with "New FX Series" CTA

### Create/Edit form (right sidebar panel)
- Create: all fields enabled — name, description, base_currency_code, quote_currency_code, from_date, to_date (optional), source_kind (select), provider_module (select, only shown when source_kind = provider_module)
- Edit: identity fields (base_currency_code, quote_currency_code, source_kind, provider_module) shown as read-only text; only name, description, from_date, to_date are editable
- Inline validation errors per field
- Submit button disabled while `@saving` is true

### Detail view
- Shows series metadata in a card: name, slug, description, currencies, dates, source, provider
- Rate records table: effective_date + rate_value, last 30 records, most recent first
- "No rate records yet" empty state with action hint (Upload CSV / Sync Now depending on source_kind)
- Back to list link

## Execution Summary

### Work Performed

1. **Created** `lib/aurum_finance/fx/fx_series.ex` — FxSeries schema with `changeset/2`, `update_changeset/2`, `source_kinds/0`, and `supported_providers/0`.
2. **Created** `lib/aurum_finance/fx/fx_rate_record.ex` — FxRateRecord schema stub.
3. **Created** `lib/aurum_finance/fx.ex` — Fx context with `list_fx_series/0`, `get_fx_series!/1`, `change_fx_series/2`, `change_fx_series_update/2`, `create_fx_series/1`, `update_fx_series/2`, `delete_fx_series/1`, `list_fx_rate_records/2`.
4. **Replaced** `lib/aurum_finance_web/live/fx_live.ex` — full LiveView with list/detail states, create/edit/delete event handlers.
5. **Created** `lib/aurum_finance_web/live/fx_live.html.heex` — HEEX template with list view, detail view, right-sidebar form, and delete confirmation modal.
6. **Updated** `priv/gettext/en/LC_MESSAGES/fx.po` — all new translation keys for this feature.
7. **Created** `llms/tasks/023_fx_series_report_conversion/` directory.

### Files Created/Modified

| File | Action | Notes |
|------|--------|-------|
| `lib/aurum_finance/fx/fx_series.ex` | Created | Schema + changesets + source_kinds/0 + supported_providers/0 |
| `lib/aurum_finance/fx/fx_rate_record.ex` | Created | Schema stub |
| `lib/aurum_finance/fx.ex` | Created | Context public API |
| `lib/aurum_finance_web/live/fx_live.ex` | Replaced | Full LiveView |
| `lib/aurum_finance_web/live/fx_live.html.heex` | Created | HEEX template |
| `priv/gettext/en/LC_MESSAGES/fx.po` | Updated | All new msgid keys |

### Stable DOM IDs

| ID | Element |
|----|---------|
| `fx-page` | Root div |
| `fx-series-list` | Table wrapper in list view |
| `fx-series-row-{id}` | Per-row `<tr>` |
| `fx-series-detail` | Detail view wrapper |
| `fx-series-form` | Right sidebar panel (via `panel_id`) |
| `fx-series-form-inner` | `<.form>` element |
| `fx-delete-confirm` | Delete confirmation dialog |
| `fx-new-series-btn` | New series button |
| `fx-view-btn-{id}` | View button per row |
| `fx-edit-btn-{id}` | Edit button per row |
| `fx-delete-btn-{id}` | Delete button per row |
| `fx-delete-confirm-btn` | Confirm delete button |
| `fx-delete-cancel-btn` | Cancel delete button |
| `fx-save-btn` | Form submit button |
| `fx-cancel-form-btn` | Form cancel button |

### What is NOT done in this task (deferred to later tasks)

- CSV upload wiring (Task 06)
- Provider sync wiring (Task 06)
- Account report FX conversion form (Task 08)
- Tests (separate QA task)
- `pt-BR` translations (separate i18n task)
- Migrations for `fx_series` and `fx_rate_records` tables (Task 02 backend)

### Notes

- The Fx context and FxSeries/FxRateRecord schemas were created as part of this task since Task 02 (backend) had not yet been executed on this branch. The schema definitions here should be reconciled with Task 02's output when that task runs. They serve as a working stub that satisfies the LiveView's compilation requirements.
- `FxSeries.update_changeset/2` locks identity fields (currencies, source_kind, provider_module) — only name, description, from_date, to_date are editable.
- `Fx.delete_fx_series/1` checks row count before deleting and returns `{:error, :has_records}` if records exist.
- `form_source_kind/1` private helper reads the form field value to conditionally show the provider_module select.

### Compile verification

`mix compile --warnings-as-errors` passes with zero warnings from `aurum_finance` app code.

### Accessibility Verified

- [x] All form inputs have associated labels
- [x] Delete confirmation uses `role="dialog"`, `aria-modal="true"`, `aria-labelledby`
- [x] Screen-reader-only text for "Actions" column header
- [x] Empty states have descriptive text

### Closure Note

- Task 05 is closed and superseded by Task 06 for interaction wiring.
- Upload and sync interaction states are now handled in the real UI flow.
