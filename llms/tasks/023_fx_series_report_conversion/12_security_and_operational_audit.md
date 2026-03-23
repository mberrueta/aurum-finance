# Task 12: Security and Operational Audit

## Status
- **Status**: BLOCKED
- **Approved**: [ ] Human sign-off
- **Blocked by**: Task 11
- **Blocks**: Task 13

## Assigned Agent
`audit-security` - Security reviewer for authentication, input validation, secrets, and operational risk

## Agent Invocation
Invoke the `audit-security` agent with instructions to read this task file, the approved spec, and the completed implementation/test outputs before auditing the FX feature.

## Objective
Review the implemented FX feature for security and operational risks around file upload/parsing, provider HTTP calls, scheduler/worker behavior, auth boundaries, secrets/configuration, and report-time data exposure.

## Inputs Required

- [ ] `llms/tasks/023_fx_series_report_conversion/plan.md`
- [ ] `llms/tasks/023_fx_series_report_conversion/execution_plan.md`
- [ ] Completed outputs from Tasks 02-11
- [ ] `llms/constitution.md`
- [ ] `llms/project_context.md`
- [ ] Relevant config/runtime changes
- [ ] Test results from `mix test`
- [ ] Output from `mix precommit`

## Expected Outputs

- [ ] Written audit findings organized by severity
- [ ] Specific feedback on upload, provider, scheduling, and reporting risks
- [ ] Confirmation of secrets/config/env handling

## Acceptance Criteria

- [ ] Reviews file-upload validation and malformed-input handling
- [ ] Reviews provider HTTP usage, retries, and secret sourcing from env/runtime config
- [ ] Reviews worker uniqueness/overlap behavior and scheduler safety
- [ ] Reviews authenticated-route boundaries for `/fx` and the account report
- [ ] Reviews report conversion behavior for data leakage or ambiguous error handling
- [ ] Produces a clear pass/fail recommendation with actionable findings

## Technical Notes

### Focus Areas
1. CSV upload validation and failure handling
2. Provider credentials/env vars and outbound HTTP posture
3. Oban scheduler/worker overlap and retry behavior
4. Authenticated access boundaries and any implicit account/entity leakage
5. Reporting output semantics when conversion is unavailable or invalid

## Execution Instructions

### For the Agent
1. Review completed implementation and quality-gate outputs.
2. Classify findings by severity and keep recommendations concrete.
3. Call out any required follow-up work before final PR review.

### For the Human Reviewer
1. Review the findings and decide whether follow-up tasks are required.
2. Approve before Task 13 begins if no blocking issues remain.

---

## Execution Summary
*[Filled by executing agent after completion]*

## Human Review
*[Filled by human reviewer]*

