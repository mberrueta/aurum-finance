# Task 13: ADR and System Documentation Update for Assisted Matching

## Status
- **Status**: PENDING
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 10, Task 11
- **Blocks**: None

## Assigned Agent
`tl-architect` - Technical lead architect for architectural decision capture, system-level consistency, and implementation alignment

## Agent Invocation
```text
Act as tl-architect following llms/constitution.md.

Execute Task 13 from llms/tasks/018_reconciliation_status/13_match_candidates_docs.md

Read these files before starting:
- llms/constitution.md
- llms/tasks/018_reconciliation_status/plan.md
- docs/adr/0013-reconciliation-workflow-model.md
- docs/architecture.md
- docs/domain-model.md
- Task 10 output
- Task 11 output
```

## Objective
Update the architectural record and system documentation so the codebase clearly states that reconciliation now includes explainable candidate matching for operator assistance, while automatic reconciliation remains deferred.

## Inputs Required

- [ ] Task 10 output - actual backend candidate model and API shape
- [ ] Task 11 output - actual UX pattern for candidate inspection
- [ ] Existing reconciliation ADR and core system docs

## Expected Outputs

- [ ] One ADR update path chosen and implemented:
  - amend `docs/adr/0013-reconciliation-workflow-model.md`, or
  - add a new ADR that refines the assisted-matching implementation strategy
- [ ] `docs/architecture.md` updated
- [ ] `docs/domain-model.md` updated
- [ ] Optional roadmap/docs references updated if the agent judges them materially affected

## Acceptance Criteria

- [ ] Documentation explicitly distinguishes:
  - candidate matching assistance
  - manual clear/reconcile workflow
  - future auto-reconciliation
- [ ] ADR text matches the implemented system, not the aspirational end-state only
- [ ] Docs explain that score output is explainable and based on weighted signals
- [ ] Docs use neutral terminology for heuristic strength and avoid overstating certainty
- [ ] Docs state the public score contract clearly as a normalized heuristic in the range `0.0..1.0`
- [ ] Docs state that scoring may classify more broadly, while the default public API/UI only surface useful above-threshold candidates unless explicitly configured otherwise
- [ ] Docs explain that viewing candidates does not mutate ledger or reconciliation state
- [ ] Architecture doc reflects where candidate scoring lives and which contexts it depends on
- [ ] Domain model doc reflects the current implementation posture accurately
- [ ] Any deferred parts are clearly marked as future work, not implied as already delivered

## Technical Notes

### Documentation Decision

The agent must choose one of these and justify it:

1. **Amend ADR 0013**
   - Best if the new implementation is a clarification of the already accepted direction.

2. **Add a new ADR**
   - Best if this introduces a distinct implementation decision such as:
     - runtime candidate scoring before persistent `MatchResult` storage,
     - explainable scoring contract,
     - assist-only UX before auto-apply.

### Required Themes

- Explainable score breakdown
- Entity/account-scoped evidence loading
- Read-only candidate inspection
- Reuse path toward future auto-suggest / auto-rec

### Constraints

- Do not describe auto-rec as implemented if it is still deferred
- Keep terminology aligned with the code and UI shipped in Tasks 10 and 11
- Preserve consistency with ADR-0008, ADR-0010, and ADR-0013

## Execution Instructions

### For the Agent
1. Compare the implemented backend/frontend behavior against ADR 0013
2. Decide whether to amend or extend the ADR set
3. Update architecture and domain docs to match reality
4. Call out what is implemented now versus deferred
5. Document the rationale in the Execution Summary

### For the Human Reviewer
1. Verify the docs are honest about current capability
2. Verify future auto-rec remains explicitly deferred
3. Verify the docs explain how the scoring model can evolve without locking in unsafe automation
4. Verify terminology matches the shipped UI and backend API

---

## Execution Summary
*[Filled by executing agent after completion]*

### Work Performed
### Outputs Created
### Assumptions Made
| Assumption | Rationale |
|------------|-----------|

### Decisions Made
| Decision | Alternatives Considered | Rationale |
|----------|------------------------|-----------|

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
- [ ] APPROVED - Documentation complete
- [ ] REJECTED - See feedback below

### Feedback
