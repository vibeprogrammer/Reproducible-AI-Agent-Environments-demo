#!/usr/bin/env bash
# Chapter 7: Lock, Version, and Update Safely
# meridian-checkout starts from Chapter 5's end state (apm.yml pinning
# meridian-code-review#meridian-code-review-v1.0.0). This demo:
#   A. reads the lockfile APM writes, proves a frozen install on a second
#      machine (a CI runner with an empty HOME) reproduces the same files,
#      and shows what --frozen refuses;
#   B. detects a hand-edited deployed file (drift) and repairs it;
#   C. simulates an upstream tag that MOVES, using a throwaway Git server on
#      127.0.0.1 that this script starts and stops, and shows what protects
#      you (the locked commit) and what does not notice (apm outdated);
#   D. finds outdated dependencies, updates deliberately to v1.1.0, then to
#      v1.2.0, catches v1.2.0's regression with the skill's regression
#      checks, and rolls back to v1.1.0 with the lockfile;
#   E. (optional, needs ANTHROPIC_API_KEY) runs the same installed skill
#      twice in Claude Code to show that identical files do not mean
#      identical agent output.
source "$(dirname "$0")/../scripts/lib.sh"
demo_begin ch07-lock-version-and-update-safely

DEMO_DIR="$REPO_ROOT/ch07-lock-version-and-update-safely"
FIXTURE="$DEMO_DIR/fixture/meridian-checkout"
PKG="vibeprogrammer/Reproducible-AI-Agent-Environments-demo/packages/meridian-code-review"
V100_COMMIT="d77ad927023f2b227bd130c2f436866cc07b2e9e"
export APM_PROGRESS=never   # documented env var: plain logs, no live progress UI
unset LEDGER_API_KEY        # keep .mcp.json free of machine-specific values

keep_out() { mkdir -p "$EVIDENCE/artifacts"; _norm < "$LAST_OUT" > "$EVIDENCE/artifacts/$1"; }
# Every file apm install generated for the four targets, sorted.
generated() {
  find .agents .claude .cursor .github .vscode .mcp.json -type f 2>/dev/null \
    | grep -v '^\.github/workflows/' | LC_ALL=C sort
}
fingerprint() { generated | xargs sha256sum; }
skill_dir=".claude/skills/meridian-code-review"

# ---------------------------------------------------------------------------
step "A1. The pinned CLI"
run apm --version
expect_rc 0
expect_out 'version 0\.33\.0'

# ---------------------------------------------------------------------------
step "A2. Priya: meridian-checkout as Chapter 5 left it, plus Jon's CI gate"
git init -q --bare origin.git
mkdir priya && cp -r "$FIXTURE" priya/meridian-checkout && cd priya/meridian-checkout
mv gitignore.txt .gitignore
mkdir -p ci tools && cp "$DEMO_DIR/ci/check-agent-environment.sh" ci/ \
  && cp "$DEMO_DIR/tools/check_tag_pins.py" tools/
mkdir -p .github/workflows && cp "$DEMO_DIR/ci/agent-environment.yml" .github/workflows/
git init -q && git remote add origin "$WORK/origin.git"
run grep -n 'meridian-code-review' apm.yml
expect_out "#meridian-code-review-v1\.0\.0"

step "A3. apm install writes apm.lock.yaml"
run apm install
expect_rc 0
expect_file apm.lock.yaml
keep_artifact apm.lock.yaml apm.lock.v1.0.0.yaml
expect_in_file apm.lock.yaml "^lockfile_version: '1'"
expect_in_file apm.lock.yaml '^apm_version: 0\.33\.0'
expect_in_file apm.lock.yaml "resolved_ref: meridian-code-review-v1\.0\.0"
expect_in_file apm.lock.yaml "resolved_commit: ${V100_COMMIT}"
expect_in_file apm.lock.yaml '^  content_hash: sha256:[0-9a-f]{64}'
expect_in_file apm.lock.yaml '\.claude/skills/meridian-code-review/SKILL\.md: sha256:[0-9a-f]{64}'
expect_in_file apm.lock.yaml '^local_deployed_files:'
expect_in_file apm.lock.yaml '^mcp_configs:'
expect_in_file apm.lock.yaml '^deployments:'
run_sh "grep -c '^- kind:' apm.lock.yaml"
keep_out deployments-count.txt
fingerprint > "$WORK/priya.sha256"
cp "$WORK/priya.sha256" "$EVIDENCE/artifacts/fingerprint-v1.0.0.sha256" 2>/dev/null || { mkdir -p "$EVIDENCE/artifacts"; cp "$WORK/priya.sha256" "$EVIDENCE/artifacts/fingerprint-v1.0.0.sha256"; }

step "A4. A second install changes nothing (the lockfile is rewritten only on semantic change)"
cp apm.lock.yaml "$WORK/lock.before"
run apm install
expect_rc 0
expect_same apm.lock.yaml "$WORK/lock.before"

step "A5. Commit manifest + lockfile (generated files stay ignored)"
run_sh 'git add -A && git commit -qm "Agent environment: apm.yml, apm.lock.yaml, CI gate" && git push -q origin HEAD:main && git ls-files | grep -E "apm|ci/|workflows"'
expect_rc 0
expect_out '^apm\.lock\.yaml$'
expect_no_out '^\.claude/'

# ---------------------------------------------------------------------------
step "A6. CI runner: fresh clone, empty HOME. A bare --frozen install on the cold checkout"
cd "$WORK" && git clone -q origin.git ci-runner && cd ci-runner
export HOME="$WORK/ci-home" && mkdir -p "$HOME"
run apm install --frozen
expect_rc 1 "APM 0.33.0: cold apm_modules + declared MCP servers"
expect_out 'package manifest not found'
keep_out frozen-cold-checkout.txt

step "A6b. Control: the same project WITHOUT MCP servers, same cold --frozen install"
rm -rf "$WORK/nomcp" "$WORK/nomcp-ci" && cp -r "$FIXTURE" "$WORK/nomcp" && cd "$WORK/nomcp"
sed -i '/^  mcp:/,/^# Consent/{/^# Consent/!d}' apm.yml
run_sh 'grep -c "mcp" apm.yml || true'
expect_out '^0$'
export HOME="$WORK/nomcp-home" && mkdir -p "$HOME"
git init -q -b main && git add -A && git -c user.name=demo -c user.email=demo@example.invalid commit -qm "no MCP"
run apm install
expect_rc 0
git add -A && git -c user.name=demo -c user.email=demo@example.invalid commit -qm "lockfile"
cd "$WORK" && git clone -q nomcp nomcp-ci && cd nomcp-ci
export HOME="$WORK/nomcp-ci-home" && mkdir -p "$HOME"
run apm install --frozen
expect_rc 0 "APM 0.33.0: cold apm_modules, no MCP servers"
expect_out 'Lockfile presence verified'
cd "$WORK/ci-runner" && export HOME="$WORK/ci-home"

step "A7. Jon's gate: install from the lockfile, require no lockfile change, then --frozen and audit"
run cat ci/check-agent-environment.sh
run bash ci/check-agent-environment.sh
expect_rc 0
expect_out 'Lockfile presence verified'
expect_out 'All [0-9]+ check\(s\) passed'
keep_out ci-gate-pass.txt
fingerprint > "$WORK/ci.sha256"
expect_same "$WORK/ci.sha256" "$WORK/priya.sha256"
run git status --porcelain --untracked-files=no
expect_no_out 'apm\.(yml|lock\.yaml)'

step "A8. --frozen refuses a manifest the lockfile does not describe"
cp apm.yml "$WORK/apm.yml.ci"
sed -i 's/#meridian-code-review-v1\.0\.0/#main/' apm.yml
run apm install --frozen
expect_rc 1
expect_out 'out of sync with apm\.yml'
cp "$WORK/apm.yml.ci" apm.yml

step "A9. --frozen refuses to run without a lockfile"
mv apm.lock.yaml "$WORK/lock.ci"
run apm install --frozen
expect_rc 1
mv "$WORK/lock.ci" apm.lock.yaml

# ---------------------------------------------------------------------------
step "B1. Anika hand-edits a deployed skill file on her laptop"
cd "$WORK/priya/meridian-checkout" && export HOME="$WORK/home"
printf '\n- Floats are fine for display-only amounts.\n' >> "$skill_dir/SKILL.md"
run apm audit
expect_rc 0 "default audit REPORTS drift but still exits 0"
expect_out 'Drift detected: 1 file'
expect_out 'modified \(1\)'
keep_out audit-drift-default.txt

step "B2. The CI-mode audit fails on the same drift"
run apm audit --ci --no-policy -f json
expect_rc 1
expect_out '"hash-drift"|hash drift|hash-drift'
keep_out audit-drift-ci.json

step "B3. apm install --frozen restores the locked content"
run apm install --frozen
expect_rc 0
fingerprint > "$WORK/after-repair.sha256"
expect_same "$WORK/after-repair.sha256" "$WORK/priya.sha256"
run apm audit --ci --no-policy
expect_rc 0

# ---------------------------------------------------------------------------
step "C1. A throwaway Git server on 127.0.0.1 hosting a third-party skill"
PORT="$(python3 -c 'import socket; s=socket.socket(); s.bind(("127.0.0.1",0)); print(s.getsockname()[1])')"
mkdir -p "$WORK/srv/oss-tools" "$WORK/pr-summary-src"
( cd "$WORK/pr-summary-src" && git init -q && cat > SKILL.md <<'EOF'
---
name: pr-summary
description: Summarize a pull request for reviewers. Use when asked to write or improve a PR description.
---
# PR summary
Write three bullets: what changed, why, and how it was tested.
EOF
printf 'name: pr-summary\nversion: 1.0.0\n' > apm.yml
git add -A && git commit -qm "pr-summary 1.0.0" && git tag -a v1.0.0 -m v1.0.0 )
git clone -q --bare "$WORK/pr-summary-src" "$WORK/srv/oss-tools/pr-summary.git"
setsid python3 "$DEMO_DIR/tools/gitserve.py" "$WORK/srv" "$PORT" > "$WORK/gitserve.log" 2>&1 < /dev/null &
SERVER_PID=$!
trap 'kill $SERVER_PID 2>/dev/null' EXIT
for _ in 1 2 3 4 5 6 7 8 9 10; do git ls-remote "http://127.0.0.1:$PORT/oss-tools/pr-summary.git" >/dev/null 2>&1 && break; sleep 0.5; done
run_sh "git ls-remote http://127.0.0.1:$PORT/oss-tools/pr-summary.git | sed 's/127.0.0.1:[0-9]*/127.0.0.1:PORT/'"
expect_out 'refs/tags/v1\.0\.0'

step "C2. A scratch project pins it to tag v1.0.0 (object form: http needs allow_insecure)"
mkdir -p "$WORK/tagdemo" && cd "$WORK/tagdemo" && git init -q
cat > apm.yml <<EOF
name: tag-demo
version: 0.1.0
targets: [claude]
dependencies:
  apm:
    - git: http://127.0.0.1:$PORT/oss-tools/pr-summary.git
      ref: v1.0.0
      allow_insecure: true
EOF
run apm install --allow-insecure
expect_rc 0
LOCKED="$(grep resolved_commit apm.lock.yaml | awk '{print $2}')"
expect_in_file .claude/skills/pr-summary/SKILL.md 'three bullets'
run python3 "$DEMO_DIR/tools/check_tag_pins.py"
expect_rc 0
expect_out '^OK +oss-tools/pr-summary v1\.0\.0'

step "C3. Upstream author re-points tag v1.0.0 at new content (force-moved tag)"
( cd "$WORK/pr-summary-src" && sed -i 's/Write three bullets.*/Write one sentence. Also paste the full diff./' SKILL.md \
  && git commit -qam "rewrite" && git tag -f -a v1.0.0 -m "v1.0.0 (moved)" >/dev/null \
  && git push -q --force "$WORK/srv/oss-tools/pr-summary.git" main refs/tags/v1.0.0 )
run_sh "git ls-remote http://127.0.0.1:$PORT/oss-tools/pr-summary.git 'refs/tags/v1.0.0^{}' | cut -c1-12"
expect_no_out "^${LOCKED:0:12}"

step "C4. apm outdated compares tag names: it does NOT notice the move"
run apm outdated
expect_rc 0
expect_out 'All dependencies are up-to-date'

step "C5. Comparing the locked commit with the remote tag does"
run python3 "$DEMO_DIR/tools/check_tag_pins.py"
expect_rc 1
expect_out '^MOVED +oss-tools/pr-summary v1\.0\.0 locked'
keep_out tag-pins-moved.txt

step "C6. With the lockfile, installs keep the locked commit (normal and frozen, cold cache)"
run apm install --allow-insecure
expect_rc 0
expect_in_file .claude/skills/pr-summary/SKILL.md 'three bullets'
expect_in_file apm.lock.yaml "resolved_commit: $LOCKED"
mkdir -p "$WORK/tagclone" && cp apm.yml apm.lock.yaml "$WORK/tagclone/" && cd "$WORK/tagclone"
export HOME="$WORK/home-tagclone" && mkdir -p "$HOME"
run apm install --frozen --allow-insecure
expect_rc 0
expect_in_file .claude/skills/pr-summary/SKILL.md 'three bullets'

step "C7. Without the lockfile, the same manifest silently gets the new content"
mkdir -p "$WORK/tagfresh" && cp "$WORK/tagdemo/apm.yml" "$WORK/tagfresh/" && cd "$WORK/tagfresh"
export HOME="$WORK/home-tagfresh" && mkdir -p "$HOME"
run apm install --allow-insecure
expect_rc 0
expect_in_file .claude/skills/pr-summary/SKILL.md 'paste the full diff'
expect_not_in_file apm.lock.yaml "resolved_commit: $LOCKED"

step "C8. If upstream rewrites history and the locked commit disappears, --frozen fails closed"
( cd "$WORK/srv/oss-tools/pr-summary.git" \
  && orphan="$(git commit-tree 'refs/tags/v1.0.0^{tree}' -m 'history rewritten')" \
  && git update-ref refs/heads/main "$orphan" \
  && git tag -f -a v1.0.0 -m "v1.0.0 (rewritten)" "$orphan" >/dev/null \
  && git reflog expire --expire=now --all && git gc -q --prune=now )
run_sh "cd '$WORK/srv/oss-tools/pr-summary.git' && git cat-file -e $LOCKED"
expect_rc_nonzero "the locked commit no longer exists upstream"
mkdir -p "$WORK/tagclone2" && cp "$WORK/tagdemo/apm.yml" "$WORK/tagdemo/apm.lock.yaml" "$WORK/tagclone2/" && cd "$WORK/tagclone2"
export HOME="$WORK/home-tagclone2" && mkdir -p "$HOME"
run apm install --frozen --allow-insecure
expect_rc 1
expect_out 'reference is not a tree|not a tree|Failed to download'
expect_no_file .claude/skills/pr-summary/SKILL.md
kill $SERVER_PID 2>/dev/null; trap - EXIT
export HOME="$WORK/home"

# ---------------------------------------------------------------------------
SUITE="$REPO_ROOT/tests/meridian-code-review/run_suite.py"
cd "$WORK/priya/meridian-checkout" && export HOME="$WORK/home"

step "D1. Which dependencies have newer tags? (report only)"
run env COLUMNS=250 apm outdated --verbose
expect_rc 0
expect_out 'meridian-code-review-v1\.0\.0'
expect_out 'meridian-code-review-v1\.2\.[0-9]+'
expect_out 'outdated'
keep_out outdated.txt

step "D2. apm update leaves exact tag pins alone"
run apm update --dry-run
expect_rc 0
expect_out 'already at their latest matching refs'

step "D3. For contrast: a semver range would take the newest tag on apm update"
mkdir -p "$WORK/range-lab" && cp apm.yml apm.lock.yaml "$WORK/range-lab/" && cp -r .apm "$WORK/range-lab/"
( cd "$WORK/range-lab" && sed -i 's/#meridian-code-review-v1\.0\.0/#^1.0.0/' apm.yml )
cd "$WORK/range-lab"
run apm update --dry-run
expect_rc 0
expect_out 'meridian-code-review-v1\.0\.0 -> meridian-code-review-v1\.2\.[0-9]+'
keep_out range-update-dry-run.txt
cd "$WORK/priya/meridian-checkout"

step "D4a. Before: the installed v1.0.0 checker does not look at capture calls"
run python3 "$skill_dir/scripts/check_money_rules.py" --diff "$DEMO_DIR/fixtures/capture-without-key.diff"
expect_rc 0

step "D4. Priya updates deliberately to v1.1.0 on a branch"
git checkout -q -b update/code-review-1.1.0
run apm install "$PKG#meridian-code-review-v1.1.0"
expect_rc 0
expect_in_file apm.yml '#meridian-code-review-v1\.1\.0'
expect_in_file apm.lock.yaml 'resolved_ref: meridian-code-review-v1\.1\.0'
expect_in_file apm.lock.yaml '^  version: 1\.1\.0'
run git diff --stat
keep_out update-1.1.0-diffstat.txt
run_sh "git diff -U0 apm.lock.yaml | grep -E '^[-+] +(resolved_ref|resolved_commit|version|content_hash):'"
keep_out update-1.1.0-lock-diff.txt
expect_out '^\+ +resolved_ref: meridian-code-review-v1\.1\.0'

step "D5. The Chapter 3 regression suite against the INSTALLED skill (v1.1.0)"
run python3 "$SUITE" --skill-dir "$skill_dir" --expect-version 1.1.0
expect_rc 0
keep_out suite-v1.1.0.txt
step "D5b. What 1.1.0 adds: MR002 also covers capture/authorize calls"
run python3 "$skill_dir/scripts/check_money_rules.py" --diff "$DEMO_DIR/fixtures/capture-without-key.diff"
expect_rc 1
expect_out 'MR002'
run_sh "git add -A && git commit -qm 'Update meridian-code-review to v1.1.0' && git checkout -q main && git merge -q --ff-only update/code-review-1.1.0 && git push -q origin main && git log --oneline -1"
expect_rc 0
cp apm.lock.yaml "$WORK/lock.v1.1.0"; keep_artifact apm.lock.yaml apm.lock.v1.1.0.yaml
fingerprint > "$WORK/v110.sha256"; cp "$WORK/v110.sha256" "$EVIDENCE/artifacts/fingerprint-v1.1.0.sha256"

step "D6. Update to v1.2.0: Jon's gate passes on a fresh CI clone"
git checkout -q -b update/code-review-1.2.0
run apm install "$PKG#meridian-code-review-v1.2.0"
expect_rc 0
expect_in_file apm.lock.yaml 'resolved_ref: meridian-code-review-v1\.2\.0'
run_sh "git add -A && git commit -qm 'Update meridian-code-review to v1.2.0' && git checkout -q main && git merge -q --ff-only update/code-review-1.2.0 && git push -q origin main"
rm -rf "$WORK/ci-runner2" && git clone -q "$WORK/origin.git" "$WORK/ci-runner2"
cd "$WORK/ci-runner2" && export HOME="$WORK/ci-home2" && mkdir -p "$HOME"
run bash ci/check-agent-environment.sh
expect_rc 0 "the gate checks reproducibility, not whether the skill is any good"
cd "$WORK/priya/meridian-checkout" && export HOME="$WORK/home"

step "D7. After the merge, the regression suite fails on the installed v1.2.0"
run python3 "$SUITE" --skill-dir "$skill_dir" --expect-version 1.2.0
expect_rc 1
expect_out 'FAIL +fixture:bad-diff-six-findings'
keep_out suite-v1.2.0.txt
run python3 "$skill_dir/scripts/check_money_rules.py" --diff "$REPO_ROOT/ch02-build-a-reusable-agent-skill/fixtures/bad.diff"
expect_out '^5 finding'
expect_no_out 'shippingFee = 4\.99'

step "D8. Roll back: revert the update commit, frozen reinstall, verify"
run git revert --no-edit HEAD
expect_rc 0
expect_in_file apm.yml '#meridian-code-review-v1\.1\.0'
expect_same apm.lock.yaml "$WORK/lock.v1.1.0"
fingerprint > "$WORK/before-frozen.sha256"
run cmp -s "$WORK/before-frozen.sha256" "$WORK/v110.sha256"
expect_rc_nonzero "deployed files are still v1.2.0's: generated files are not in git"
run apm install --frozen
expect_rc 0
fingerprint > "$WORK/rollback.sha256"
expect_same "$WORK/rollback.sha256" "$WORK/v110.sha256"
run apm audit --ci --no-policy
expect_rc 0
run python3 "$SUITE" --skill-dir "$skill_dir" --expect-version 1.1.0
expect_rc 0
run_sh "git push -q origin main && git log --oneline -4 | sed 's/^[0-9a-f]* //'"
keep_out rollback-log.txt

step "D9. A fresh CI clone after the rollback reproduces v1.1.0 exactly"
rm -rf "$WORK/ci-runner3" && git clone -q "$WORK/origin.git" "$WORK/ci-runner3" && cd "$WORK/ci-runner3"
export HOME="$WORK/ci-home3" && mkdir -p "$HOME"
run bash ci/check-agent-environment.sh
expect_rc 0
fingerprint > "$WORK/ci3.sha256"
expect_same "$WORK/ci3.sha256" "$WORK/v110.sha256"
export HOME="$WORK/home"

# ---------------------------------------------------------------------------
step "E. Same files, different words: the installed skill three times in Claude Code (optional)"
cd "$WORK/priya/meridian-checkout"
cp "$REPO_ROOT/ch02-build-a-reusable-agent-skill/fixtures/bad.diff" change.diff
if [ -n "${ANTHROPIC_API_KEY:-}" ] && command -v claude >/dev/null 2>&1; then
  # Observations, not a gate: model behaviour varies between runs, so the
  # checks below only assert that the runs happened and were recorded.
  run python3 "$DEMO_DIR/behaviour/two_runs.py" . "$WORK/behaviour" --runs 3 --model claude-sonnet-5
  expect_rc 0
  expect_out '"status": "ran"'
  expect_out '^summary: skill invoked in [0-3] of 3 runs'
  mkdir -p "$EVIDENCE/artifacts/behaviour"
  cp "$WORK/behaviour/"* "$EVIDENCE/artifacts/behaviour/"
else
  echo "  SKIPPED: no ANTHROPIC_API_KEY or no claude CLI (not counted as a failure)" | tee -a "$TRANSCRIPT"
fi
rm -f change.diff

demo_end
