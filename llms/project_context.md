# Project Context

This file captures project-specific context used by agents.

## Precedence
- `llms/constitution.md` is the baseline for all LLM agents (Codex, Claude, Gemini, and others).
- This file extends that baseline with project-specific context and must not conflict with it.

## App identity
- App name: `aurum_finance`
- Web module: `AurumFinanceWeb`
- Framework: Phoenix + LiveView

## Domain focus
AurumFinance is a self-hosted personal finance operating system focused on:
- ledger correctness
- reconciliation workflows
- privacy-first data ownership

## Engineering conventions
- Follow `AGENTS.md` as the primary instruction source.
- Use `Req` for HTTP integrations.
- Run `mix precommit` before finishing tasks.
