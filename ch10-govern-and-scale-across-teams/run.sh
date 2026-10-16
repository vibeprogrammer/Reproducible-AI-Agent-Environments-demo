#!/usr/bin/env bash
# Chapter 10 demo: govern and scale across teams (APM 0.33.0).
# Marta's rollout: an enterprise -> org -> repo policy chain, a warn-mode
# pilot across three meridian-finance repos, remediation and one recorded
# exception, the flip to block, tighten-only inheritance, and adoption
# metrics aggregated from the repos' lockfiles.
source "$(dirname "$0")/../scripts/lib.sh"
HERE="$(cd "$(dirname "$0")" && pwd)"
demo_begin ch10-govern-and-scale-across-teams

PKG=vibeprogrammer/Reproducible-AI-Agent-Environments-demo/packages
TODAY=2026-10-16   # fixed "as of" date for the metrics, so reruns compare
# Strip APM's progress-bar repaint lines from the transcript.
quiet() { sed -E '/ resolve |^\[[.#]+\]|\?25[hl]/d'; }
export -f quiet

step "A. Lay out the policy chain (enterprise -> org -> repo)"
# In production each file lives in a policy repo and extends: names it as
# owner/repo. Offline, extends: takes a file path, which APM 0.33.0
# resolves against the current directory, so we render absolute paths.
mkdir -p policies
cp -r "$HERE/policies/." policies/
find policies -name '*.yml' -exec sed -i "s#@POLICIES@#$PWD/policies#g" {} +
cp "$HERE/exceptions.yml" .
run_sh 'grep -h "^extends:\|^enforcement:" policies/meridian-finance/apm-policy.pilot.yml policies/meridian-checkout/apm-policy.yml | sed "s#$PWD#<workspace>#"'
expect_out 'enforcement: warn'
expect_out 'enforcement: block'

run apm policy status --policy-source policies/enterprise/apm-policy.yml
expect_rc 0
expect_out 'Outcome +│ found'
expect_out 'Enforcement +│ warn'

run apm policy status --policy-source policies/meridian-finance/apm-policy.pilot.yml --json
expect_rc 0
keep_artifact "$LAST_OUT" policy-status-org-pilot.json
expect_out '"outcome": "found"'
expect_out '"enforcement": "warn"'
# The parent's deny and the org's deny are both counted: the chain merged.
expect_out '"dependencies_deny": 2'
expect_out '"manifest_required_fields": 3'

run apm policy status --policy-source policies/meridian-checkout/apm-policy.yml --json
keep_artifact "$LAST_OUT" policy-status-checkout.json
expect_out '"enforcement": "block"'
expect_out '"dependencies_deny": 3'

step "B. Three meridian-finance repos install their agent dependencies"
for r in meridian-checkout meridian-ledger meridian-platform-tools; do
  mkdir -p "repos/$r"; cp "$HERE/fixtures/$r/apm.yml" "repos/$r/"
  pushd "repos/$r" >/dev/null; run_sh 'apm install 2>&1 | quiet'; expect_rc 0 "install $r"; popd >/dev/null
  expect_file "repos/$r/apm.lock.yaml"
done
# APM itself warns about nothing here; every dependency carries a ref.
cd repos

step "C. Week 1: the pilot policy in warn mode"
for r in meridian-checkout meridian-ledger meridian-platform-tools; do
  pushd "$r" >/dev/null
    run apm audit --ci --no-drift --no-fail-fast \
        --policy ../../policies/meridian-finance/apm-policy.pilot.yml
    expect_rc 0 "warn never fails the job ($r)"
    apm audit --ci --no-drift --no-fail-fast -f json -o "pilot-$r.json" \
        --policy ../../policies/meridian-finance/apm-policy.pilot.yml >/dev/null 2>&1
    keep_artifact "pilot-$r.json" 
  popd >/dev/null
done
run_sh 'python3 - <<EOF
import json
for r in ["meridian-checkout","meridian-ledger","meridian-platform-tools"]:
    d=json.load(open(f"{r}/pilot-{r}.json"))
    print(r, "passed=%s" % d["passed"])
    for c in d["checks"]:
        if not c["passed"] or "warn)" in c["message"]:
            print("  ", c["name"], "--", c["message"])
            for x in c.get("details") or []: print("      ", x)
EOF'
keep_artifact "$LAST_OUT" pilot-findings.txt
expect_out "bare branch 'meridian-engineering-standards-v1.0.0' tracks a moving tip"
expect_out "meridian-standards: denied by pattern"
expect_out "autopilot-comment: not in allowed sources"
expect_out "required-packages"
expect_out "required-manifest-fields"
expect_out "mcp-self-defined"

step "D. Metrics before remediation"
cp meridian-checkout/pilot-meridian-checkout.json meridian-checkout/policy-audit.json
cp meridian-ledger/pilot-meridian-ledger.json meridian-ledger/policy-audit.json
cp meridian-platform-tools/pilot-meridian-platform-tools.json meridian-platform-tools/policy-audit.json
run python3 "$HERE/tools/adoption_metrics.py" meridian-checkout meridian-ledger \
    meridian-platform-tools --exceptions ../exceptions.yml --today "$TODAY" \
    --policy ../policies/meridian-finance/apm-policy.pilot.yml \
    --json-out ../metrics-week1.json
expect_rc 0
keep_artifact "$LAST_OUT" metrics-week1.md
keep_artifact ../metrics-week1.json
expect_out 'baseline adopted: 2/3; role bundle: 3/3; owner declared: 2/3; policy pass: 3/3 \(rule warnings: 8\)'
expect_no_out 'EXC-001'

step "E. Same violation, block mode: the deprecated package now fails the job"
pushd meridian-ledger >/dev/null
  run apm audit --ci --no-drift --no-fail-fast --policy ../../policies/meridian-finance/apm-policy.yml
  expect_rc 1 "block fails the job"
  expect_out 'dependency-denylist'
  expect_out 'meridian-standards: denied by pattern' 
  popd >/dev/null

step "F. Remediate: migrate off the deprecated package, add baseline and owner"
pushd meridian-ledger >/dev/null
  run_sh "apm uninstall $PKG/meridian-standards#meridian-standards-v0.9.0 2>&1 | quiet"
  expect_rc 0
  expect_not_in_file apm.yml 'packages/meridian-standards#'
  popd >/dev/null
pushd meridian-platform-tools >/dev/null
  run_sh "sed -i 's#^description: .*#&\nauthor: meridian-finance/platform-team#' apm.yml && grep '^author' apm.yml"
  expect_out 'author: meridian-finance/platform-team'
  run_sh "apm install $PKG/meridian-engineering-standards#meridian-engineering-standards-v1.0.0 2>&1 | quiet"
  expect_rc 0
  expect_in_file apm.yml 'meridian-engineering-standards#meridian-engineering-standards-v1.0.0' 
  popd >/dev/null

step "G. Week 3: the enforced policy (block, exception EXC-001 recorded)"
for r in meridian-checkout meridian-ledger meridian-platform-tools; do
  pushd "$r" >/dev/null
    run apm audit --ci --no-drift --no-fail-fast -f json -o policy-audit.json \
        --policy ../../policies/meridian-finance/apm-policy.yml
    expect_rc 0 "$r passes the enforced org policy"
    keep_artifact policy-audit.json "enforced-$r.json" 
  popd >/dev/null
done
pushd meridian-checkout >/dev/null
  run apm audit --ci --no-drift --no-fail-fast \
      --policy ../../policies/meridian-checkout/apm-policy.yml
  expect_rc 0 "checkout passes its own stricter override"
  popd >/dev/null
run python3 "$HERE/tools/adoption_metrics.py" meridian-checkout meridian-ledger \
    meridian-platform-tools --exceptions ../exceptions.yml --today "$TODAY" \
    --policy ../policies/meridian-finance/apm-policy.yml \
    --json-out ../metrics-week3.json --fail-on-expired
expect_rc 0
keep_artifact "$LAST_OUT" metrics-week3.md
keep_artifact ../metrics-week3.json
expect_out 'baseline adopted: 3/3; role bundle: 3/3; owner declared: 3/3; policy pass: 3/3 \(rule warnings: 1\)'
expect_out 'EXC-001 \(76d left\)'

step "H. Exceptions expire: the same register three months later"
run python3 "$HERE/tools/adoption_metrics.py" meridian-ledger \
    --exceptions ../exceptions.yml --today 2027-01-15 \
    --policy ../policies/meridian-finance/apm-policy.yml \
    --json-out ../metrics-expired.json --fail-on-expired
expect_rc 1 "an expired exception fails the metrics job"
expect_out 'EXC-001 \(EXPIRED\)'

step "I. Tighten-only: the org exception does not reach meridian-checkout"
pushd meridian-checkout >/dev/null
  run_sh "apm install microsoft/apm/packages/autopilot/autopilot-comment#ee08bb59b9a7bce67fb4010e4af8652c4c53a7de 2>&1 | quiet"
  expect_rc 0 "no org policy is discovered offline, so install proceeds"
  run apm audit --ci --no-drift --no-fail-fast --policy ../../policies/meridian-finance/apm-policy.yml
  expect_rc 0 "the org policy allows it (EXC-001 is org-wide)"
  run apm audit --ci --no-drift --no-fail-fast --policy ../../policies/meridian-checkout/apm-policy.yml
  expect_rc 1 "the repo override denies it"
  expect_out 'autopilot-comment: denied by pattern: microsoft/apm/packages/autopilot/\*\*'
  run_sh "apm uninstall microsoft/apm/packages/autopilot/autopilot-comment#ee08bb59b9a7bce67fb4010e4af8652c4c53a7de 2>&1 | quiet"
  expect_rc 0 
  popd >/dev/null

step "J. A child that tries to relax the policy"
run apm policy status --policy-source ../policies/rogue-override.yml --json
keep_artifact "$LAST_OUT" policy-status-rogue.json
expect_out '"enforcement": "block"'
expect_out '"dependencies_allow": 0'
pushd meridian-checkout >/dev/null
  run apm audit --ci --no-drift --no-fail-fast --policy ../../policies/rogue-override.yml
  expect_rc 1 "an allow list of ** intersects to nothing"
  expect_out 'not in allow list' 
  popd >/dev/null

step "K. A broken chain is never enforced partially"
run_sh "sed 's#enterprise/apm-policy.yml#enterprise/missing.yml#' ../policies/meridian-finance/apm-policy.yml > ../policies/broken.yml"
run apm policy status --policy-source ../policies/broken.yml --check
expect_rc 1 "--check fails when no usable policy resolves"
expect_out 'incomplete_chain'
pushd meridian-checkout >/dev/null
  run apm audit --ci --no-drift --policy ../../policies/broken.yml
  expect_rc 1 "the CI gate fails closed on a broken chain"
  expect_out 'Policy fetch failed: Policy chain incomplete'
  popd >/dev/null

step "L. Executable trust for one installed package"
pushd meridian-ledger >/dev/null
  run apm policy explain microsoft/apm/packages/autopilot/autopilot-comment
  expect_rc 0 
  popd >/dev/null

demo_end
