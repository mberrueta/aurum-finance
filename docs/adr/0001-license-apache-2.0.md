# ADR 0001: Open Source License — Apache License 2.0

- Status: Accepted
- Date: 2026-03-04
- Decision Makers: Maintainer(s)

## Context

AurumFinance is an open-source, self-hosted personal finance operating system.
The project is intended to be:
- practical for real personal use
- a reference-quality portfolio project
- privacy-first / self-hosted by default

Because it handles sensitive financial data, it is important that:
- the codebase is easy to adopt and self-host
- contributions are encouraged
- legal/compliance overhead for users and contributors is minimized
- the project is safe to use in environments where patent concerns may exist

## Decision Drivers

1. Maximize adoption and reuse (personal + commercial)
2. Encourage contributions without complex license constraints
3. Reduce patent-risk ambiguity for users and contributors
4. Keep license compliance simple for a small, early-stage project

## Considered Options

### Option A — Apache License 2.0 (Chosen)
A permissive license with an explicit contributor patent license grant. :contentReference[oaicite:5]{index=5}

### Option B — MIT License
Very permissive and short, but does not include an explicit patent license grant (patent coverage is often argued as implicit, but remains less explicit). :contentReference[oaicite:6]{index=6}

### Option C — MPL 2.0
Weak/file-level copyleft intended to require sharing modifications to MPL-covered files while allowing proprietary combinations; adds more compliance overhead than permissive licenses. :contentReference[oaicite:7]{index=7}

### Option D — AGPLv3
Strong copyleft designed for network/server software to ensure users interacting over a network can obtain source of modified versions; can reduce adoption and complicate integration. :contentReference[oaicite:8]{index=8}

## Decision

We will license AurumFinance under the **Apache License 2.0**.

## Rationale

Apache-2.0 best satisfies the decision drivers:
- It is permissive, making it easy for individuals and organizations to self-host and extend AurumFinance.
- It includes an explicit patent license grant from contributors, improving legal clarity and reducing adoption friction. :contentReference[oaicite:9]{index=9}
- It keeps compliance simple while still providing clear attribution and licensing terms.

MIT was rejected due to less explicit patent clarity. :contentReference[oaicite:10]{index=10}  
MPL-2.0 and AGPLv3 were rejected because copyleft obligations add friction for users and contributors (and AGPL can materially limit adoption). :contentReference[oaicite:11]{index=11}

## Consequences

### Positive
- Lower barrier to adoption and contribution
- Better patent clarity than MIT-style licenses
- Easier compatibility with a wide range of dependencies and deployment environments

### Negative / Trade-offs
- Does not prevent closed-source forks or hosted proprietary derivatives
- “SaaS enclosure” is not blocked by the license (would require AGPL or a different strategy)

### Mitigations / Follow-ups
- Build community and brand moats: clear docs, strong governance, great contributor experience
- If “hosted proprietary enclosure” becomes a real problem later, consider re-evaluating licensing
  (this would be a major change requiring explicit community communication)

## Implementation Notes

- Add `LICENSE` containing the full Apache-2.0 text.
- Add `NOTICE` (optional but commonly used with Apache-2.0; recommended once third-party attributions accumulate).
- Ensure repository headers/badges match Apache-2.0.
