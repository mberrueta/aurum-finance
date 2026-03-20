# Task 07: Documentation and ADR Sync

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 06
- **Blocks**: Task 08

## Assigned Agent
`docs-feature-documentation-author` - Documentation specialist for feature semantics, roadmap alignment, and user-facing/architecture docs

## Agent Invocation
Invoke the `docs-feature-documentation-author` agent with instructions to read this task file, the approved plan, and the completed implementation/test outputs before updating docs.

## Objective
Update the required architecture, ADR, roadmap, and feature docs so the first real Net Worth read path is documented with the correct V1 boundaries.

## Inputs Required

- [ ] `llms/tasks/021_net_worth_initial_read_experience/plan.md`
- [ ] Approved outputs from Tasks 02-06
- [ ] `docs/adr/0017-reporting-and-read-model-architecture.md`
- [ ] `docs/architecture.md`
- [ ] `docs/roadmap.md`
- [ ] Any existing reporting/product docs chosen for update

## Expected Outputs

- [ ] ADR update for reporting/read-model semantics
- [ ] Architecture doc update
- [ ] Roadmap update
- [ ] Feature/product doc update for Net Worth V1 semantics if needed

## Acceptance Criteria

- [ ] ADR clarifies that Net Worth is the first real production read-path consumer
- [ ] ADR records latest-snapshot-on-or-before semantics and report-specific freshness in V1
- [ ] Architecture doc reflects the real reporting hub and Net Worth page
- [ ] Architecture and/or ADR docs explicitly record any narrow PubSub-based V1 freshness signal as a bounded exception to the default synchronous cross-context communication guidance
- [ ] Roadmap makes clear that this issue delivers the first real Net Worth read path
- [ ] Roadmap makes clear that drilldown remains a planned Reporting M4 follow-up
- [ ] Feature docs explain included account scope, no FX, as-of semantics, coverage states, and freshness meaning

## Technical Notes

### Relevant Code Locations
```text
docs/adr/0017-reporting-and-read-model-architecture.md
docs/architecture.md
docs/roadmap.md
docs/
```

### Constraints
- Keep docs aligned with actual shipped behavior, not aspirational extras
- Do not present drilldown as accidentally missing
- If Task 03 introduces a reporting-specific PubSub freshness signal, document it as a narrow architectural exception rather than a general event-driven direction

## Execution Instructions

### For the Agent
1. Read the implemented behavior, not just the plan.
2. Update docs to match real scope and semantics.
3. Call out any mismatch between docs and implementation explicitly.

### For the Human Reviewer
1. Check that docs reflect the implemented V1 scope precisely.
2. Confirm drilldown and dashboard follow-ups are framed intentionally.
3. Approve before Task 08 begins.

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
### Outputs Created
### Assumptions Made
### Decisions Made
### Blockers Encountered
### Questions for Human
### Ready for Next Task
- [ ] All outputs complete
- [ ] Summary documented
- [ ] Questions listed (if any)

---

## Human Review
*[Filled by human reviewer]*

### Review Date
### Decision
- [ ] APPROVED - Proceed to next task
- [ ] REJECTED - See feedback below

### Feedback
