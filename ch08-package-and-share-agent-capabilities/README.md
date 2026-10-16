# Chapter 8 demo: package and share agent capabilities

Companion demo for Chapter 8 of *Reproducible AI Agent Environments*.
Meridian turns its review skill and its payment rules into one team
package, `meridian-engineering-standards`, publishes it as a git tag,
packs it as a bundle, and lists it in an internal catalogue (an APM
marketplace). `meridian-checkout` then depends on the team package
instead of the skill.

The public demo repository stands in for Meridian's internal
repositories (`meridian-finance/...` in the book). The catalogue, which
would be its own repository, is a local git repository created inside
the disposable workspace.

## Prerequisites

- APM CLI **0.33.0** on `PATH` (`apm --version`). The harness refuses
  any other version.
- `git`, `bash`, `python3` (standard library only).
- Network access to public GitHub (the packages are installed from
  `vibeprogrammer/Reproducible-AI-Agent-Environments-demo` by tag).
- No credentials. `LEDGER_API_KEY` is not needed; the ledger MCP server
  is configured but never started.

## Files

- `run.sh` — the whole demo; sources `../scripts/lib.sh`.
- `fixture/meridian-checkout/apm.yml` — the consumer manifest after the
  change. The rest of the project (service code, `.apm/` agent and
  prompt, `.gitignore`) is copied from the Chapter 5 fixture; the
  repo-local `money-handling` instruction is deleted because the team
  package now ships the same rules.
- `fixture/meridian-agent-catalog/apm.yml` — the catalogue: a
  `marketplace:` block listing the team package (`^1.0.0`) and the
  skill (`~1.1.0`), each resolved through a per-package `tag_pattern`.
- The package itself lives at `../packages/meridian-engineering-standards/`
  and is consumed by its tag `meridian-engineering-standards-v1.0.0`
  (commit 13749d8). It depends on
  `packages/meridian-code-review#meridian-code-review-v1.1.0`.

## Run

```bash
bash ch08-package-and-share-agent-capabilities/run.sh
```

Evidence goes to `../evidence/ch08-package-and-share-agent-capabilities/`
(`transcript.log`, `environment.txt`, `result.json`, `artifacts/`).
Last run: 125 checks passed, 0 failed (APM 0.33.0, Debian 12 x86_64,
2026-10-16).

## What the run shows (expected observations)

1. `apm --version` reports 0.33.0.
2. `git ls-remote` lists per-package release tags
   (`meridian-code-review-v1.0.0` … `v1.2.0`,
   `meridian-engineering-standards-v1.0.0` at 13749d8); there are no
   repo-wide `vX.Y.Z` tags.
3. Package shapes: the skill is a HYBRID package (`SKILL.md` +
   `apm.yml`); the team package is an `.apm/` package (an instruction
   and a prompt) whose `apm.yml` declares the skill as a dependency.
4. Producer: in the package folder, `apm install` with no harness
   markers and no `targets:` exits 2 ("No harness detected").
   `apm pack --dry-run` before any install would pack 3 files and no
   dependency content. `apm install --target claude` writes a lockfile.
5. `apm pack` writes `build/meridian-engineering-standards-1.0.0/`
   (10 files: `plugin.json`, the instruction, the prompt as
   `commands/payment-pr.md`, the skill under `skills/`, and an embedded
   `apm.lock.yaml` whose `pack.bundle_files` maps every file to a
   SHA-256). `apm pack --archive -o dist` writes a `.zip`.
6. `apm install ../bundle --target claude` installs 9 files and does not
   add a dependency to `apm.yml`. A copy with one changed line is
   refused: "Bundle integrity check failed … Hash mismatch", exit 1,
   nothing deployed.
7. `apm publish` exits 1 until the experimental `registries` feature is
   enabled. With it enabled and a `registries:` block, `--dry-run`
   prints what it would upload: a flat zip with `apm.yml`, `.apm/`,
   `README.md` and `CHANGELOG.md` — no dependency content.
8. `meridian-checkout` with the team package: `apm install` installs
   3 APM dependencies (the team package, the skill, the project's own
   `.apm/`) and 2 MCP servers; the skill lands at version 1.1.0 for every
   target; `payment-standards` lands as a Copilot instruction, a Claude
   rule and a Cursor rule. The lockfile records the skill with
   `depth: 2` and `resolved_by` naming the repository.
   `apm deps tree` prints the skill as "could not place in tree";
   `apm deps why` with the lower-case path reports it as transitive;
   the repository name alone "matches multiple packages".
   `apm audit --ci` passes.
9. A fresh clone: cold `apm install --frozen` stops with "package
   manifest not found" (the v0.33.0 behaviour Chapter 7 documents);
   `apm install` then changes neither `apm.yml` nor the lockfile, the
   warm `--frozen` install passes, and every generated file matches
   Priya's checkout by SHA-256.
10. Adding the skill directly at v1.0.1 next to the team package (which
    pins v1.1.0) fails: "incompatible immutable requirements … Align the
    requested refs", exit 1, lockfile untouched. The same pin (v1.1.0)
    twice installs.
11. The catalogue: `apm marketplace check` reports both entries OK;
    `apm pack` writes `.claude-plugin/marketplace.json` with
    `git-subdir` sources pinned to a tag and a commit SHA; `~1.1.0`
    resolves to `meridian-code-review-v1.1.0`, not the known-bad
    v1.2.0. `apm marketplace add <path> --name meridian`,
    `apm marketplace browse meridian`, `apm search standards@meridian`
    and `apm install meridian-engineering-standards@meridian` work; the
    install writes a `git:`/`path:`/`ref:` entry to `apm.yml`, and the
    lockfile records `discovered_via: meridian`.
12. `apm experimental list` is saved for the record. It lists
    `marketplace-authoring` as disabled, yet the authoring commands used
    in step 11 ran without enabling it.

## Limitations and what is NOT verified

- No registry upload: `apm publish` was only run with `--dry-run`
  against a hypothetical URL. No APM registry server was available.
- The catalogue is registered from a local path. Registering it from a
  hosted git repository (`apm marketplace add owner/repo`) is
  documented but not exercised here.
- Bundles are installed into Claude Code's layout only. How Copilot,
  Cursor or Claude Code behave at runtime with the installed files is
  not tested in this demo (see Chapters 3 and 6 for harness runs).
- `apm deps tree` and `apm deps why` output is as observed on v0.33.0
  for two packages served from one repository; it may differ for
  packages in separate repositories.
