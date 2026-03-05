# ADR 0003: Grouped Rules Engine Execution and Explainability Model

- Status: Accepted
- Date: 2026-03-04
- Decision Makers: Maintainer(s)
- Phase: 1 — Research & Landscape Analysis
- Source: `llms/tasks/001_research_landscape_analysis/plan.md`

## Context

Automated classification of imported transactions requires a rules engine.
The core design question is whether rules execute as a single flat priority list
(first match wins globally) or as independent groups each with their own priority order.

Firefly III uses a flat priority-ordered pipeline (triggers → conditions → actions),
which is proven but limits the ability to classify the same transaction across
multiple independent dimensions simultaneously.

## Decision Drivers

1. A single transaction often needs simultaneous, independent classification across
   multiple dimensions (expense type, account origin, investment type, etc.).
2. Each dimension should be independently maintainable — changes to expense rules
   should not require reasoning about account-tagging rules.
3. Every automated change must be explainable at the group, rule, and field level.
4. User overrides must survive re-runs without being silently overwritten.

## Decision

AurumFinance will use a **grouped rules engine** model:

- Rules are organized into **independent groups**. Each group has a dedicated responsibility
  (e.g., expense category, account origin, investment type).
- **Multiple groups can match the same transaction simultaneously.** Each group produces
  its output independently — there is no conflict between groups.
- **Within a group, priority order applies.** The first matching rule in the group wins;
  remaining rules in that group are skipped.
- **No match in a group is a valid outcome.** Absence of match produces no output for
  that group — it is not an error.

### Example

```
Group 1 — Expense Type
  Rule 1.1: description contains "UBER"  → category = Transport
  Rule 1.2: description contains "RAPPI" → category = Food Delivery
  Rule 1.3: amount < 0, account = VISA   → category = General Expense

Group 2 — Account Origin
  Rule 2.1: account = "VISA Santander"  → tag = credit-card
  Rule 2.2: account = "CA USD"          → tag = usd-account
  Rule 2.3: account = "Broker A"        → tag = brokerage

Group 3 — Investment Type
  Rule 3.1: description matches /ETF/i           → investment_type = ETF
  Rule 3.2: description matches /Corporate Bond/i → investment_type = Corporate Bond
```

A transaction "UBER EATS" charged to VISA Santander simultaneously matches
Group 1 (→ category = Food Delivery) and Group 2 (→ tag = credit-card). Group 3
produces no output. All three outcomes are recorded.

### Explainability requirements

Every automated change must record:
- Which group fired.
- Which rule within the group matched.
- What fields were modified and their previous values.
- That no match occurred in groups that did not fire.

### Import preview

Rules must support a **preview-before-apply** mode showing per-row: matched group,
matched rule, proposed changes, and confidence. The user can approve, reject, or
modify before committing.

## Rationale

The grouped model allows independent classification dimensions to coexist without
coupling. A flat pipeline requires the rule author to reason about global priority
across unrelated concerns; the grouped model constrains priority reasoning to within
a single responsibility boundary.

Firefly III's trigger → condition → action pipeline is the closest external reference
and validates that rules with explicit conditions and actions are a proven UX pattern.
The grouped extension is AurumFinance's deliberate differentiation.

## Consequences

### Positive
- Multiple classification dimensions can be maintained independently.
- Explainability is structural: each output is attributed to an exact group + rule.
- Adding a new classification dimension (new group) does not affect existing groups.
- No-match is explicit and auditable, not silently ignored.

### Negative / Trade-offs
- More complex engine than a single flat pipeline.
- Rule authors must understand the group model to write effective rules.

### Mitigations
- UI for rule management should make the group concept explicit and visual.
- Preview mode lowers the cost of experimenting with rules before applying them.

## Implementation Notes

- Groups are ordered for UI presentation but execution order between groups does not matter.
- Each group should declare which output field(s) it is responsible for.
- Classification audit log must record group ID, rule ID, field name, old value, new value, and timestamp.
