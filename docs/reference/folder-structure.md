# Folder Structure

```
.agents/              # Shared AI hub — all tools read CONSTITUTION.md here
  skills/             # AI runbooks for CVE patching, releasing, etc.
.cicd/                # All CI/CD pipeline configuration
  docker-resources/
    scripts/          # Build, scan, release scripts (stored as .sh.txt)
    secrets/          # Mount-only credentials (gitignored)
  jenkins_config.yml  # Jenkins declarative pipeline
  scan-versions.env   # Pinned scanner versions
  scan-exceptions.yml # Accepted CVE exceptions
.claude/commands/     # Claude Code slash commands
.codex/               # OpenAI Codex instructions
.cursor/              # Cursor AI rules
.github/              # GitHub workflows, Copilot instructions
.local/               # Local dev only — compose files, tool Dockerfiles
  docker-compose.build.yaml
  docker-compose.run.yml
  docker-compose.scan.yml
  docker-compose.scan.external.yml
  docker-compose.registry.yml
  docker-compose.docs.yml
.tools/               # Local tooling — compiled utilities
  jsonq/              # Go source for jq-compatible JSON CLI (built by init.sh)
  bin/                # Compiled binaries — gitignored, built locally
docs/                 # MkDocs documentation with Mermaid diagrams
helm/                 # Helm chart for Kubernetes deployment
patches/              # CVE patch files (source build only)
reports/              # Scan output (gitignored)
Dockerfile            # Source build — C/generic (PRIORITY)
Dockerfile.go         # Source build — Go-specific (PRIORITY)
Dockerfile.binary     # Binary fallback
init.sh.txt           # First-run setup (rename to init.sh to bootstrap)
build.sh.txt          # Main build entrypoint (translated by init.sh)
Makefile              # Shortcut aliases
mkdocs.yml            # MkDocs config (always at repo root)
CLAUDE.md             # Claude Code adapter (references CONSTITUTION.md)
SECURITY.md           # Vulnerability disclosure policy
CHANGELOG.md          # Release changelog
```
