# Task 05 Security Findings Report

## Scope Reviewed
- Auth backend/session logic
- Router protection boundaries
- Login/logout controller flow
- Rate-limiting hardening for login attempts
- Security documentation alignment
- Existing auth test evidence (Task 04 + follow-up hardening tests)

## Findings

### 1. MINOR - Login endpoint reveals setup state when hash is missing
- **Location**: `lib/aurum_finance_web/controllers/auth_controller.ex`
- **Observation**: `/login` intentionally shows setup guidance when `AURUM_ROOT_PASSWORD_HASH` is not configured.
- **Risk**: Low information disclosure (attacker can infer operator setup state).
- **Disposition**: **Accepted** by product decision; improves operator recovery and avoids confusing login failures.

### 2. INFO - Brute-force baseline mitigation implemented (IP-based limiter)
- **Location**:
  - `lib/aurum_finance_web/auth_rate_limiter.ex`
  - `lib/aurum_finance_web/controllers/auth_controller.ex`
  - `test/aurum_finance_web/auth_rate_limiter_test.exs`
  - `test/aurum_finance_web/controllers/auth_controller_test.exs`
- **Observation**: Login attempts are now throttled by client IP with a rolling window and temporary lockout.
- **Current policy**: 5 failed attempts per 5 minutes, lockout for 5 minutes.
- **Risk reduction**: Lowers online password-guessing throughput.
- **Residual risk**: Limiter is in-memory and process-local (resets on restart, not shared across nodes).
- **Disposition**: **Addressed for current scope**; future enhancement can add distributed/persistent throttling and structured auth-failure logging.

### 3. INFO - Dev dashboard remains outside auth guard in development
- **Location**: `lib/aurum_finance_web/router.ex`
- **Observation**: `/dev/dashboard` remains public in dev scope.
- **Risk**: Expected for local development; unsafe if dev routes are exposed externally.
- **Disposition**: **Accepted** by explicit plan decision.

## Positive Security Checks
- Protected app routes and LiveViews enforce auth via plug + `on_mount`.
- Session fixation mitigation applied on login (`configure_session(renew: true)` + session reset).
- Logout drops session cookie.
- Idle timeout enforced by Aurum auth logic (`AurumFinance.Auth.validate_session/2`).
- Root secret stored as bcrypt hash only; no plaintext defaults persisted.
- Login brute-force baseline throttling is active and covered by tests.
- Security boundary documentation exists and matches threat model (`docs/security.md`).

## Blocking Issues
- **None identified**.

## Release Recommendation
- **Safe to proceed** to Task 06 for release/runbook finalization.

## Notes
- This review reflects the current accepted behavior where missing hash shows setup guidance on `/login`.
- Sobelow task is not available in this repository (`mix sobelow` task missing), so this report is based on code-path review plus automated tests present in this repo.
