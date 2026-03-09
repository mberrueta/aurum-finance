# Task 05: Shared URL Filter Helper — `AurumFinanceWeb.FilterQuery`

## Status
- **Status**: ✅ COMPLETE
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 04
- **Blocks**: Task 06

## Assigned Agent
`dev-backend-elixir-engineer` — Backend engineer for Elixir/Phoenix. Implements shared modules, context utilities, and cross-cutting infrastructure.

## Agent Invocation

```
Act as dev-backend-elixir-engineer following llms/constitution.md.

Execute Task 05 from llms/tasks/013_audit_trail/05_url_filter_helper.md.

Read all inputs listed in the task. Extract the URL filter encoding/decoding
logic from TransactionsLive into a shared helper module. Migrate TransactionsLive
to use it. Do not implement AuditLogLive — that is Task 06.
Do not modify plan.md or any other task files.
```

## Objective

The `?q=key:value&key:value` URL filter pattern is currently implemented inline in `TransactionsLive`. `AuditLogLive` (Task 06) will need the same pattern, and future filtered list views will repeat it again. Extract this into a shared, reusable helper module before the audit LiveView is built, so both views use a consistent, tested implementation.

This task has two deliverables:
1. The shared helper module `AurumFinanceWeb.FilterQuery`
2. Refactored `TransactionsLive` using the helper (behaviour must be identical — no regressions)

---

## Current Pattern to Extract

The following logic is currently inline in `TransactionsLive` and must be moved to the shared helper:

### Encoding (building the URL query string)

```
# Current private functions in TransactionsLive:
defp maybe_add_query_clause(clauses, _key, nil), do: clauses
defp maybe_add_query_clause(clauses, _key, false), do: clauses
defp maybe_add_query_clause(clauses, _key, ""), do: clauses
defp maybe_add_query_clause(clauses, key, value), do: clauses ++ ["#{key}:#{value}"]

defp non_default_filter(value, default) when value == default, do: nil
defp non_default_filter(value, _default), do: value

# Used to build paths like:
# [] -> "/transactions"
# _  -> "/transactions?q=" <> Enum.join(clauses, "&")
```

### Decoding (parsing the URL back into a map)

```
# Current private functions in TransactionsLive:
defp decode_query_clauses(nil), do: %{}
defp decode_query_clauses(query_string) do
  query_string
  |> extract_q_payload()
  |> URI.decode()
  |> String.split("&", trim: true)
  |> Enum.reduce(%{}, fn clause, acc ->
    case String.split(clause, ":", parts: 2) do
      [key, value] when key != "" and value != "" -> Map.put(acc, key, value)
      _parts -> acc
    end
  end)
end

defp extract_q_payload("q=" <> payload), do: payload
defp extract_q_payload(query_string) do
  case URI.decode_query(query_string) do
    %{"q" => payload} -> payload
    _params -> ""
  end
end
```

### URL state parsing entry point

```
# Current in TransactionsLive:
defp parse_state_from_uri(uri) do
  clauses =
    uri
    |> URI.parse()
    |> Map.get(:query)
    |> decode_query_clauses()
  ...
end
```

---

## Inputs Required

- [ ] `lib/aurum_finance_web/live/transactions_live.ex` — source of the pattern to extract
- [ ] `lib/aurum_finance_web/` — understand existing module structure (helpers, components, etc.)
- [ ] `llms/constitution.md` — coding conventions
- [ ] `llms/project_context.md` — module naming conventions

---

## Expected Outputs

### New file: `lib/aurum_finance_web/filter_query.ex`

A pure, stateless module with no LiveView or Phoenix dependencies. Public API:

**`FilterQuery.decode(query_string_or_nil) :: %{String.t() => String.t()}`**
Parses a raw URI query string (from `URI.parse(uri).query`) into a `%{key => value}` map using the `?q=key:value&key:value` encoding. Returns `%{}` for nil or empty input.

**`FilterQuery.encode(clauses :: keyword() | [{String.t(), term()}]) :: String.t() | nil`**
Takes a list of `{key, value}` pairs, drops pairs where value is `nil`, `false`, or `""`, encodes them as `"key:value"` segments, and returns the `?q=...` query string. Returns `nil` (or `""`) if all pairs are dropped, so the caller can build a clean base path.

**`FilterQuery.build_path(base_path, clauses) :: String.t()`**
Convenience function: calls `encode/1` and appends to `base_path`. Returns `base_path` unchanged if no clauses survive filtering.

**`FilterQuery.skip_default(value, default) :: term() | nil`**
Returns `nil` if `value == default`, otherwise returns `value`. Replaces the inline `non_default_filter/2`. Useful for omitting filter values that represent the default state from the URL.

### Updated: `lib/aurum_finance_web/live/transactions_live.ex`

Remove the private functions listed in "Current Pattern to Extract" above. Replace their call sites with calls to `FilterQuery`. Behaviour must be **identical** — no change to URL format, no change to filter parsing logic, no change to visible UI.

### New test file: `test/aurum_finance_web/filter_query_test.exs`

Unit tests for the shared helper covering:
- `decode/1` with nil, empty string, single clause, multiple clauses, malformed input
- `encode/1` with empty list, all-nil values, mixed nil/non-nil, boolean `false`, empty string values
- `build_path/2` with and without surviving clauses
- `skip_default/2` with matching and non-matching values
- Round-trip: `encode → decode` produces the original key/value pairs

---

## Acceptance Criteria

- [ ] `AurumFinanceWeb.FilterQuery` module exists at `lib/aurum_finance_web/filter_query.ex`
- [ ] Module has no LiveView, Phoenix, or Plug dependencies — it is a pure data transformation module
- [ ] `TransactionsLive` no longer contains inline `decode_query_clauses`, `extract_q_payload`, `maybe_add_query_clause`, or `non_default_filter` functions
- [ ] `TransactionsLive` uses `FilterQuery` for all URL encoding/decoding — no duplication
- [ ] Existing `TransactionsLive` behaviour is identical: same URL format, same filter parsing, no visual or functional regression
- [ ] `test/aurum_finance_web/filter_query_test.exs` covers all public functions including edge cases
- [ ] All existing `TransactionsLive` tests continue to pass (no regressions)
- [ ] Module is documented with `@moduledoc` describing its purpose and the `?q=key:value` encoding convention

---

## Technical Notes

### Module placement

`lib/aurum_finance_web/filter_query.ex` — under the web layer, not the core app layer, because this is a URL/HTTP concern. It may be used by any LiveView that implements URL-driven filtered list views.

### Encoding format is fixed

The `key:value` encoding separated by `&` under a single `?q=` parameter is the established convention in this project. Do not change the format — `AuditLogLive` and future views must produce the same URL structure.

### Do not over-generalise

The helper should cover exactly the pattern that exists today, plus a clean public API for `AuditLogLive` to use. Do not add features that aren't needed yet (e.g., typed parsing, nested filters, pagination encoding). Keep it minimal.

### `TransactionsLive` migration is a refactor, not a feature change

The external behaviour of `TransactionsLive` must be identical before and after this task. If existing tests pass and the URL format is unchanged, the migration is correct.

### What AuditLogLive will need (for reference — do NOT implement here)

`AuditLogLive` (Task 06) will call `FilterQuery.decode/1` in `handle_params` and `FilterQuery.build_path/2` when building patch paths. This task just needs to provide that API; Task 06 will use it.

---

## Execution Instructions

### For the Agent

1. Read `lib/aurum_finance_web/live/transactions_live.ex` in full to understand the exact inline pattern
2. Read the existing web layer structure to find the right placement for the new module
3. Create `lib/aurum_finance_web/filter_query.ex` with the public API described above
4. Update `TransactionsLive` to use `FilterQuery` — remove the now-redundant private functions
5. Create `test/aurum_finance_web/filter_query_test.exs` with full unit test coverage
6. Run existing `TransactionsLive` tests mentally or literally to confirm no regressions
7. Document all assumptions in the Execution Summary

### For the Human Reviewer

After the agent completes:

1. Verify `FilterQuery` module has no Phoenix/LiveView/Plug dependencies
2. Verify `TransactionsLive` no longer contains the extracted private functions
3. Verify URL format produced by `TransactionsLive` is unchanged (check `build_path` output)
4. Verify `filter_query_test.exs` covers encode/decode round-trips and edge cases
5. Run the test suite — all `TransactionsLive` tests must pass
6. If approved: mark `[x]` on "Approved" and proceed to Task 06
7. If rejected: add rejection reason and specific feedback

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
- Extracted the compact `?q=key:value&key:value` URL filter encoding/decoding logic from `TransactionsLive` into a shared pure helper module, `AurumFinanceWeb.FilterQuery`
- Implemented `FilterQuery.decode/1`, `FilterQuery.encode/1`, `FilterQuery.build_path/2`, and `FilterQuery.skip_default/2`
- Refactored `TransactionsLive` to use `FilterQuery` for all URL parsing and path construction, removing the inline private helper functions that duplicated this behavior
- Added public docs with usage examples to the important `FilterQuery` functions so the shared helper is self-describing and ready for reuse by `AuditLogLive`
- Added unit coverage for the helper and verified existing `TransactionsLive` behavior still passes

### Outputs Created
- `lib/aurum_finance_web/filter_query.ex`
- `lib/aurum_finance_web/live/transactions_live.ex`
- `test/aurum_finance_web/filter_query_test.exs`

### Assumptions Made
| Assumption | Rationale |
|------------|-----------|
| The existing compact `?q=` format in `TransactionsLive` is the canonical project convention and must remain byte-for-byte compatible | Task 06 will reuse the same encoding pattern for `AuditLogLive`, so changing the format here would create unnecessary downstream churn |
| A pure helper under `AurumFinanceWeb` is the correct boundary for this logic | The concern is URL/query encoding for LiveViews, not core domain behavior |

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|
| Keep `FilterQuery` minimal and string-based | Add typed parsing, pagination helpers, or LiveView-specific wrappers | The task explicitly called for extracting the current pattern without over-generalising |
| Preserve `TransactionsLive` filter parsing behavior exactly and only replace the helper calls | Rework the filter state structure while extracting the code | This task is a refactor prerequisite for Task 06, not a feature redesign |
| Add docs/examples directly on the shared helper's public API | Rely only on tests for discoverability | This helper is intended for reuse across views, so examples reduce future ambiguity |

### Blockers Encountered
- None

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
- [ ] ✅ APPROVED — Proceed to Task 06
- [ ] ❌ REJECTED — See feedback below

### Feedback
[Human's notes, corrections, or rejection reasons]

### Git Operations Performed
```bash
# [Commands human executed]
```
