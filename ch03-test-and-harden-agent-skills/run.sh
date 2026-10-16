#!/usr/bin/env bash
# Chapter 3: Test and Harden Agent Skills
# Runs Meridian's regression suite for meridian-code-review against the
# published v1.0.0 tag (expected: the suite catches the known defects) and
# the v1.0.1 tag (expected: everything passes), proves the suite can fail
# (negative controls), validates the skill, shows why the suite lives outside
# the package, and checks the committed harness evidence. Harness tests in
# real agents run only with RUN_HARNESS_TESTS=1 and model credentials.
source "$(dirname "$0")/../scripts/lib.sh"
demo_begin ch03-test-and-harden-agent-skills

DEMO_DIR="$REPO_ROOT/ch03-test-and-harden-agent-skills"
SUITE="$REPO_ROOT/tests/meridian-code-review/run_suite.py"
FIX="$REPO_ROOT/tests/meridian-code-review/fixtures"
PKG="vibeprogrammer/Reproducible-AI-Agent-Environments-demo/packages/meridian-code-review"
V101_COMMIT="1d8dbb13d4c7ad66cd7cfb92b24b673f4b564fbf"
SKILLS_REF_COMMIT="69ef37e9424c0a7ea9dd2293b559e43ec8176379"
export APM_PROGRESS=never

install_tag() {  # install_tag DIR TAG -- clean project, real APM install
  mkdir -p "$1" && (cd "$1" && git init -q . &&
    apm install "$PKG#$2" --target claude,codex < /dev/null > install.log 2>&1)
}

# ---------------------------------------------------------------------------
step "1. Install the published v1.0.0 and run the suite on the installed copy"
install_tag v100 meridian-code-review-v1.0.0
run_sh 'grep -E "resolved_ref|resolved_commit" v100/apm.lock.yaml'
expect_out 'resolved_commit: d77ad927023f2b227bd130c2f436866cc07b2e9e'
run python3 "$SUITE" --skill-dir v100/.claude/skills/meridian-code-review \
  --json v100-suite.json
expect_rc 1 "the suite fails on v1.0.0"
expect_out 'FAIL  help-documents-diff-semantics'
expect_out 'FAIL  fixture:unchanged-line-after-deletion'
expect_out 'FAIL  fixture:non-utf8-input-is-input-error'
expect_out '26 checks, 23 passed, 3 failed'
keep_artifact v100-suite.json suite-v1.0.0.json

step "2. The two checker defects, shown directly on v1.0.0"
run python3 v100/.claude/skills/meridian-code-review/scripts/check_money_rules.py \
  --diff "$FIX/context-after-deletion.diff"
expect_rc 1 "v1.0.0 reports an unchanged line"
expect_out 'MR001 decimal literal assigned to a money field'
run_sh "python3 v100/.claude/skills/meridian-code-review/scripts/check_money_rules.py --diff '$FIX/non-utf8.diff' 2>&1 | tail -1"
expect_out "UnicodeDecodeError"
run_sh "python3 v100/.claude/skills/meridian-code-review/scripts/check_money_rules.py --diff '$FIX/non-utf8.diff' >/dev/null 2>&1; echo exit=\$?"
expect_out '^exit=1$'

# ---------------------------------------------------------------------------
step "3. Install v1.0.1 and run the same suite"
install_tag v101 meridian-code-review-v1.0.1
run_sh 'grep -E "resolved_ref|resolved_commit" v101/apm.lock.yaml'
expect_out "resolved_commit: ${V101_COMMIT}"
run python3 "$SUITE" --skill-dir v101/.claude/skills/meridian-code-review \
  --expect-version 1.0.1 --json v101-suite.json
expect_rc 0 "the suite passes on v1.0.1"
expect_out '27 checks, 27 passed, 0 failed'
run python3 "$SUITE" --skill-dir v101/.agents/skills/meridian-code-review \
  --expect-version 1.0.1
expect_rc 0 "same result on the copy APM deployed for Codex"
keep_artifact v101-suite.json suite-v1.0.1.json
S101=v101/.claude/skills/meridian-code-review/scripts/check_money_rules.py
run python3 "$S101" --diff "$FIX/context-after-deletion.diff"
expect_rc 0
run python3 "$S101" --diff "$FIX/non-utf8.diff"
expect_rc 2 "input error, not findings"
expect_out 'error: input is not UTF-8'
run python3 "$S101" --diff "$FIX/deleted-key.diff"
expect_rc 1
expect_out 'MR002 payment/charge/refund created without an idempotency key'
run_sh "python3 '$S101' --help | sed -n '/--diff FILE/,/--files/p'"
expect_out 'MR002'

# ---------------------------------------------------------------------------
step "4. Negative controls: the suite must fail on planted defects"
cp -r v101/.claude/skills/meridian-code-review planted
rm planted/references/false-positives.md
python3 - planted/scripts/check_money_rules.py <<'PY'
import sys, pathlib
p = pathlib.Path(sys.argv[1]); s = p.read_text()
s = s.replace("def main(argv=None):", "def main(argv=None):\n"
  "    open('leak.txt', 'w').write('x')\n"
  "    import socket\n"
  "    try:\n"
  "        socket.create_connection(('127.0.0.1', 9), timeout=1)\n"
  "    except OSError:\n"
  "        pass", 1)
p.write_text(s)
PY
sed -i 's/^version: 1.0.1/version: 1.0.2/' planted/apm.yml
run python3 "$SUITE" --skill-dir planted
expect_rc 1
expect_out 'FAIL  version-consistent'
expect_out 'FAIL  referenced-files-exist .*missing: references/false-positives.md'
expect_out 'FAIL  no-write-network-or-subprocess-events'
expect_out 'FAIL  working-dir-unchanged'

# ---------------------------------------------------------------------------
step "5. Spec validation (skills-ref) and APM's content scan"
python3 -m venv .venv >/dev/null 2>&1
./.venv/bin/pip install --quiet --disable-pip-version-check \
  "git+https://github.com/agentskills/agentskills@${SKILLS_REF_COMMIT}#subdirectory=skills-ref" \
  > pip.log 2>&1
cp -r v101/.claude/skills/meridian-code-review meridian-code-review
run ./.venv/bin/skills-ref validate meridian-code-review
expect_rc 0
expect_out 'Valid skill'
run_sh 'cd meridian-code-review && apm audit --file SKILL.md'
expect_rc 0
expect_out 'no issues found'

# ---------------------------------------------------------------------------
step "6. Why the suite lives outside the package folder"
cp -r v101/.claude/skills/meridian-code-review pkg-with-tests
mkdir -p pkg-with-tests/tests && cp "$FIX/bad.diff" pkg-with-tests/tests/
mkdir consumer && (cd consumer && git init -q . &&
  apm install ../pkg-with-tests --target claude < /dev/null > install.log 2>&1)
run_sh 'cd consumer && find .claude/skills -type f | sort'
expect_out 'tests/bad.diff'
run_sh 'cd v101 && find .claude/skills -type f | sort'
expect_no_out '/tests/'

# ---------------------------------------------------------------------------
step "7. Behavioural tests in real harnesses (Claude Code, Codex CLI)"
H="$DEMO_DIR/harness"
if [ "${RUN_HARNESS_TESTS:-}" = "1" ] && { [ -n "${ANTHROPIC_API_KEY:-}" ] || [ -n "${OPENAI_API_KEY:-}" ]; }; then
  run python3 "$H/run_harness_tests.py" --ref meridian-code-review-v1.0.1 \
    --runs "${HARNESS_RUNS:-3}" --out "$WORK/harness-live"
  expect_rc 0
  keep_artifact "$WORK/harness-live/results.json" harness-live-results.json
else
  echo "  skipped: harness runs (set RUN_HARNESS_TESTS=1 and ANTHROPIC_API_KEY" \
       "and/or OPENAI_API_KEY; see README)" | tee -a "$TRANSCRIPT"
fi
for v in v1.0.0 v1.0.1; do
  R="$REPO_ROOT/evidence/ch03-test-and-harden-agent-skills/harness/$v/results.json"
  run python3 "$H/summarize.py" "$R"
  expect_rc 0
  expect_out '2\.1\.301 \(Claude Code\)'
  expect_out 'codex-cli 0\.163\.0'
  expect_out "ref: meridian-code-review-$v"
done

# ---------------------------------------------------------------------------
step "8. CI wiring for the skill's repository"
run_sh "cd '$REPO_ROOT' && sed -n '/^on:/,/^permissions:/p;/run_suite.py/p' .github/workflows/meridian-code-review-tests.yml"
expect_rc 0
expect_out 'packages/meridian-code-review/\*\*'
expect_out 'tests/meridian-code-review/run_suite.py'

demo_end
