# Chapter 10 demo: govern and scale across teams

Companion demo for Chapter 10 of *Reproducible AI Agent Environments*.
Marta, Meridian's engineering manager, rolls an `apm-policy.yml` out
across three `meridian-finance` repositories: a policy chain
(enterprise hub -> org -> repo override), a warn-mode pilot, remediation
and one recorded exception, the flip to block, tighten-only inheritance,
and adoption metrics computed from the repositories' lockfiles.

The public demo repository stands in for Meridian's internal
repositories (`meridian-finance/...` in the book), so internal packages
are matched under
`vibeprogrammer/reproducible-ai-agent-environments-demo/packages/**`.

## Prerequisites

- APM CLI **0.33.0** on `PATH` (`apm --version`); the harness refuses any
  other version.
- `git`, `bash`, `python3` (standard library only).
- Network access to public GitHub (packages install from this repository
  by tag and from `microsoft/apm` by commit SHA). No credentials.

## Files

- `run.sh`: the whole demo; sources `../scripts/lib.sh`.
- `policies/enterprise/apm-policy.yml`: enterprise hub (warn; a deny
  list, `max_depth`, MCP transport and self-defined rules, required
  manifest fields `version`, `description`, `author`).
- `policies/meridian-finance/apm-policy.pilot.yml`: week-1 org policy
  (warn; approved sources, the deprecated `meridian-standards` denied,
  the baseline required, `require_pinned_constraint` on trial).
- `policies/meridian-finance/apm-policy.yml`: the enforced org policy
  (block; exception EXC-001 recorded; `require_pinned_constraint`
  dropped, see below).
- `policies/meridian-checkout/apm-policy.yml`: repo override (block, plus
  a deny on `microsoft/apm/packages/autopilot/**`).
- `policies/rogue-override.yml`: a child that tries to relax the chain.
- `exceptions.yml`: the exceptions register (APM 0.33.0 has no waiver
  field; this file and the comment in the org policy are the process).
- `fixtures/<repo>/apm.yml`: manifests for `meridian-checkout`,
  `meridian-ledger`, `meridian-platform-tools`.
- `tools/adoption_metrics.py`: aggregates `apm.yml`, `apm.lock.yaml`,
  the `apm audit --ci -f json` result and the exceptions register into a
  Markdown table and `metrics.json`.

Packages added for this chapter (tags never move):
`packages/meridian-role-payments` (`meridian-role-payments-v1.0.0`),
`packages/meridian-role-platform` (`meridian-role-platform-v1.0.0`) and the
deprecated stand-in `packages/meridian-standards`
(`meridian-standards-v0.9.0`). The baseline is Chapter 8's
`meridian-engineering-standards-v1.0.0`.

## Run

```bash
bash ch10-govern-and-scale-across-teams/run.sh
```

Evidence lands in `evidence/ch10-govern-and-scale-across-teams/`
(`transcript.log`, `environment.txt`, `result.json`, `artifacts/`).

## Expected observations

1. A: `apm policy status --policy-source <file>` resolves each level; the
   org pilot reports 2 dependency denies (one inherited) and 3 required
   manifest fields; the checkout override reports `block` and 3 denies.
2. C: under the warn pilot every `apm audit --ci` exits 0, and the
   findings are: per-package tags such as
   `meridian-engineering-standards-v1.0.0` read as "bare branch" by
   `require_pinned_constraint`; the deprecated `meridian-standards` and an
   unapproved third-party package in `meridian-ledger`; a missing baseline
   and missing `author` in `meridian-platform-tools`; self-defined MCP
   servers in `meridian-checkout` (a per-rule warn).
3. E: the same deprecated-package violation under the enforced policy
   exits 1.
4. F-G: after `apm uninstall`, an `author` line and `apm install` of the
   baseline, all three repos pass the enforced policy; the metrics read
   3/3 for baseline, role bundle, owner and policy, with EXC-001 open.
5. H: the same register evaluated as of 2027-01-15 reports EXC-001
   expired and exits 1 with `--fail-on-expired`.
6. I: the org exception allows `autopilot-comment` org-wide, but the
   checkout override's deny wins (deny lists union).
7. J: a child with `enforcement: off` and `allow: ["**"]` stays at
   `block`, and its allow list intersects to nothing, so every dependency
   fails the allow list.
8. K: a missing parent gives `incomplete_chain`; `apm policy status
   --check` and `apm audit --ci` both exit 1.
9. M: a `require:` entry with a `#ref` and `require_resolution:
   project-wins` passes with one warning when the lockfile resolved a
   different ref; with `block` the same mismatch exits 1. This is the
   closest 0.33.0 gets to deprecating one release of a required package.
10. N: requiring `meridian-code-review`, which every repo receives only
   transitively through the baseline, fails `required-packages`:
   `require:` checks the manifest's direct dependencies.
11. O: `policy.hash` in a repository's `apm.yml` pins the bytes of the
   policy it expects. A matching hash passes; a mismatch is reported and
   enforcement is skipped (exit 0) under the default posture; with
   `policy.fetch_failure_default: block` the same mismatch exits 1.

## Limitations (what this demo does not verify)

- **Install-time enforcement.** `apm install` has no `--policy` flag in
  0.33.0; it discovers `<org>/.github-private|.github|.apm/apm-policy.yml`
  from the project's git remote through the GitHub API. The fixture repos
  have no remote (`meridian-finance` is fictional), so installs here run
  without a policy, and the gate shown is `apm audit --ci --policy <file>`.
  Install-time warn/block output is documented upstream but not observed
  in this demo.
- **`extends:` by repository.** Production chains use `extends: org` or
  `owner/repo`; this demo uses file paths, which 0.33.0 resolves against
  the current working directory (so `run.sh` writes absolute paths).
  Repository-based chains were not exercised.
- **Exceptions are org-wide.** Allow-listing a package for one repo allows
  it for every repo under that policy; the per-repo scope lives only in
  `exceptions.yml` and review.
- **Version-level deprecation.** Dependency allow/deny patterns match the
  package identity without its `#ref`, so a single release cannot be
  denied; the demo deprecates a whole package.
- `apm policy status` prints `Extends chain: none` for file sources even
  when the parent's rules were merged (the rule counts show the merge).
- The hash-pin behaviour in step O was observed with a file policy
  source. The v0.33.0 manifest reference describes a mismatch as always
  fail-closed; with a file source we saw fail-closed only with
  `fetch_failure_default: block`. Repository sources were not exercised.
- The metrics are adoption facts from APM artifacts, not measures of
  agent behaviour or productivity.
