# Skill: Monorepo Add Project

Add a new FOSS subproject under `projects/<foss-name>/` in a monorepo.

## Purpose
Scaffold a new FOSS project as a subproject of an existing monorepo, following the same
polyrepo structure inside `projects/<name>/`, and wire it into the root CI pipeline.

## Prerequisites
- Repository is in monorepo mode (`projects/` directory exists at root)
- Root `CLAUDE.md` and `.cicd/jenkins_config.yml` already configured

## Steps

### Step 1 — Collect Details
Ask the same questions as `onboard-foss-project.md` Step 1, plus:
- Subproject name? (will become `projects/<name>/`)
- Does this subproject share the root CI or needs its own Jenkins pipeline?

### Step 2 — Create Subproject Directory Structure
```bash
mkdir -p projects/<foss-name>/{patches,helm/templates,.cicd/docker-resources/scripts,.deploy/compose}
```

Directory mirrors polyrepo structure:
```
projects/<foss-name>/
    Dockerfile
    Dockerfile.go        (if Go project)
    Dockerfile.binary
    package.json
    build.sh.txt
    patches/
        README.md
        verify.sh.txt
        .gitkeep
    helm/
        Chart.yaml
        values.yaml
        values.binary.yaml
        templates/
    .deploy/compose/
        docker-compose.load.yml
        docker-compose.dev.yml
```

### Step 3 — Copy and Customize Templates
Copy root-level templates into the subproject directory and fill placeholders
using the same process as `onboard-foss-project.md` Steps 2–3.

Key differences for monorepo:
- `package.json` `name` field: `<foss-name>-fork` (subproject-scoped)
- `helm/Chart.yaml` name: `<foss-name>` (no conflict with other subprojects)
- Relative paths in scripts reference `../../` for shared root scripts

### Step 4 — Wire into Root CI
Update `.cicd/jenkins_config.yml` to add a parallel stage for the new subproject:

```yaml
# Add to parallel stages section
stage('<foss-name>') {
  steps {
    dir("projects/<foss-name>") {
      sh "BUILD_STRATEGY=${BUILD_STRATEGY} ./build.sh"
    }
  }
}
```

### Step 5 — Update Root Compose Files
Add the new subproject service to `projects/docker-compose.all.yml`:
```yaml
include:
  - projects/<foss-name>/.deploy/compose/docker-compose.load.yml
```

### Step 6 — Translate Script Files
```bash
find projects/<foss-name> -name "*.sh.txt" | while read f; do
  target="${f%.txt}"
  cp "$f" "$target" && chmod +x "$target"
done
```

### Step 7 — Create Release Branch
```bash
git checkout -b release/<foss-name>-<upstream_version>-r1
git add projects/<foss-name>/
git add .cicd/jenkins_config.yml projects/docker-compose.all.yml
git commit -m "feat: add <foss-name> <upstream_version> as monorepo subproject"
```

## Validation
- [ ] `projects/<foss-name>/` mirrors polyrepo structure
- [ ] All placeholders filled in package.json, Dockerfiles, Helm
- [ ] Root CI pipeline includes new subproject stage
- [ ] `projects/docker-compose.all.yml` updated
- [ ] Script files translated to executable
- [ ] Source build compiles successfully

## Related
- Skill: `onboard-foss-project.md` — polyrepo equivalent
- Doc: `docs/monorepo.md`
