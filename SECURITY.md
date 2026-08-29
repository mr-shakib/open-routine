# Security Policy

## Reporting a vulnerability

Please **do not open a public issue** for security vulnerabilities.

Report privately via GitHub's [Security Advisories](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability) ("Report a vulnerability" on the Security tab).

Please include: what the issue is, how to reproduce it, and what an attacker could achieve. We aim to acknowledge within 72 hours.

## Scope

In scope: this repository's backend and app — authentication, data handling, ingestion, dependencies.

Out of scope: Daffodil International University's own systems and any third-party service. **Please do not test against university infrastructure.**

## Design notes

- **No credentials required.** The app needs no login to read the routine. There is no user password to leak.
- **The routine is public data.** We deliberately do **not** encrypt or obfuscate it in transport. The app we studied did, using a key shipped to the client — which provides no real confidentiality while adding complexity. Standard TLS is the correct and sufficient control.
- **Ingestion input is untrusted.** Spreadsheets are parsed defensively and validated against the expected lattice before anything is written.
