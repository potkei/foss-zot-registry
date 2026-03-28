# =============================================================================
# FOSS Boilerplate — Makefile shortcuts
# Usage: make <target>
# =============================================================================

.DEFAULT_GOAL := help

# Build
build:                 ## Source build (default)
	./build.sh --source

build-binary:          ## Binary fallback build
	./build.sh --binary

build-both:            ## Build both strategies
	./build.sh --both

build-go:              ## Source build for Go projects
	docker compose -f .local/docker-compose.build.yaml --profile source-go build

# Scan
scan:                  ## Run all security scans
	./build.sh --scan

scan-cve:              ## CVE scan only (Trivy)
	./build.sh --scan --cve

scan-sast:             ## SAST only (Semgrep + SonarQube)
	./build.sh --scan --sast

scan-deps:             ## Dependency check (OWASP DC)
	./build.sh --scan --deps

scan-secrets:          ## Secret detection (Gitleaks)
	./build.sh --scan --secrets

scan-iac:              ## IaC lint (Hadolint + Checkov)
	./build.sh --scan --iac

# Release
release:               ## Full pipeline: build + scan + release
	./build.sh --release

# Docs
docs:                  ## Serve MkDocs at http://localhost:8000
	./build.sh --docs

docs-build:            ## Build static docs site
	docker compose -f .local/docker-compose.docs.yml run docs build

# Run
run:                   ## Run the built app locally
	docker compose -f .local/docker-compose.run.yml up

run-bg:                ## Run the built app in background
	docker compose -f .local/docker-compose.run.yml up -d

run-down:              ## Stop the running app
	docker compose -f .local/docker-compose.run.yml down

# Registry
registry-up:           ## Start local registry (localhost:5000) + UI (localhost:5001)
	./build.sh --registry

registry-down:         ## Stop local registry
	docker compose -f .local/docker-compose.registry.yml down

registry-ui:           ## Open registry UI in browser
	open http://localhost:5001

push-local:            ## Build source image and push to localhost:5000
	./build.sh --push-local

# Test
test:                  ## Run all BATS tests in Docker (no local install needed)
	docker compose -f .local/docker-compose.test.yml run --rm test

test-local:            ## Run BATS tests locally (requires bats in PATH)
	bats --recursive .tools/tests/

# Setup
init:                  ## First-run setup (translate scripts, create dirs)
	./init.sh

onboard:               ## Onboard a new FOSS project (interactive)
	bash .cicd/docker-resources/scripts/onboard-foss.sh

# Cleanup
clean:                 ## Remove reports and build artifacts
	rm -rf reports/*.json reports/*.html reports/*.txt
	docker compose -f .local/docker-compose.build.yaml down --rmi local 2>/dev/null || true

clean-all:             ## Remove everything including volumes
	docker compose --env-file .cicd/scan-versions.env -f .local/docker-compose.scan.yml down -v 2>/dev/null || true
	docker compose -f .local/docker-compose.registry.yml down -v 2>/dev/null || true
	docker compose -f .local/docker-compose.build.yaml down --rmi local -v 2>/dev/null || true
	rm -rf reports/*.json reports/*.html reports/*.txt

# Help
help:                  ## Show this help
	@grep -E '^[a-zA-Z_-]+:.*##' $(MAKEFILE_LIST) | sort | awk 'BEGIN {FS = ":.*## "}; {printf "\033[36m%-18s\033[0m %s\n", $$1, $$2}'

.PHONY: build build-binary build-both build-go scan scan-cve scan-sast scan-deps scan-secrets scan-iac release docs docs-build run run-bg run-down registry-up registry-down registry-ui push-local init onboard test test-local clean clean-all help
