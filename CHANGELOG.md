# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).
Versioning follows `{upstream_version}-r{N}` (see CLAUDE.md Article III).

## [Unreleased]

## [2.1.15-r2] - 2026-03-28

### Security
- **CVE-2026-33186** (CVSS 9.1 Critical): gRPC-Go authorization bypass via missing leading slash in `:path` header
  - Patch: `patches/0001-CVE-2026-33186-gomod-bump-grpc.patch`
  - Fix: `google.golang.org/grpc` bumped v1.79.0 → v1.79.3
  - Upstream: fixed-in-1.79.3
- **CVE-2026-0861** (CVSS 8.1 High): glibc integer overflow in memalign leading to heap corruption (`libc6`)
  - No upstream fix available as of 2026-03-28
  - Accepted in `.trivyignore` — expiry 2026-09-28, owner: security-team
  - Revisit when debian12 ships patched libc6

### Build Strategy
- `source` (default)

## [2.1.15-r1] - 2026-03-28

### Initial
- Forked from upstream zot 2.1.15
- Source: https://github.com/project-zot/zot/archive/refs/tags/v2.1.15.tar.gz
- SHA256: 183525bc4ffdf031c6c7e40a013f888f3a1f9a7acc149baa01cd6adc00f59b23 (computed locally — verify against a second trusted source)
- License: Apache-2.0
- Build strategy: source (Go 1.25.7, `make binary` with embedded UI via zui commit-111cb8e)
- No CVE patches applied at initial onboard

<!-- =======================================================================
Release entry template — copy and fill in for each release:

## [X.Y.Z-rN] — YYYY-MM-DD

### Security
- **CVE-YYYY-NNNNN**: Brief description of the fix
  - Patch: `patches/0001-CVE-YYYY-NNNNN-description.patch`
  - Upstream: not-fixed | fixed-in-X.Y.Z | pending
  - CVSS: X.X (Critical|High|Medium|Low)

### Added
- New feature or capability

### Changed
- Modification to existing behavior

### Fixed
- Bug fix (non-security)

### [BLOCKED] (if applicable)
- **CVE-YYYY-NNNNN**: Blocked by {dependency}. Expected resolution: {date}. Owner: {name}

### Build Strategy
- `source` (default) | `binary` (fallback — reason: {reason}, approved by: {name})

======================================================================= -->
