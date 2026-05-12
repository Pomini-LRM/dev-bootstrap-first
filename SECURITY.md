# Security Policy

## Supported Versions

Only the latest release is actively maintained with security updates.

| Version | Supported |
|---------|-----------|
| Latest  | Yes       |
| Older   | No        |

## Reporting a Vulnerability

If you discover a security vulnerability, please report it responsibly:

1. **Do not** open a public issue.
2. Use [GitHub Security Advisories](https://docs.github.com/en/code-security/security-advisories/guidance-on-reporting-and-writing-information-about-vulnerabilities/privately-reporting-a-security-vulnerability)
   to report the vulnerability privately through this repository's **Security** tab > **Report a vulnerability**.
3. Include as much detail as possible: steps to reproduce, affected versions, and potential impact.

We will acknowledge receipt and work on a fix. Security patches are given the highest priority.

## Security design notes

- Both launchers download exclusively from `https://github.com/Pomini-LRM/dev-bootstrap`
  over HTTPS using the system TLS stack. No custom certificate pinning is applied.
- The launchers do **not** require elevated privileges to download or extract.
  Only the downstream prerequisite installers (`install-prerequisites-*.ps1` / `.sh`)
  may prompt for elevation to install system packages.
- No tokens or secrets are stored, logged, or transmitted by the launchers.
  Credential handling is delegated entirely to `setup-config-interactive.ps1`
  and `dev-bootstrap.ps1`.
- Inspect the source of `dev-bootstrap-first-run.cmd` and `dev-bootstrap-first-run.sh`
  before running on a managed or shared workstation.
