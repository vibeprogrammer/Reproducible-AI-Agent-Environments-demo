#!/usr/bin/env bash
# Runs every chapter demo in order and writes evidence/SUMMARY.md.
set -uo pipefail
cd "$(dirname "$0")"
rc=0; rows=""
for d in ch[0-9][0-9]-*/; do
  d="${d%/}"; [ -x "$d/run.sh" ] || continue
  echo ">>> $d"
  if bash "$d/run.sh"; then s=passed; else s=FAILED; rc=1; fi
  rows+="| ${d} | ${s} | [transcript](${d}/transcript.log) |"$'\n'
done
{
  echo "# Verification summary"
  echo
  echo "Run: $(date -u +%Y-%m-%dT%H:%M:%SZ) with apm $(apm --version | grep -Eo '[0-9]+\.[0-9]+\.[0-9]+' | head -1)"
  echo
  echo "| Demo | Result | Evidence |"
  echo "| --- | --- | --- |"
  printf '%s' "$rows"
} > evidence/SUMMARY.md
cat evidence/SUMMARY.md
exit $rc
