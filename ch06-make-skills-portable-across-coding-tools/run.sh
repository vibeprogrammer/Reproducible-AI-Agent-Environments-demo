#!/usr/bin/env bash
# Chapter 6 demo: install the same Meridian package set to every target
# APM v0.33.0 supports, one target at a time and all together; record where
# each primitive lands; build the compatibility matrix from those runs; and,
# when credentials are present, check what Claude Code and Codex CLI
# actually discover. Run from the demo repo root:
#   bash ch06-make-skills-portable-across-coding-tools/run.sh
HERE="$(cd "$(dirname "$0")" && pwd)"
source "$HERE/../scripts/lib.sh"
demo_begin ch06-make-skills-portable-across-coding-tools

TOOL="python3 $HERE/matrix_tool.py"
HCHECK="python3 $HERE/harness_check.py"
FIXTURE="$HERE/fixture/meridian-checkout"
PKGS="$HERE/fixture/agent-packages"   # tool-specific notes packages
RUNS="${HARNESS_RUNS:-3}"
TRIALS="$WORK/trials"; HOUT="$WORK/harness"; mkdir -p "$TRIALS" "$HOUT"

# Stable targets: the 12 canonical names apm.yml accepts, plus vscode
# (alias of copilot that adds VS Code's MCP file) and intellij (MCP-only
# adapter; files go through the Copilot profile).
STABLE="copilot vscode intellij claude cursor codex gemini antigravity \
opencode windsurf kiro grok-build hermes agent-skills"
# Experimental, file-based targets we can exercise here. copilot-app and
# copilot-cowork need the desktop app / Microsoft 365 and are not run.
EXPERIMENTAL="grok-cloud openclaw"

skill_dir() {
  case "$1" in
    claude) echo .claude/skills ;; kiro) echo .kiro/skills ;;
    grok-build|grok-cloud) echo .grok/skills ;; *) echo .agents/skills ;;
  esac
}
# Targets without an MCP client make the install exit 1 because the
# package set declares an MCP server.
expected_rc() {
  case "$1" in grok-build|agent-skills|grok-cloud|openclaw) echo 1 ;; *) echo 0 ;; esac
}

# fresh DIR: a new copy of the fixture with its own isolated HOME and git repo
fresh() {
  rm -rf "$1"; mkdir -p "$1/home"
  cp -r "$FIXTURE" "$1/project"; cp -r "$PKGS" "$1/agent-packages"
  mv "$1/project/gitignore.txt" "$1/project/.gitignore"
  ( cd "$1/project" && git init -q . && git add -A && git commit -qm fixture )
  HOME="$1/home" git config --global init.defaultBranch main
}

# install_trial TARGET: fresh copy, install for one target, record what changed
install_trial() {
  local t="$1" d="$TRIALS/$1"
  fresh "$d"
  [ -n "${2:-}" ] && run_sh "HOME='$d/home' apm experimental enable $t"
  $TOOL snap "$d" "$d/before.json"
  run_sh "cd '$d/project' && set -o pipefail && HOME='$d/home' \
apm install --target $t 2>&1 | $TOOL clean"
  echo "$LAST_RC" > "$d/rc"; cp "$LAST_OUT" "$d/install.log"
  $TOOL snap "$d" "$d/after.json"
  $TOOL diff "$d/before.json" "$d/after.json" "$d/files.txt"
  expect_rc "$(expected_rc "$t")" "install --target $t"
  expect_file "$d/project/$(skill_dir "$t")/meridian-code-review/SKILL.md"
  if grep -q "Run 'apm compile'" "$d/install.log"; then
    cp -r "$d/project" "$d/installed-only"
    $TOOL snap "$d" "$d/before-compile.json"
    run_sh "cd '$d/project' && set -o pipefail && HOME='$d/home' \
apm compile --target $t 2>&1 | $TOOL clean"
    cp "$LAST_OUT" "$d/compile.log"
    $TOOL snap "$d" "$d/after-compile.json"
    $TOOL diff "$d/before-compile.json" "$d/after-compile.json" "$d/compile-files.txt"
    expect_rc 0 "compile --target $t"
  fi
  mkdir -p "$EVIDENCE/artifacts/targets/$t"
  for f in install.log files.txt rc compile.log compile-files.txt; do
    [ -f "$d/$f" ] && sed -e "s#$WORK#<workspace>#g" "$d/$f" \
      > "$EVIDENCE/artifacts/targets/$t/$f"
  done
  return 0
}

step "APM version and the targets command"
run apm --version
expect_out "0\.33\.0"
run apm targets --help
expect_out "Show resolved targets"

step "Target detection: no markers, then a .cursor/ folder and a CLAUDE.md"
fresh "$WORK/detect"
cd "$WORK/detect/project"
# Remove the targets: block so APM falls back to auto-detection.
python3 - <<'PY'
import re
s = open("apm.yml").read()
s = re.sub(r"\ntargets:\n(  - .*\n)+", "\n", s)
open("apm.yml", "w").write(s)
PY
expect_not_in_file apm.yml "^targets:"
run apm targets
expect_out "claude +inactive +needs CLAUDE.md"
run_sh "HOME='$WORK/detect/home' apm install 2>&1 | $TOOL clean; exit \${PIPESTATUS[0]}"
expect_rc 2 "install with nothing to detect"
expect_no_file apm.lock.yaml
mkdir .cursor && printf '# Notes for humans\n' > CLAUDE.md
run apm targets
expect_out "claude +active +CLAUDE.md"
expect_out "cursor +active +\.cursor/"
run apm targets --json
expect_out '"target": "cursor"'
cd "$WORK/detect/project"
cp "$FIXTURE/apm.yml" apm.yml
# Observed on v0.33.0: apm targets reports filesystem detection only; it does
# not reflect targets: from apm.yml (install does, see below).
run apm targets
expect_out "copilot +inactive"

cd "$WORK"

step "One target at a time (stable targets)"
for t in $STABLE; do install_trial "$t"; done

step "One target at a time (experimental targets, flag enabled in the run's HOME)"
for t in $EXPERIMENTAL; do install_trial "$t" enable; done
expect_in_file "$TRIALS/openclaw/install.log" "Skill integrated -> \.agents/skills/"

step "Isolation: tool-specific notes reach only their tool"
expect_file "$TRIALS/claude/project/.claude/rules/claude-code-notes.md"
expect_no_file "$TRIALS/claude/project/.claude/rules/cursor-notes.md"
expect_file "$TRIALS/cursor/project/.cursor/rules/cursor-notes.mdc"
expect_no_file "$TRIALS/cursor/project/.cursor/rules/claude-code-notes.mdc"
expect_in_file "$TRIALS/copilot/install.log" "Package targets \[claude\] do not overlap"
expect_in_file "$TRIALS/copilot/install.log" "Per-dependency targets \[cursor\] do not overlap"
expect_not_in_file "$TRIALS/copilot/files.txt" "notes"

step "Together: Meridian's declared targets (apm.yml targets:)"
fresh "$WORK/together"
cd "$WORK/together/project"
run_sh "set -o pipefail; HOME='$WORK/together/home' apm install 2>&1 | $TOOL clean"
expect_rc 0
expect_out "Targets: claude, copilot, cursor +\(source: apm\.yml\)"
expect_file .agents/skills/meridian-code-review/SKILL.md
expect_file .claude/skills/meridian-code-review/SKILL.md
expect_file .github/instructions/money-handling.instructions.md
expect_file .claude/rules/money-handling.md
expect_file .cursor/rules/money-handling.mdc
expect_file .claude/rules/claude-code-notes.md
expect_file .cursor/rules/cursor-notes.mdc
expect_no_file .github/instructions/cursor-notes.instructions.md
expect_no_file .github/instructions/claude-code-notes.instructions.md
run_sh "find . -name SKILL.md -path '*meridian-code-review*' -not -path './apm_modules/*' | sort"
expect_out "^\./\.agents/skills/meridian-code-review/SKILL\.md$"
keep_artifact "$LAST_OUT" together-meridian-skill-copies.txt
keep_artifact apm.lock.yaml together-meridian-apm.lock.yaml
# Observed on v0.33.0: install honours the notes packages' target limits,
# but apm compile folds every installed dependency's instructions into
# AGENTS.md, including the Claude-only and Cursor-only notes.
run_sh "set -o pipefail; HOME='$WORK/together/home' apm compile --target codex 2>&1 | $TOOL clean"
expect_rc 0
expect_in_file AGENTS.md "\.claude/skills/meridian-code-review/"
expect_in_file AGENTS.md "\.agents/skills/meridian-code-review/"
keep_artifact AGENTS.md together-compiled-AGENTS.md
cd "$WORK"

step "Together: every stable target in one install"
fresh "$WORK/all-stable"
cd "$WORK/all-stable/project"
ALL_CSV="$(echo $STABLE | tr ' ' ',')"
run_sh "set -o pipefail; HOME='$WORK/all-stable/home' apm install --target $ALL_CSV 2>&1 | $TOOL clean"
expect_rc 0 "MCP-capable targets in the set, so no MCP failure"
run_sh "find . -name SKILL.md -path '*meridian-code-review*' -not -path './apm_modules/*' | sort"
expect_out "\.agents/skills/meridian-code-review"
expect_out "\.claude/skills/meridian-code-review"
expect_out "\.kiro/skills/meridian-code-review"
expect_out "\.grok/skills/meridian-code-review"
keep_artifact "$LAST_OUT" all-stable-skill-copies.txt
cd "$WORK"

step "Together: --target all"
fresh "$WORK/all"
cd "$WORK/all/project"
run_sh "set -o pipefail; HOME='$WORK/all/home' apm install --target all 2>&1 | $TOOL clean"
expect_rc 0
expect_out "\[i\] Targets: "
expect_no_out "Targets: [^\n]*hermes"
expect_no_out "Targets: [^\n]*antigravity"
cd "$WORK"

step "Runtime discovery in real harnesses (skipped without credentials)"
# Harness workspaces are copies of the single-target installs above.
cp -r "$TRIALS/claude/project" "$HOUT/claude"
cp -r "$TRIALS/codex/project" "$HOUT/codex"
cp -r "$TRIALS/codex/installed-only" "$HOUT/codex-installed-only"
cp -r "$TRIALS/copilot/project" "$HOUT/copilot-for-claude"
cp -r "$TRIALS/claude/project" "$HOUT/claude-for-codex"
mkdir -p "$HOUT/results"
for c in inventory skill-used instructions-always instructions-money \
         instructions-money-after-read; do
  run $HCHECK claude "$HOUT/claude" "$c" "$RUNS" "$HOUT/results/claude"
  expect_rc 0
done
run $HCHECK claude "$HOUT/copilot-for-claude" inventory 1 "$HOUT/results/copilot-for-claude"
for c in skill-listed skill-used instructions-money; do
  run $HCHECK codex "$HOUT/codex" "$c" "$RUNS" "$HOUT/results/codex"
  expect_rc 0
done
run $HCHECK codex "$HOUT/codex-installed-only" instructions-money "$RUNS" "$HOUT/results/codex-installed-only"
run $HCHECK codex "$HOUT/claude-for-codex" skill-listed "$RUNS" "$HOUT/results/claude-for-codex"
mkdir -p "$EVIDENCE/artifacts/harness"
rm -f "$EVIDENCE/artifacts/harness/"*.json
for f in "$HOUT"/results/*/*.json; do
  n="$(basename "$(dirname "$f")")--$(basename "$f")"
  sed -e "s#$WORK#<workspace>#g" "$f" > "$EVIDENCE/artifacts/harness/$n"
done
# The Claude Code start-up inventory is deterministic: assert it when it ran.
INV="$HOUT/results/claude/claude-inventory.json"
if grep -q '"status": "ran"' "$INV"; then
  expect_in_file "$INV" '"passed": 3'
fi

step "Build the compatibility matrix from the runs"
mkdir -p "$WORK/hflat"
for f in "$HOUT"/results/*/*.json; do cp "$f" "$WORK/hflat/$(basename "$(dirname "$f")")--$(basename "$f")"; done
cd "$WORK"
run $TOOL matrix "$TRIALS" "$WORK/hflat" compatibility-matrix
expect_rc 0
expect_in_file compatibility-matrix.md "^\| claude \| skill, instructions, prompt as command, agent, hook, MCP \|"
expect_in_file compatibility-matrix.md "^\| codex \| skill, instructions \(compiled\), agent, hook, MCP \|"
expect_in_file compatibility-matrix.md "^\| agent-skills \| skill \(exit 1\) \|"
expect_in_file compatibility-matrix.md "^\| gemini \|.*unverified \|$"
sed -e "s#$WORK#<workspace>#g" compatibility-matrix.md > "$EVIDENCE/compatibility-matrix.md"
sed -e "s#$WORK#<workspace>#g" compatibility-matrix.json > "$EVIDENCE/compatibility-matrix.json"
run cat compatibility-matrix.md

demo_end
