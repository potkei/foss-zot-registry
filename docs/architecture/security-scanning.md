# Security Scanning

## Scanner Stack

All scanners run via Docker Compose with pinned versions (`.cicd/scan-versions.env`).

| Scanner | Type | What It Checks |
|---|---|---|
| Trivy | CVE | Container image vulnerabilities |
| Semgrep | SAST | Source code security patterns |
| SonarQube | SAST | Code quality + security hotspots |
| OWASP Dependency-Check | SCA | Known vulnerable dependencies |
| Gitleaks | Secrets | Secrets in git history |
| Hadolint | IaC | Dockerfile best practices |
| Checkov | IaC | Infrastructure misconfigurations |

## Scan Modes

```mermaid
flowchart LR
    subgraph "Local Mode (no token needed)"
        L1[SonarQube CE] --> L2[Auto-setup project + token]
        L2 --> L3[Scanner CLI]
    end

    subgraph "External Mode (SONAR_TOKEN set)"
        E1[Existing SonarQube] --> E2[Scanner CLI]
    end
```

- **Local**: `docker compose -f .local/docker-compose.scan.yml up` — spins up SonarQube + all scanners
- **External**: Set `SONAR_TOKEN` + `SONAR_HOST_URL` — connects to existing SonarQube

## Scan Gate

The CI pipeline blocks releases if unexpected critical or high findings are detected.
Exceptions must be documented in `.cicd/scan-exceptions.yml` with reason, owner, and expiry.
