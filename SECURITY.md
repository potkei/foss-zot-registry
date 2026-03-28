# Security Policy

## Supported Versions

| Version | Supported |
|---|---|
| Latest `-rN` release | Yes |
| Previous `-rN` on same upstream | Best effort |
| Older upstream versions | No |

## Reporting a Vulnerability

If you discover a security vulnerability in **our patches or build pipeline**, please report it
responsibly:

1. **Do NOT open a public GitHub issue.**
2. Email: `security@REPLACE_ORG.com`
3. Include:
   - Description of the vulnerability
   - Steps to reproduce
   - Affected version(s)
   - Suggested fix (if any)

We will acknowledge receipt within **48 hours** and provide an initial assessment within
**5 business days**.

## Upstream Vulnerabilities

This repository ships patched container images of upstream open source software. If the
vulnerability is in the **upstream project itself** (not our patches):

1. Report it to the upstream project first.
2. Open an issue here referencing the upstream CVE so we can prioritize a patched build.

## CVE Response SLA

| Severity | CVSS | Patch SLA | Binary Fallback |
|---|---|---|---|
| Critical | >= 9.0 | 24 hours | Yes, if source blocked |
| High | 7.0 - 8.9 | 72 hours | After 72h if blocked |
| Medium | 4.0 - 6.9 | Next release | No |
| Low | < 4.0 | Next release | No |

## Security Controls

- All upstream archives are verified via SHA256 checksum (+ GPG where available)
- All container images pass CVE scanning (Trivy) before release
- SBOM generated on every release (CycloneDX via Syft)
- Images signed on every release (Cosign)
- No secrets in build args or committed to repository
- Base images pinned to specific versions (no `latest` tags)

## Disclosure Policy

We follow coordinated disclosure. Fixes will be released before public disclosure when possible.
