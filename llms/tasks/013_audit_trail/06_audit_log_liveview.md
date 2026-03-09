# Task 06: Audit Log LiveView — Route, Sidebar, Filters, Event List, Pagination, Gettext

## Status
- **Status**: ✅ COMPLETE
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 04, Task 05
- **Blocks**: Task 07

## Assigned Agent
`dev-frontend-ui-engineer` - Frontend engineer for Phoenix LiveView. Implements UI components, Tailwind styling, LiveView hooks, and responsive accessible interfaces.

## Agent Invocation
```
Act as a Frontend UI Engineer following llms/constitution.md.

Read and implement Task 06 from llms/tasks/013_audit_trail/06_audit_log_liveview.md

Before starting, read:
- llms/constitution.md
- llms/project_context.md
- llms/tasks/013_audit_trail/plan.md (full spec — especially "Query / Viewer Requirements" and "UX States" sections)
- This task file in full
```

## Objective
Build the complete Audit Log viewer UI: a dedicated `AuditLogLive` LiveView at `/audit-log` with URL-driven filters, an event list with expandable rows showing before/after snapshots, offset-based pagination, sidebar navigation entry, and full gettext internationalization. The viewer is for operational/admin/manual events, not a raw ledger-insert firehose. This corresponds to plan tasks 10-16.

## Inputs Required

- [ ] `llms/tasks/013_audit_trail/plan.md` - UI requirements in "Query / Viewer Requirements" and "UX States" sections
- [ ] `lib/aurum_finance_web/live/transactions_live.ex` - **Reference pattern** for URL-driven filters, `handle_params`, `push_patch`, query-string encoding, date preset buttons
- [ ] `lib/aurum_finance_web/router.ex` - Current route structure (line 37-51: `:app` live session)
- [ ] `lib/aurum_finance_web/components/layouts.ex` - Sidebar navigation (`nav_items/0` at line 137-153)
- [ ] `lib/aurum_finance/audit.ex` - `list_audit_events/1` (with filters from Task 03), `distinct_entity_types/0`
- [ ] `llms/constitution.md` - HEEx templating rules (`{}` interpolation, `:if`/`:for` attributes, no `<% %>`)

## Expected Outputs

### New Files
- [ ] `lib/aurum_finance_web/live/audit_log_live.ex` - LiveView module with mount, handle_params, handle_event, render, and HEEx template (inline or separate `.html.heex`)

### Modified Files
- [ ] `lib/aurum_finance_web/router.ex` - Add `live "/audit-log", AuditLogLive, :index` inside the `:app` live session
- [ ] `lib/aurum_finance_web/components/layouts.ex` - Add `:audit_log` entry to `nav_items/0`
- [ ] Gettext `.pot`/`.po` files - New entries for audit log UI strings

## Acceptance Criteria

### Route and Navigation
- [ ] `/audit-log` is accessible to authenticated root users
- [ ] `/audit-log` renders the `AuditLogLive` view inside the `:app` live session layout
- [ ] Sidebar shows "Audit Log" navigation item with an appropriate icon
- [ ] The `active_nav: :audit_log` assign highlights the correct sidebar item

### Filter Form
- [ ] Entity type dropdown populated dynamically from `Audit.distinct_entity_types/0`
- [ ] "All" is the default option for entity type dropdown
- [ ] Action dropdown with options: "All", "created", "updated", "archived", "unarchived", "voided"
- [ ] Channel dropdown with options: "All", "web", "system", "mcp", "ai_assistant"
- [ ] Optional Entity ID text input for filtering by a specific record UUID
- [ ] Date preset buttons: "Today", "This week", "This month", "All" (following `TransactionsLive` pattern)
- [ ] All filter changes update the URL via `push_patch` (URL-driven state)
- [ ] Filters are hydrated from the URL on mount/handle_params (bookmarkable)

### Event List
- [ ] Displays events ordered by `occurred_at` descending
- [ ] Each row shows: formatted `occurred_at`, `entity_type`, `action`, `actor`, `channel`
- [ ] Empty/help text and page framing make it clear this is an operational audit log, not an every-transaction ledger feed
- [ ] Clicking a row expands it to show `before` and `after` snapshots as formatted JSON
- [ ] Clicking an expanded row collapses it
- [ ] No edit, delete, replay, or any write-action buttons anywhere in the view
- [ ] Strictly read-only interface

### Pagination
- [ ] Default page size of 50 events
- [ ] Prev/Next pagination controls (or "Load more" button)
- [ ] Pagination state reflected in URL (via offset or page parameter)
- [ ] Prev button disabled on first page
- [ ] Next button disabled when fewer results than page size are returned

### Empty States
- [ ] No events at all: "No audit events recorded yet." (no CTA)
- [ ] Filters return no results: "No events match the selected filters." with a clear-filters link

### Gettext
- [ ] All user-visible strings use `dgettext("audit_log", "key")`
- [ ] Gettext domain: `"audit_log"`
- [ ] Keys follow snake_case convention: `page_title`, `filter_entity_type`, `filter_action`, `filter_channel`, `filter_entity_id`, `filter_date_*`, `column_occurred_at`, `column_entity_type`, `column_action`, `column_actor`, `column_channel`, `empty_state`, `empty_state_filtered`, `clear_filters`, `pagination_prev`, `pagination_next`, `snapshot_before`, `snapshot_after`

### General
- [ ] HEEx template uses `{}` interpolation (not `<%= %>`)
- [ ] HEEx template uses `:if` and `:for` attributes (not `<% if %>` blocks)
- [ ] Tailwind classes follow existing app styling conventions
- [ ] `mix precommit` passes

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance_web/live/transactions_live.ex       # URL-driven filter reference pattern
lib/aurum_finance_web/components/layouts.ex            # nav_items/0 for sidebar
lib/aurum_finance_web/router.ex                        # Route registration
lib/aurum_finance/audit.ex                             # list_audit_events/1, distinct_entity_types/0
priv/gettext/                                          # Gettext files
```

### URL-Driven Filter Pattern (from TransactionsLive)

Follow the compact query-string pattern used by `TransactionsLive`:
- URL format: `/audit-log?q=type:account&action:created&channel:web&date:this_month`
- `mount/3` sets default assigns
- `handle_params/3` parses the URI, extracts filter state, loads data
- Filter changes emit `push_patch` to update the URL
- Date presets emit `push_patch` via a `set_date_preset` event

Key functions to replicate from TransactionsLive:
- `parse_state_from_uri/1` - Extract filter values from query string
- `assign_filters/2` - Set filter assigns and form
- `normalize_date_filters/1` - Resolve date presets to date ranges
- `audit_log_path/1` - Build the compact query string URL

### Sidebar Navigation Entry

Add to `nav_items/0` in `layouts.ex` after the `:settings` entry:

```elixir
{:audit_log, dgettext("layout", "nav_audit_log"), "hero-clipboard-document-list-mini", ~p"/audit-log"}
```

### JSON Snapshot Display

For the expandable before/after snapshots, use `Jason.encode!(snapshot, pretty: true)` and render in a `<pre><code>` block. If the snapshot is `nil`, show a dash or "N/A".

### Pagination Strategy

Use offset-based pagination with a `page` parameter in the URL:
- Page 1 = offset 0, Page 2 = offset 50, etc.
- Pass `offset: (page - 1) * page_size` and `limit: page_size` to `list_audit_events/1`
- Determine if there is a next page by requesting `page_size + 1` results and checking if the extra result exists

### Filter-to-Query Mapping

| URL param | Audit filter key | Type |
|-----------|-----------------|------|
| `type` | `:entity_type` | String |
| `action` | `:action` | String |
| `channel` | `:channel` | Atom (parsed from string) |
| `entity` | `:entity_id` | String (UUID) |
| `date` | Date preset -> `:occurred_after` / `:occurred_before` | DateTime |
| `page` | `:offset` (computed from page number) | Integer |

### Constraints
- No LiveView components in subdirectories -- use a flat module `AuditLogLive` (convention from plan)
- The view is strictly read-only. No `phx-submit`, no mutation events, no forms that write data.
- All data loading goes through the `Audit` context -- no direct Repo calls from the LiveView
- The inline HEEx template is preferred (single-file LiveView) unless the template is very large, in which case a separate `.html.heex` file is acceptable

### Design Decision References
- Plan section "Query / Viewer Requirements" for complete filter and display specifications
- Plan section "UX States" for empty/loading/error states
- Plan decision: dedicated `/audit-log` route, not nested under settings

## Execution Instructions

### For the Agent
1. Read ALL inputs listed above thoroughly
2. Create `lib/aurum_finance_web/live/audit_log_live.ex` with:
   - `mount/3`: set default assigns (active_nav, page_title, empty filters)
   - `handle_params/3`: parse URI, load audit events
   - `handle_event/3`: filter changes, date presets, row expansion, pagination
   - `render/1`: HEEx template with filter form, event list, pagination, empty states
3. Add the route to `router.ex` inside the `:app` live session
4. Add the sidebar entry to `layouts.ex` in `nav_items/0`
5. Add gettext entries (run `mix gettext.extract` after adding dgettext calls)
6. Add the `nav_audit_log` gettext entry to the `"layout"` domain
7. Test manually if possible, or verify compilation
8. Run `mix precommit`
9. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Navigate to `/audit-log` and verify the page loads
2. Test each filter (entity type, action, channel, entity ID, date presets)
3. Verify URL updates on filter changes (bookmarkable)
4. Verify expandable row behavior (click to expand/collapse)
5. Verify pagination (prev/next, disabled states)
6. Verify empty states (no events, no matching events)
7. Verify sidebar navigation highlights correctly
8. Confirm no write actions exist in the template
9. Check HEEx conventions (`{}` interpolation, `:if`/`:for` attributes)
10. If approved: mark `[x]` on "Approved" and update plan.md status
11. If rejected: add rejection reason and specific feedback

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- Implemented `AurumFinanceWeb.AuditLogLive` with URL-driven filters, date presets, expandable event rows, and offset-based pagination using the shared `FilterQuery` helper
- Added the `/audit-log` route under the authenticated `:app` live session and wired the sidebar navigation entry with `active_nav: :audit_log`
- Built the LiveView template with a read-only operational audit framing, dynamic entity type filter options from `Audit.distinct_entity_types/0`, static action/channel filters, entity ID filtering, empty states, and JSON before/after snapshot expansion
- Added gettext coverage for the new `audit_log` domain plus the `layout` navigation label for the sidebar entry
- Added a minimal LiveView regression suite covering mount, filtering, expansion, empty filtered state, and read-only behavior, then ran the full repo gates

### Outputs Created
- `lib/aurum_finance_web/live/audit_log_live.ex`
- `lib/aurum_finance_web/live/audit_log_live.html.heex`
- `lib/aurum_finance_web/router.ex`
- `lib/aurum_finance_web/components/layouts.ex`
- `priv/gettext/audit_log.pot`
- `priv/gettext/en/LC_MESSAGES/audit_log.po`
- `priv/gettext/layout.pot`
- `priv/gettext/en/LC_MESSAGES/layout.po`
- `test/aurum_finance_web/live/audit_log_live_test.exs`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| The existing compact `?q=key:value&key:value` filter format should be reused unchanged for the audit viewer | Task 05 established this as the shared URL convention and the task explicitly references `TransactionsLive` as the pattern to follow |
| Invalid `entity_id`, `channel`, and `page` query values should be ignored rather than raising errors | The audit viewer should remain bookmarkable and resilient to malformed URLs in a single-user operational UI |
| A minimal initial LiveView test suite is appropriate even though Task 07 will deepen coverage | The constitution requires tests for executable logic, and Task 07 can expand from this baseline instead of starting from zero |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Used a separate `.html.heex` template instead of a single-file inline render | Inline `~H` render in `audit_log_live.ex` | The page has enough structure that the separate template is easier to review and maintain |
| Implemented simple prev/next pagination with a `page` URL clause and `limit + 1` lookahead | Load-more UI or total-count pagination | This satisfies the spec with minimal extra state and no count query |
| Framed the page explicitly as an operational audit log with no write controls | A more generic event feed presentation | The narrowed v1 audit scope needs to be visible in the UI so it is not interpreted as a ledger insert firehose |

### Blockers Encountered
- Gettext does not allow dynamic `dgettext/2` keys. Resolution: replaced interpolated action/channel translation lookups with explicit helper functions for each supported value.

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
