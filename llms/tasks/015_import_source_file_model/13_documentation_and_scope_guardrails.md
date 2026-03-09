# Task 13: Documentation and Scope Guardrails

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 10, Task 11, Task 12
- **Blocks**: None

## Assigned Agent
`docs-feature-documentation-author` - Feature documentation writer. Creates and updates user-facing documentation aligned with actual application behavior.

## Agent Invocation
Activate `docs-feature-documentation-author` with:

> Act as `docs-feature-documentation-author` following `llms/constitution.md`.
>
> Execute Task 13 from `llms/tasks/015_import_source_file_model/13_documentation_and_scope_guardrails.md`.
>
> Read the milestone plan and all completed task outputs first. Update documentation and task notes so the implemented milestone boundary stays clear and future work is correctly separated.

## Objective
Document the delivered ingestion scope clearly, preserve the CSV-only boundary, and update existing ADRs/docs so they stop describing the old ingestion model. This task must explicitly state that transaction creation/materialization and classification are future work, not part of this milestone.

## Inputs Required

- [ ] `llms/tasks/015_import_source_file_model/plan.md`
- [ ] Tasks 10, 11, and 12 outputs
- [ ] `docs/domain-model.md`
- [ ] `docs/roadmap.md`
- [ ] relevant ADRs/docs that still describe import preview + commit/materialization/classification inside ingestion
- [ ] any docs impacted by the completed work

## Expected Outputs

- [ ] Documentation updates under `llms/` and project docs/ADRs as appropriate
- [ ] Explicit terminology migration from legacy ingestion terms to canonical `imported_files` / `imported_rows` where this milestone supersedes the older wording

## Acceptance Criteria

- [ ] Documentation states imports are account-scoped
- [ ] Documentation states processing is async via background job
- [ ] Documentation states LiveView updates via PubSub
- [ ] Documentation states imported rows are immutable evidence
- [ ] Documentation states transaction creation is out of scope for this milestone
- [ ] Documentation states CSV is the only supported format in this milestone
- [ ] Follow-up work is clearly separated from this milestone
- [ ] ADRs/docs that describe the old `ImportBatch` / `ImportRow` model are updated where this milestone establishes new canonical terminology
- [ ] ADRs/docs no longer describe `commit_import/2` or equivalent ledger-commit behavior as part of this milestone
- [ ] ADRs/docs no longer describe preview classification as part of M2 / this ingestion milestone
- [ ] ADRs/docs clearly state that classification/materialization will be handled in a separate future milestone
- [ ] ADRs/docs clearly state that the output of this milestone is immutable evidence + preview/review data, not ledger facts

## Execution Summary
*[Filled by executing agent]*

## Human Review
*[Filled by human reviewer]*
