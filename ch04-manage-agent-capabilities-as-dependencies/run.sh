#!/usr/bin/env bash
# Chapter 4 demo: inspect a real public dependency graph with APM v0.33.0.
# Run from the demo repo root:  bash ch04-manage-agent-capabilities-as-dependencies/run.sh
# Needs: apm 0.33.0 on PATH, git, python3, and anonymous HTTPS access to github.com.
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../scripts/lib.sh"
demo_begin ch04-manage-agent-capabilities-as-dependencies
# Plain, non-animated CLI output so the transcript stays readable.
export CI=true TERM=dumb

summarize_lock() { python3 "$HERE/lock_summary.py" "${1:-apm.lock.yaml}"; }

# ---------------------------------------------------------------------------
step "1. A manifest with two direct dependencies (graph-lab)"
mkdir graph-lab && cd graph-lab && git init -q .
cp "$HERE/fixtures/graph-lab/apm.yml" apm.yml
run cat apm.yml
expect_rc 0

step "2. Resolve and install the graph"
run apm install
expect_rc 0 "install succeeds"
expect_out "1 dependency unpinned: github/awesome-copilot"
expect_file apm.lock.yaml
expect_file .agents/skills/autopilot-comment/SKILL.md
expect_file .agents/skills/review-and-refactor/SKILL.md
keep_artifact apm.lock.yaml graph-lab.apm.lock.yaml

step "3. What the lockfile recorded, one line per package"
run summarize_lock
expect_rc 0
expect_out "depth=1  microsoft/apm-sample-package  ref=v1.0.0  commit=fb2851683be0"
expect_out "depth=1  microsoft/apm/packages/autopilot/autopilot-pr-review-scheduler  ref=v0.33.0  commit=18c4c43c924c"
expect_out "depth=2  github/awesome-copilot/skills/review-and-refactor  ref=\(none\)"
expect_out "resolved_by=microsoft/apm-sample-package"
expect_out "depth=3  microsoft/apm/packages/autopilot/autopilot-comment  ref=v0.33.0  commit=18c4c43c924c"
cp "$LAST_OUT" "$WORK/graph-lab.lock-summary.txt"; keep_artifact "$WORK/graph-lab.lock-summary.txt"
run_sh "grep -c 'content_hash: sha256:' apm.lock.yaml"
expect_rc 0 "lock records content hashes"

step "4. The tree: direct versus transitive"
run apm deps tree
expect_rc 0
expect_out "autopilot-pr-review-worker@0.1.0"
expect_out "autopilot-comment@0.1.0"
expect_out "review-and-refactor"

step "5. Why is a transitive package here? (cross-repo edge)"
run apm deps why github/awesome-copilot/skills/review-and-refactor
expect_rc 0
expect_out "microsoft/apm-sample-package"
expect_out "transitive"

step "6. Why, for a sub-package of the same monorepo (observed v0.33.0 behaviour)"
# The lock records resolved_by as the repository (microsoft/apm), not the
# virtual sub-package, so the chain stops at the repository name.
run apm deps why microsoft/apm/packages/autopilot/autopilot-comment --json
expect_rc 0
expect_out '"is_direct": false'
expect_no_out "autopilot-pr-review-scheduler"
run apm deps why autopilot-comment
expect_out "not installed"

step "7. Remote versions and local metadata"
run apm view microsoft/apm-sample-package versions
expect_rc 0
expect_out "v1\.0\.0 +│ tag +│ fb285168"
run apm view microsoft/apm/packages/autopilot/autopilot-pr-review-worker
expect_rc 0
expect_out "Ref: v0\.33\.0"
expect_out "Commit: 18c4c43c924c"

step "8. The package boundary ships whole"
# A HYBRID package (SKILL.md + apm.yml) is copied as one directory,
# including its evals and its own apm.yml.
run_sh "find .agents/skills/autopilot-pr-review-worker -maxdepth 2 | sort"
expect_rc 0
expect_file .agents/skills/autopilot-pr-review-worker/apm.yml
expect_file .agents/skills/autopilot-pr-review-worker/evals/render_eval.py

step "9. Replay on a clean checkout: the lock wins over the floating ref"
cp apm.lock.yaml "$WORK/lock.before"
run_sh "rm -rf apm_modules .agents .github && ls -A"
run apm install --frozen
expect_rc 0 "frozen install from the lock"
expect_same apm.lock.yaml ../lock.before
run_sh "grep -B3 'virtual_path: skills/review-and-refactor' apm.lock.yaml | grep resolved_commit"
expect_rc 0
cd "$WORK"

# ---------------------------------------------------------------------------
step "10. Two paths, two commits, one package (diamond-lab)"
mkdir diamond-lab && cd diamond-lab && git init -q .
cp "$HERE/fixtures/diamond-lab/apm.yml" apm.yml
run apm install
expect_rc_nonzero "install refuses the conflict"
expect_out "incompatible immutable requirements"
expect_out "autopilot-comment@v0\.32\.0"
expect_out "autopilot-pr-review-worker@v0\.33\.0 ->"
expect_no_file apm.lock.yaml
cd "$WORK"

# ---------------------------------------------------------------------------
step "11. Semver ranges on Git sources (range-lab)"
mkdir range-lab && cd range-lab && git init -q .
cp "$HERE/fixtures/range-lab/apm.yml" apm.yml
run apm install
expect_rc 0
keep_artifact apm.lock.yaml range-lab.apm.lock.yaml
run summarize_lock
expect_out "meridian-code-review  ref=meridian-code-review-v1\.[0-9]+\.[0-9]+ .*constraint=\^1\.0\.0"
expect_out "autopilot-comment  ref=v0\.32\.0 .*version=0\.32\.0 .*constraint=~0\.32\.0"
cp "$LAST_OUT" "$WORK/range-lab.lock-summary.txt"; keep_artifact "$WORK/range-lab.lock-summary.txt"
run_sh "head -3 apm_modules/microsoft/apm/packages/autopilot/autopilot-comment/apm.yml"
expect_out "version: 0\.1\.0"
run_sh "grep -E '^lockfile_version' apm.lock.yaml"
expect_out "lockfile_version: '2'"
cd "$WORK"

demo_end
