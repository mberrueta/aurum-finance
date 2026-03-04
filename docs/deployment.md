# Deployment Guide

This document defines the deployment contract for AurumFinance across local and production environments.

## Objectives

- Keep deployments reproducible and low-risk.
- Make runtime configuration explicit.
- Ensure database migrations are controlled and reversible.

## Deployment targets

- Local containerized runtime: `docker compose`
- Production container runtime: OCI image from `Dockerfile`

Current release behavior:
- The container command runs migrations on startup via `AurumFinance.Release.migrate/0`.
- The app then starts the release (`/app/bin/aurum_finance start`).

## Runtime configuration contract

Required in production:

- `DATABASE_URL`
  - Example: `ecto://USER:PASS@HOST/DATABASE`
- `SECRET_KEY_BASE`
  - Generate with: `mix phx.gen.secret`
- `PHX_HOST`
  - Public hostname, used by endpoint URL generation.

Recommended in production:

- `PORT`
  - Defaults to `4000` if not set.
- `POOL_SIZE`
  - Defaults to `10` if not set.
- `ECTO_IPV6`
  - Set to `true`/`1` when using IPv6 DB networking.
- `PHX_SERVER=true`
  - Required when running release directly.

Optional cluster/runtime:

- `DNS_CLUSTER_QUERY`

## Build

Build production image:

```bash
docker build --build-arg MIX_ENV=prod -t aurum_finance:prod .
```

## Run

Run production image directly:

```bash
docker run --rm -p 4000:4000 \
  -e PHX_SERVER=true \
  -e PORT=4000 \
  -e PHX_HOST=localhost \
  -e DATABASE_URL='ecto://postgres:postgres@host.docker.internal/aurum_finance_dev' \
  -e SECRET_KEY_BASE='replace_me' \
  aurum_finance:prod
```

Run local stack:

```bash
docker compose up --build
```

## Migration strategy

Startup migration is currently enabled in container `CMD`.

Pros:
- Simple operational flow for early stage.

Risks:
- Concurrent startups can attempt migrations simultaneously.
- Large/locking migrations can extend startup time.

Recommended evolution for scale:
- Move migrations to a dedicated one-shot release job in CI/CD.
- Keep app startup migration-free in steady-state workloads.

## Rollback

Rollback a migration version from a running release shell:

```bash
/app/bin/aurum_finance eval "AurumFinance.Release.rollback(AurumFinance.Repo, 20260304120000)"
```

Notes:
- Use exact migration timestamp version.
- Always confirm target DB and environment before rollback.

## Verification checklist

After deploy:

1. Confirm container is healthy/running.
2. Confirm app responds on configured port.
3. Confirm DB connectivity (no `DBConnection` errors in logs).
4. Confirm no migration failures in startup logs.
5. Confirm static assets are served (CSS/JS load without 404s).

## Security and secret handling

- Never commit `.env`, `.env.*`, `.envrc.custom`, or `.envrc_custom`.
- Inject secrets from runtime secret manager or platform secrets.
- Treat `SECRET_KEY_BASE` as sensitive and rotate on compromise events.

## Operational notes

- `.envrc` provides open-source defaults for local development.
- `.envrc_custom` is for machine-specific overrides.
