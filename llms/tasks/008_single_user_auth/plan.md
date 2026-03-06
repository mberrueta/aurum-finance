# Execution Plan: Issue #8 - Single-User Root Password Guard

## Metadata
- **Spec**: `https://github.com/mberrueta/aurum-finance/issues/8`
- **Created**: 2026-03-06
- **Status**: PLANNING
- **Current Task**: 03 (awaiting human approval)

## Overview
Issue #8 introduces minimal self-hosted authentication to block anonymous access while keeping the product single-user. The implementation centers on password-only login, session storage in Phoenix signed cookies, router/LiveView protection, inactivity-timeout enforcement in Aurum auth logic, and boot-time configuration enforcement for `AURUM_ROOT_PASSWORD_HASH`.

## Technical Summary
### Codebase Impact
- **New files**: ~6-10
- **Modified files**: ~8-14
- **Database migrations**: No
- **External dependencies**: `bcrypt_elixir` (or equivalent bcrypt adapter)

### Risk Assessment
| Risk | Likelihood | Impact | Mitigation |
|------|------------|--------|------------|
| Route not fully protected, leaving anonymous access paths | Medium | High | Centralize protection in browser pipeline + `live_session` `on_mount`; add coverage tests for all routes |
| Session timeout behavior implemented inconsistently between HTTP and LiveView | Medium | High | Apply the finalized idle-timeout policy (2h, enforced by Aurum auth logic) and verify with integration + LiveView tests |
| Missing env var check only in prod, not matching acceptance criteria | Medium | High | Enforce startup check at runtime for all app starts (with explicit test strategy) |
| Plain-text password leakage in logs/tests/docs | Low | High | Security review task + test fixtures that only use hashes |

## Roles

### Human Reviewer
- Approves each task before next begins
- Executes all git operations (add, commit, push, checkout, stash, revert)
- Final sign-off on completed work
- Can reject/request changes on any task

### Executing Agents
| Task | Agent | Description |
|------|-------|-------------|
| 01 | `tl-architect` | Define auth architecture, boundaries, and policy decisions |
| 02 | `dev-backend-elixir-engineer` | Implement password hash verification, runtime config enforcement, mix task |
| 03 | `dev-frontend-ui-engineer` | Implement login/logout UX and router/LiveView protection wiring |
| 04 | `qa-elixir-test-author` | Add deterministic tests covering all acceptance criteria |
| 05 | `audit-security` | Validate security posture and secret-handling constraints |
| 06 | `rm-release-manager` | Document rollout/runbook, security-boundary docs alignment, and operator setup steps |

## Task Sequence

| # | Task | Status | Approved | Dependencies |
|---|------|--------|----------|--------------|
| 01 | Auth Policy and Technical Design | ✅ COMPLETED | [x] | None |
| 02 | Backend Auth Foundation | ✅ COMPLETED | [x] | Task 01 |
| 03 | Login UX and Route/LiveView Guarding | ✅ COMPLETED | [ ] | Task 02 |
| 04 | Auth Test Coverage | 🔒 BLOCKED | [ ] | Task 03 |
| 05 | Security Audit and Hardening Review | 🔒 BLOCKED | [ ] | Task 04 |
| 06 | Release Runbook and Ops Checklist | 🔒 BLOCKED | [ ] | Task 05 |

**Status Legend:**
- ⏳ PENDING - Ready to start (dependencies met)
- 🔄 IN_PROGRESS - Currently being executed
- ✅ COMPLETED - Done and approved
- 🔒 BLOCKED - Waiting on dependency
- ❌ REJECTED - Needs rework
- ⏸️ ON_HOLD - Paused by human

## Assumptions
1. GitHub issue #8 is the authoritative specification source for this work (no `llms/specs/*` file exists yet).
2. Password verification will use bcrypt, adding a dependency if not already present.
3. Session timeout is idle-based only: 2 hours of inactivity, enforced by Aurum auth logic (session remains stored in Phoenix signed cookie).
4. Startup enforcement for `AURUM_ROOT_PASSWORD_HASH` applies whenever the application boots, with test setup updated accordingly.
5. Login page can be minimal and does not need full app shell styling parity.

## Open Questions
1. None. Final decisions already made:
- Session is stored in Phoenix signed cookie, and idle timeout (2h) is enforced by Aurum auth logic.
- In development, `/dev/dashboard` remains accessible without auth; all other app routes require a valid session.
- Login flow is controller-based: `GET /login`, `POST /login`, `DELETE /logout`.

## Documentation and Security Alignment
- Implementation must document the security boundary in `docs/security.md`.
- The documentation must explicitly state that auth protects against anonymous network access.
- The documentation must explicitly state that auth does not protect against host/root access.
- The documentation must explicitly state that auth does not protect users who can read or modify environment/runtime configuration.
- This wording must remain proportional to the self-hosted, single-operator model.

## Change Log
| Date | Task | Change | Reason |
|------|------|--------|--------|
| 2026-03-06 | Plan | Initial creation | Requested planning for issue #8 |
| 2026-03-06 | Plan | Final decisions formalized and security-doc alignment clarified | Remove ambiguity and match agreed scope |
