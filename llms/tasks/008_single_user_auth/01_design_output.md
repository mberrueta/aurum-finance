# Task 01 Design Output: Single-User Auth Policy and Technical Design

## Scope
Design-only decisions for issue #8 (`Impl: Auth — single-user root password guard`).
This document defines boundaries and implementation touchpoints for Tasks 02-06.

## Final Decisions

1. **Auth model**
- Single-user root-password model only.
- No username, no OAuth, no roles, no password reset.

2. **Credentials source and verification**
- Root bcrypt hash is provided by environment variable: `AURUM_ROOT_PASSWORD_HASH`.
- Password verification uses bcrypt against that hash.
- Plain-text password is never stored in repository, image layers, or application defaults.

3. **Session model and timeout**
- Session is stored in Phoenix signed cookie.
- Idle timeout is **2 hours**.
- Idle timeout enforcement is implemented by Aurum auth logic (not by cookie signing alone).

4. **Auth endpoints shape**
- `GET /login`
- `POST /login`
- `DELETE /logout`
- Login is controller-based.

5. **Route protection policy**
- All app routes and LiveViews require valid session.
- Exception: login/logout routes are public.
- Development exception: `/dev/dashboard` remains accessible without auth in dev.

6. **Startup policy**
- Application startup must fail if `AURUM_ROOT_PASSWORD_HASH` is missing.
- This must be enforced in runtime configuration logic.

7. **Security documentation alignment**
- Implementation must ensure `docs/security.md` explicitly states:
  - protects against anonymous network access
  - does not protect against host/root access
  - does not protect actors who can read/modify env/runtime config
- Wording must stay proportional to self-hosted, single-operator assumptions.

## Guard Matrix

| Surface | Access Policy | Enforcement Point |
|---|---|---|
| `GET /login` | Public | Router public scope/pipeline |
| `POST /login` | Public | Router public scope + controller auth action |
| `DELETE /logout` | Authenticated session required | Router/auth pipeline + controller logout action |
| `/`, `/dashboard`, `/accounts`, `/transactions`, `/import`, `/rules`, `/reconciliation`, `/fx`, `/reports`, `/settings` | Authenticated session required | Router auth pipeline + protected `live_session` `on_mount` |
| `/dev/dashboard` (dev only) | Public in dev | Existing dev scope stays outside auth guard |

## Acceptance Criteria Mapping

| Issue #8 Criterion | Implementation Touchpoint |
|---|---|
| App is inaccessible without valid session | Router authenticated pipeline + protected `live_session` `on_mount` for all app LiveViews |
| Root password hash configured via env var | Runtime configuration contract + auth module config reader |
| Simple login page with password only | Controller + login template/live-rendered view (minimal UI) |
| Password verification uses bcrypt | Auth backend verification module |
| Session stored in Phoenix signed cookie | Endpoint session config + auth session lifecycle logic |
| All routes and LiveViews protected via plug/`on_mount` | Router pipeline and `live_session` `on_mount` guard module |
| Logout button in nav | Layout navigation update pointing to `DELETE /logout` flow |
| Session timeout defaults to 2 hours | Aurum auth session validator (idle timeout check) |
| App refuses to start if hash not set | `config/runtime.exs` startup check |
| Plain-text password never stored | Mix hash generation task + docs/runbook + security audit checks |

## Proposed File-Level Touchpoints (for Tasks 02/03)

- `config/runtime.exs`: enforce presence of `AURUM_ROOT_PASSWORD_HASH` at startup.
- `lib/aurum_finance_web/router.ex`: split public auth routes vs authenticated app routes; apply plug + `on_mount`.
- `lib/aurum_finance_web/endpoint.ex`: keep signed-cookie session strategy.
- `lib/aurum_finance_web/components/layouts.ex`: add logout action in nav shell.
- `lib/aurum_finance_web/...` (new auth modules/controllers/views): login/logout and session validation boundaries.
- `lib/mix/tasks/aurum.gen_password_hash.ex` (new): emit bcrypt hash only.
- `docs/security.md`: explicit boundary statements aligned to self-hosted model.

## Non-Goals Confirmation

- No user accounts table.
- No multi-user sessions.
- No role/permission matrix.
- No OAuth/OIDC.
- No password reset/recovery flow.

## Assumptions

- `bcrypt_elixir` (or compatible bcrypt adapter) will be added if missing.
- Existing LiveViews can be protected centrally via `live_session` `on_mount` without per-view custom auth code.
- Controller-based login is acceptable while preserving minimal UX requirements.

## Blockers / Questions

None. Final decisions are already established in plan and this output.
