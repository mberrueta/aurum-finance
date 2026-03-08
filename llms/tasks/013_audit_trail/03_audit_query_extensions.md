# Task 03: Audit Query Extensions — Date-Range Filters, Offset Pagination, and Distinct Entity Types

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 02
- **Blocks**: Task 04, Task 05

## Assigned Agent
`dev-backend-elixir-engineer` - Senior backend engineer for Elixir/Phoenix. Implements schemas, contexts, queries, background jobs, observability, and performance optimizations.

## Agent Invocation
```
Act as a Senior Backend Elixir Engineer following llms/constitution.md.

Read and implement Task 03 from llms/tasks/013_audit_trail/03_audit_query_extensions.md

Before starting, read:
- llms/constitution.md
- llms/project_context.md
- llms/tasks/013_audit_trail/plan.md (spec sections: "API / Context Design" -> "list_audit_events/1")
- This task file in full
```

## Objective
Extend `Audit.list_audit_events/1` with date-range filtering (`:occurred_after`, `:occurred_before`) and offset-based pagination (`:offset`). Add a new `Audit.distinct_entity_types/0` function that returns the set of distinct `entity_type` values from the database for the UI filter dropdown. Corresponds to plan tasks 7-8.

## Inputs Required

- [ ] `llms/tasks/013_audit_trail/plan.md` - Filter specifications in "API / Context Design" section
- [ ] `lib/aurum_finance/audit.ex` - Current `list_audit_events/1` and `filter_query/2` implementation (lines 145-331 after Task 02 modifications)
- [ ] `llms/constitution.md` - Context API conventions: `filter_query/2` multi-clause pattern matching

## Expected Outputs

- [ ] **Extended `filter_query/2`** in `lib/aurum_finance/audit.ex` with three new clauses:
  1. `{:occurred_after, %DateTime{}}` - `where(audit_event.occurred_at >= ^value)`
  2. `{:occurred_before, %DateTime{}}` - `where(audit_event.occurred_at <= ^value)`
  3. `{:offset, non_neg_integer()}` - applied as `offset(^value)` on the query (handled outside `filter_query` since offset is not a WHERE clause)

- [ ] **`Audit.distinct_entity_types/0`** function that returns `[String.t()]` -- a sorted list of distinct `entity_type` values from `audit_events`

- [ ] **Updated `@type list_opt`** typespec to include the new filter keys

## Acceptance Criteria

- [ ] `list_audit_events(occurred_after: datetime)` returns only events with `occurred_at >= datetime`
- [ ] `list_audit_events(occurred_before: datetime)` returns only events with `occurred_at <= datetime`
- [ ] Both date filters can be combined for a date range
- [ ] `list_audit_events(offset: n)` skips the first `n` results
- [ ] `offset` works correctly with `limit` for pagination (offset + limit)
- [ ] `distinct_entity_types/0` returns a sorted list of unique `entity_type` strings from the database
- [ ] `distinct_entity_types/0` returns `[]` when no audit events exist
- [ ] Existing filter behavior is preserved (entity_type, entity_id, channel, action, limit)
- [ ] Unknown filter keys continue to be silently ignored (existing behavior)
- [ ] `mix precommit` passes

## Technical Notes

### Relevant Code Locations
```
lib/aurum_finance/audit.ex    # list_audit_events/1, filter_query/2, @type list_opt
```

### Patterns to Follow
- Follow the existing `filter_query/2` multi-clause pattern matching (lines 299-331 of current `audit.ex`)
- The `:offset` filter is slightly different from WHERE clauses -- it should be applied to the query after filtering, similar to how `:limit` is handled (extracted from opts and applied separately, not inside `filter_query/2`)
- `distinct_entity_types/0` should use a simple `from ae in AuditEvent, distinct: true, select: ae.entity_type, order_by: ae.entity_type` query

### Implementation Notes for Offset
The current `list_audit_events/1` extracts `:limit` from opts and applies it directly (line 146-152). The `:offset` should follow the same pattern:

```elixir
def list_audit_events(opts \\ []) do
  limit = Keyword.get(opts, :limit, 100)
  offset = Keyword.get(opts, :offset, 0)

  AuditEvent
  |> filter_query(opts)
  |> order_by([audit_event], desc: audit_event.occurred_at)
  |> limit(^limit)
  |> offset(^offset)
  |> Repo.all()
end
```

The `filter_query/2` clause for `:offset` should simply skip it (like `:limit` does currently on line 325-327).

### Constraints
- Date comparisons use `>=` and `<=` (inclusive on both ends) as specified in the plan
- The `offset` value must be a non-negative integer; negative values should be treated as 0 or ignored
- No new indexes are needed -- `occurred_at` is already indexed

## Execution Instructions

### For the Agent
1. Read all inputs listed above
2. Add the three new `filter_query/2` clauses for `:occurred_after`, `:occurred_before`, and `:offset`
3. Update `list_audit_events/1` to extract and apply `:offset` alongside `:limit`
4. Implement `distinct_entity_types/0`
5. Update the `@type list_opt` typespec
6. Run `mix test` to verify no regressions
7. Run `mix precommit`
8. Document all assumptions in "Execution Summary"

### For the Human Reviewer
After agent completes:
1. Verify date filter clauses use correct comparison operators (`>=`, `<=`)
2. Verify offset is applied correctly in the query pipeline
3. Verify `distinct_entity_types/0` returns sorted results
4. Confirm existing filter tests still pass
5. If approved: mark `[x]` on "Approved" and update plan.md status
6. If rejected: add rejection reason and specific feedback

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
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
[Human's notes, corrections, or rejection reasons]

### Git Operations Performed
```bash
# [Commands human executed]
```
