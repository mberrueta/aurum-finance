# Execution Plan: Net Worth Initial Read Experience

## Metadata
- **Spec**: `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- **Created**: 2026-03-20
- **Status**: PLANNING
- **Current Task**: N/A

## Overview

This execution plan turns the approved Net Worth Initial Read Experience plan into a sequential implementation path that keeps scope narrow and product-real. It delivers one real reporting hub, one real Net Worth read path, the required freshness and coverage semantics, deterministic tests, documentation updates, and final review gates for security, performance, N+1, unused code, and PR readiness.

## Technical Summary

### Codebase Impact
- **New files**: ~4-8
- **Modified files**: ~8-14
- **Database migrations**: No new migration expected
- **External dependencies**: None

### Risk Assessment

| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Latest-snapshot-per-account query becomes slow or hard to reason about | Medium | High | Start with a query/performance contract review and keep selection logic isolated in the reporting read model |
| Freshness semantics drift from the agreed as-of rules | Medium | High | Implement report-shaped backend contract first, then add explicit freshness/coverage tests before UI polish |
| UI leaks mock/dashboard semantics back into `/reports` | Medium | Medium | Separate hub and detail page tasks, with the hub task explicitly removing mock surfaces |
| Live freshness updates become hand-wavy or degrade to reload-only UX | Medium | Medium | Add a dedicated refresh-signal task with PubSub-preferred semantics before final UI closure |
| Liability display transforms become inconsistent across rows and summaries | Medium | Medium | Lock presentation semantics in backend contract and verify via QA and PR review |
| N+1 queries or over-fetching slip into LiveView rendering | Medium | High | Require final PR audit to review query count, preloading, and repeated report calls |

## Roles

### Human Reviewer
- Approves each task before the next begins
- Executes all git operations (add, commit, push, checkout, stash, revert)
- Final sign-off on completed work
- Can reject or request changes on any task

### Executing Agents

| Task | Agent | Description |
|------|-------|-------------|
| 01 | `dev-db-performance-architect` | Read-model query shape, index usage, and performance constraints |
| 02 | `dev-backend-elixir-engineer` | Net Worth backend read model and freshness contract |
| 03 | `dev-backend-elixir-engineer` | Global reporting refresh API and live freshness signal wiring |
| 04 | `dev-frontend-ui-engineer` | `/reports` hub refactor |
| 05 | `dev-frontend-ui-engineer` | `/reports/net-worth` LiveView and page UX |
| 06 | `qa-elixir-test-author` | Backend and LiveView test coverage |
| 07 | `docs-feature-documentation-author` | Docs, ADR, and roadmap sync |
| 08 | `audit-security` | Security and privacy review |
| 09 | `audit-pr-elixir` | Final PR review for correctness, performance, N+1, unused code, and coverage |

## Task Sequence

| # | Task | Status | Approved | Dependencies |
|---|------|--------|----------|--------------|
| 01 | Net Worth query and performance contract | PENDING | [ ] | None |
| 02 | Net Worth backend read model | BLOCKED | [ ] | Task 01 |
| 03 | Reporting refresh API and live freshness signal | BLOCKED | [ ] | Task 02 |
| 04 | Reports hub refactor | BLOCKED | [ ] | Task 03 |
| 05 | Net Worth page LiveView | BLOCKED | [ ] | Task 04 |
| 06 | Test coverage and regression suite | BLOCKED | [ ] | Task 05 |
| 07 | Documentation and ADR sync | BLOCKED | [ ] | Task 06 |
| 08 | Security and privacy audit | BLOCKED | [ ] | Task 07 |
| 09 | Final PR review and quality gate | BLOCKED | [ ] | Task 08 |

**Status Legend:**
- `PENDING` - Ready to start
- `IN_PROGRESS` - Currently being executed
- `COMPLETED` - Done and approved
- `BLOCKED` - Waiting on dependency
- `REJECTED` - Needs rework
- `ON_HOLD` - Paused by human

## Assumptions

1. The approved `plan.md` in this folder is the authoritative scope document for implementation.
2. No new persistence layer beyond `daily_balance_snapshots` is required for V1 Net Worth.
3. The current business date product default is implemented with `Date.utc_today()` in V1.
4. Existing snapshot refresh infrastructure is sufficient for the first global reporting refresh action, even if the global API initially targets only the currently relevant projection family.
5. If implemented, live freshness signaling will use a narrow reporting-specific PubSub path documented as a bounded architectural exception rather than a general eventing direction.
6. Live freshness updates should be supported in V1 without introducing job-progress UI.
7. Cross-entity output may be supported if it falls out naturally from current scoped access, but no new entity-selection workflow is part of this issue.

## Open Questions

1. None currently blocking Task 01.
2. During Task 01, if the existing snapshot indexes are insufficient for the agreed latest-row query and freshness evaluation, the human reviewer must decide whether that warrants a follow-up issue or a narrow in-scope optimization.

## Change Log

| Date | Task | Change | Reason |
|------|------|--------|--------|
| 2026-03-20 | Plan | Initial execution plan created | Translate approved Net Worth plan into sequential technical tasks |
| 2026-03-20 | Plan | Refined task expectations for bounded PubSub freshness signaling, entity metadata, and explicit empty-state coverage | Keep execution artifacts aligned with the clarified implementation boundaries and review expectations |
