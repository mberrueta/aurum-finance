# ADR 0018: Financial Data Security Boundaries

- Status: Accepted
- Date: 2026-03-05
- Decision Makers: Maintainer(s)
- Phase: 2 — Architecture & System Design
- Source: Architecture consolidation follow-up (post Steps 1-10 baseline)

## Context

AurumFinance processes highly sensitive financial data: account identifiers,
transaction history, institution metadata, and tax-relevant records.

The system uses a single-operator model with edge authentication (root password
guard), but sensitive-data handling still requires explicit architectural
boundaries, especially for AI/MCP-assisted workflows.

This ADR defines data sensitivity classes, entity isolation expectations,
access-control concepts, and AI/MCP data exposure rules.

### Inputs

- ADR-0007: Context boundaries and edge authentication posture.
- ADR-0009: Entity-based ownership/isolation model.
- ADR-0010: Import provenance and raw evidence handling.
- ADR-0012: Tax snapshots and sensitive tax-rate evidence.
- ADR-0014: Canonical core financial model.

## Decision Drivers

1. Financial and tax data require explicit handling boundaries.
2. Sensitive data minimization must be built into architecture, not ad hoc.
3. AI/MCP integrations need strict read scopes and redaction policies.
4. Security posture must remain compatible with single-operator deployment.
5. Auditability of sensitive-data access is necessary for trust.

## Decision

### 1. Data Sensitivity Classes

Four architectural sensitivity classes are defined:

1. **Public metadata:** currency codes, non-sensitive taxonomy labels.
2. **Operational-sensitive:** account nicknames, category/tag labels, internal
   identifiers.
3. **Financial-sensitive:** transaction descriptions, amounts, balances,
   institution references, holdings/valuation data.
4. **Regulated-sensitive:** tax snapshots, tax identifiers, legal entity
   attributes, imported source artifacts.

Access and exposure policy must be stricter as class increases.

### 2. Entity Data Isolation

Entity remains the primary ownership boundary for financial data. All
entity-scoped datasets must require explicit entity context at boundary APIs.

Cross-entity reads are allowed only when the caller intentionally specifies a
cross-entity scope.

No implicit "all entities" access path is allowed for sensitive datasets.

### 3. Access Control Concepts

Given current single-operator architecture:
- access is authenticated at the edge,
- authorization defaults to operator access,
- sensitive operation classes still require intent-explicit APIs.

This ADR does not introduce a multi-user RBAC model; it defines boundaries that
remain valid if RBAC is added later.

### 4. AI and MCP Access Restrictions

AI/MCP access is constrained by policy:

1. **Least data principle:** only fields required for the specific operation
   may be exposed.
2. **Redaction by default:** account numbers, tax IDs, and institution IDs are
   masked unless explicitly required.
3. **Explicit scope:** requests must carry entity and time-range scope.
4. **No write authority by default:** AI/MCP paths are read-oriented unless a
   separately authorized action path is invoked.
5. **Prompt/context hygiene:** avoid sending raw imported artifacts when
   normalized/derived forms are sufficient.

### 5. Audit and Evidence Requirements

Sensitive access paths should produce audit records including:
- actor/channel (`web`, `mcp`, `ai_assistant`),
- requested scope (entity/date/data class),
- purpose/action type,
- timestamp and outcome.

Audit records are metadata; they do not alter financial facts.

### 5.1 Top risks (minimum threat model)

The architecture explicitly tracks these high-priority risks:

1. **Prompt injection in AI-assisted flows** leading to over-broad data
   retrieval or policy bypass attempts.
2. **PII/financial data exfiltration via logs** when sensitive payloads are
   accidentally serialized in application or integration logs.
3. **Accidental cross-entity query scope** caused by missing/incorrect entity
   filters in read paths.

Mitigation posture: strict scope enforcement, redaction defaults, and access
auditing on sensitive channels.

### 6. Data Retention and Redaction Posture

1. Source import artifacts are retained for traceability but treated as
   high-sensitivity data.
2. Redaction-safe export forms must be available for support/analysis.
3. Deletion/anonymization workflows must not break ledger audit integrity.

### 6.1 Data at Rest Posture

As a self-hosted system, encryption-at-rest guarantees depend on host/storage
configuration outside the application boundary. AurumFinance explicitly places
responsibility on operators for:

- secure secret management (environment/runtime configuration, no hardcoded
  credentials),
- encrypted and access-controlled backups,
- retention and restore procedures aligned with sensitivity classes.

## Rationale

This model balances current product reality (single operator, self-hosted
deployment) with explicit safeguards for sensitive financial and tax data.

It also creates a stable policy foundation for AI/MCP features without waiting
for a future full RBAC implementation.

## Consequences

### Positive

- Clear security vocabulary for future features and reviews.
- Reduced risk of over-exposing sensitive fields to AI/MCP channels.
- Stronger trust posture for financial and tax workflows.
- Forward-compatible with future multi-user authorization.

### Negative / Trade-offs

- Additional policy and logging surface area to maintain.
- Some workflows require redaction-aware data shaping.
- AI assistance may become less convenient for broad exploratory prompts.

### Mitigations

- Provide standard redacted DTO/view helpers.
- Centralize AI/MCP policy checks in boundary modules.
- Maintain a clear catalog of sensitivity classes and allowed operations.

## Implementation Notes

- Introduce reusable redaction/masking utilities for sensitive fields.
- Require explicit scope parameters for AI/MCP retrieval operations.
- Keep audit logs append-only and queryable by channel/scope.
- Treat imported raw files and tax snapshot data as highest-sensitivity classes.
