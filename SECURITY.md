# Security Policy

## Reporting a Vulnerability

If you discover a security vulnerability in AurumFinance, please **do not open a public issue**.

Instead, report it privately using **GitHub Security Advisories**:

https://github.com/mberrueta/aurum-finance/security/advisories

This allows maintainers to investigate and fix the issue before public disclosure.

Please include as much information as possible:

- description of the vulnerability
- steps to reproduce
- affected versions or commits
- potential impact
- proof-of-concept (if available and safe)

## Response Process

After receiving a vulnerability report, the maintainer will:

1. Acknowledge receipt of the report.
2. Investigate and validate the issue.
3. Prepare a fix or mitigation.
4. Coordinate responsible disclosure.

If the report is confirmed, a security advisory and fix will be published.

## Supported Versions

AurumFinance is currently in **early-stage development**.

At this time, only the `main` branch is considered supported.

## Security Philosophy

AurumFinance is designed for **self-hosted financial data**, so security and privacy are core principles:

- local-first deployment
- explicit permission boundaries
- auditable ledger-based data model
- minimal external dependencies where possible

## Threat Model and Security Architecture

For the current threat model and authentication security model, see:

- `docs/security.md`

In short, AurumFinance's single-user authentication is designed to prevent unauthorized network access, and it intentionally assumes the operator controls the host environment.