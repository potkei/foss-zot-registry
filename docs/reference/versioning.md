# Versioning Convention

## Format

```
{upstream_foss_version}-r{N}
```

## Examples

| Version | Meaning |
|---|---|
| `6.0.0-r1` | First revision on upstream 6.0.0 |
| `6.0.0-r2` | Second CVE fix, same upstream version |
| `6.1.0-r1` | Upstream bumped to 6.1.0, revision resets to r1 |

## Rules

- Revision resets to `r1` whenever the upstream version changes
- Git tag, Docker image tag, Helm `appVersion`, and `package.json` version all use this exact format
- CHANGELOG entry must map each `-rN` to the CVE ID(s) it addresses

## Where Version Lives

| Location | Field |
|---|---|
| `package.json` | `version` |
| Git | Tag name |
| Docker image | Tag name + OCI label |
| Helm chart | `appVersion` in `Chart.yaml` |
| CHANGELOG.md | Section header |
