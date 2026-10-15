#!/usr/bin/env bash
# Shared helpers for every chapter demo. Source it from a chapter's run.sh:
#   source "$(dirname "$0")/../scripts/lib.sh"; demo_begin ch05-declare-and-restore
# Each demo runs in a fresh disposable workspace with its own HOME, so no
# user-level agent configuration or APM cache from your machine leaks in.
set -uo pipefail

APM_PINNED_VERSION="${APM_PINNED_VERSION:-0.33.0}"
REPO_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
PASS=0; FAIL=0; DEMO_ID=""; WORK=""; TRANSCRIPT=""; EVIDENCE=""

_norm() { sed -e "s#${WORK}#<workspace>#g" -e "s#${REPO_ROOT}#<demo-repo>#g"; }

demo_begin() {
  DEMO_ID="$1"
  WORK="$(mktemp -d "${TMPDIR:-/tmp}/raae-${DEMO_ID}-XXXXXX")"
  EVIDENCE="${REPO_ROOT}/evidence/${DEMO_ID}"
  mkdir -p "$EVIDENCE" "$WORK/home"
  TRANSCRIPT="$EVIDENCE/transcript.log"; : > "$TRANSCRIPT"
  # Keep the real binaries reachable, but isolate everything user-level.
  export REAL_HOME="${REAL_HOME:-$HOME}"
  export HOME="$WORK/home"
  export GIT_AUTHOR_NAME="Meridian Demo" GIT_AUTHOR_EMAIL="demo@meridian.example"
  export GIT_COMMITTER_NAME="Meridian Demo" GIT_COMMITTER_EMAIL="demo@meridian.example"
  export NO_COLOR=1 COLUMNS=120 PYTHONIOENCODING=utf-8
  git config --global init.defaultBranch main >/dev/null 2>&1
  git config --global advice.detachedHead false >/dev/null 2>&1
  DEMO_STARTED="$(date -u +%Y-%m-%dT%H:%M:%SZ)"
  local installed; installed="$(apm --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  {
    echo "demo: ${DEMO_ID}"
    echo "started_utc: ${DEMO_STARTED}"
    echo "apm_version: ${installed:-not-found}"
    echo "apm_pinned: ${APM_PINNED_VERSION}"
    echo "git: $(git --version 2>/dev/null)"
    echo "python: $(python3 --version 2>&1)"
    echo "os: $(. /etc/os-release 2>/dev/null; echo "${PRETTY_NAME:-unknown}") $(uname -m)"
  } > "$EVIDENCE/environment.txt"
  echo "== ${DEMO_ID} == workspace: <workspace> (fresh mktemp dir, isolated HOME)" | tee -a "$TRANSCRIPT"
  if [ "${installed}" != "${APM_PINNED_VERSION}" ]; then
    echo "FATAL: apm ${APM_PINNED_VERSION} required, found '${installed:-none}'" | tee -a "$TRANSCRIPT"; exit 2
  fi
  cd "$WORK"
}

# step "description" -- prints a heading into the transcript
step() { printf '\n## %s\n' "$*" | tee -a "$TRANSCRIPT"; }

# run CMD... -- echo the command, run it, append normalized output; sets LAST_RC and LAST_OUT (file)
run() {
  printf '$ %s\n' "$*" | _norm | tee -a "$TRANSCRIPT"
  LAST_OUT="$WORK/.last_out"
  "$@" > "$LAST_OUT" 2>&1; LAST_RC=$?
  _norm < "$LAST_OUT" | tee -a "$TRANSCRIPT" >/dev/null
  printf '[exit %s]\n' "$LAST_RC" >> "$TRANSCRIPT"
  return 0
}
# run_sh 'shell string' -- same as run, through bash -c
run_sh() { run bash -c "$1"; }

_ok()   { PASS=$((PASS+1)); echo "  PASS: $*" | tee -a "$TRANSCRIPT"; }
_bad()  { FAIL=$((FAIL+1)); echo "  FAIL: $*" | tee -a "$TRANSCRIPT"; }
expect_rc()          { [ "$LAST_RC" = "$1" ] && _ok "exit code $1${2:+ ($2)}" || _bad "expected exit $1, got $LAST_RC${2:+ ($2)}"; }
expect_rc_nonzero()  { [ "$LAST_RC" != "0" ] && _ok "non-zero exit ($LAST_RC)${1:+ ($1)}" || _bad "expected non-zero exit${1:+ ($1)}"; }
expect_out()         { grep -Eq -- "$1" "$LAST_OUT" && _ok "output matches /$1/" || _bad "output missing /$1/"; }
expect_no_out()      { grep -Eq -- "$1" "$LAST_OUT" && _bad "output unexpectedly matches /$1/" || _ok "output does not match /$1/"; }
expect_file()        { [ -e "$1" ] && _ok "exists: $1" || _bad "missing: $1"; }
expect_no_file()     { [ ! -e "$1" ] && _ok "absent: $1" || _bad "unexpectedly present: $1"; }
expect_in_file()     { grep -Eq -- "$2" "$1" 2>/dev/null && _ok "$1 matches /$2/" || _bad "$1 missing /$2/"; }
expect_not_in_file() { grep -Eq -- "$2" "$1" 2>/dev/null && _bad "$1 unexpectedly matches /$2/" || _ok "$1 does not match /$2/"; }
expect_same()        { cmp -s "$1" "$2" && _ok "identical: $1 == $2" || _bad "differ: $1 vs $2"; }

# keep_artifact PATH [NAME] -- copy a file produced in the workspace into evidence/
keep_artifact() { local n="${2:-$(basename "$1")}"; mkdir -p "$EVIDENCE/artifacts"; cp -r "$1" "$EVIDENCE/artifacts/$n" 2>/dev/null || true; }

demo_end() {
  local status="passed"; [ "$FAIL" -gt 0 ] && status="failed"
  cat > "$EVIDENCE/result.json" <<EOF
{"demo": "${DEMO_ID}", "status": "${status}", "checks_passed": ${PASS}, "checks_failed": ${FAIL},
 "apm_version": "$(apm --version 2>/dev/null | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1)",
 "started_utc": "${DEMO_STARTED}", "finished_utc": "$(date -u +%Y-%m-%dT%H:%M:%SZ)"}
EOF
  echo "== ${DEMO_ID}: ${status} (${PASS} passed, ${FAIL} failed) ==" | tee -a "$TRANSCRIPT"
  cd /; [ -z "${KEEP_WORKSPACE:-}" ] && rm -rf "$WORK"
  [ "$FAIL" -eq 0 ]
}
