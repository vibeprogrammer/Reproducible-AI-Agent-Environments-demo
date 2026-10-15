# Chapter 4 — Manage Agent Capabilities as Dependencies

Companion demo for Chapter 4 of *Reproducible AI Agent Environments*. It
inspects a **real public dependency graph** with APM v0.33.0 so you can see,
on actual packages, what the chapter explains in the abstract: direct versus
transitive dependencies, Git refs versus resolved commits, what the lockfile
records, where a package boundary sits, what happens when two paths disagree,
and how a semver range on a Git source picks a tag.

Nothing here is Meridian's own configuration. Two public packages stand in
for "someone else's capabilities", and one Meridian package
(`meridian-code-review`, published in Chapter 2 in this same repository)
shows the per-package tag convention Meridian decides on in this chapter.

## Prerequisites

- APM **0.33.0** on `PATH` (`apm --version`); the harness refuses any other
  version.
- `git`, `bash`, `python3` (stdlib only).
- Anonymous HTTPS access to `github.com`. No token, no secrets.

## Files

| File | Purpose |
|---|---|
| `run.sh` | The whole demo, fully automated, run through `../scripts/lib.sh`. |
| `fixtures/graph-lab/apm.yml` | Two direct dependencies with transitive dependencies of their own. |
| `fixtures/diamond-lab/apm.yml` | A direct pin that disagrees with a transitive requirement. |
| `fixtures/range-lab/apm.yml` | Semver ranges on two Git sub-packages. |
| `lock_summary.py` | Prints one line per locked package (depth, ref, commit, version, `resolved_by`). A reading aid, not a lockfile parser. |

The packages used:

- `microsoft/apm-sample-package#v1.0.0` — its own `apm.yml` depends on
  `github/awesome-copilot/skills/review-and-refactor` **without a ref**.
- `microsoft/apm/packages/autopilot/autopilot-pr-review-scheduler#v0.33.0` —
  a virtual sub-directory package in the APM monorepo that depends, through
  relative paths, on `autopilot-pr-review-worker`, which depends on
  `autopilot-comment` (depth 3).
- `vibeprogrammer/Reproducible-AI-Agent-Environments-demo/packages/meridian-code-review#^1.0.0`
  — Meridian's Chapter 2 skill, tagged `meridian-code-review-v1.0.0`.

## Run it

From the root of this repository:

```bash
bash ch04-manage-agent-capabilities-as-dependencies/run.sh
```

Each run creates a fresh `mktemp` workspace with an isolated `HOME` (no APM
cache, no user-level agent configuration) and writes the transcript, the
environment, the result and two lockfiles to
`../evidence/ch04-manage-agent-capabilities-as-dependencies/`.

## Expected observations (APM 0.33.0)

1. `apm install` in `graph-lab` installs **5** packages (2 direct, 3
   transitive) and warns `1 dependency unpinned: github/awesome-copilot`.
2. The lockfile records a full `resolved_commit` for every package, the
   `resolved_ref` where one was requested, `depth` (2 or 3 for transitive
   packages) and `resolved_by` (the parent that pulled it in). The unpinned
   transitive skill has a commit but no `resolved_ref`.
3. `apm deps tree` shows both chains, including the depth-3
   `autopilot-comment`.
4. `apm deps why github/awesome-copilot/skills/review-and-refactor` walks back
   to `microsoft/apm-sample-package [declared in apm.yml]`.
5. For sub-packages of the *same* monorepo, the lock records `resolved_by:
   microsoft/apm` (the repository, not the sub-package), so `apm deps why`
   stops at `microsoft/apm` and does not name the scheduler. The short name
   (`apm deps why autopilot-comment`) is reported as not installed. This is
   observed v0.33.0 behaviour; use `apm deps tree` for monorepo chains.
6. `apm view microsoft/apm-sample-package versions` lists the `v1.0.0` tag at
   `fb285168`; `apm view <installed package>` shows its ref and commit.
7. A HYBRID package (SKILL.md + apm.yml) is deployed as one directory,
   including its `evals/` folder and its own `apm.yml`.
8. After deleting `apm_modules/`, `.agents/` and `.github/`,
   `apm install --frozen` reinstalls from the lock and leaves `apm.lock.yaml`
   byte-identical, including the commit of the floating transitive skill.
9. In `diamond-lab`, `apm install` exits non-zero with `incompatible
   immutable requirements`, naming both chains (`v0.32.0` direct, `v0.33.0`
   via the worker), and writes no lockfile.
10. In `range-lab`, `^1.0.0` on `meridian-code-review` resolves to the
    `meridian-code-review-v1.x.y` tag; `~0.32.0` on `autopilot-comment`
    resolves to the **repository-wide** `v0.32.0` release tag and records
    `version: 0.32.0`, although that package's own `apm.yml` says `0.1.0`.
    The lockfile format becomes `lockfile_version: '2'`.

## Limitations and what is NOT verified

- **Floating upstream.** `github/awesome-copilot/skills/review-and-refactor`
  is unpinned upstream, so a fresh run may lock a different commit than the
  committed evidence. The checks assert the structure, not that commit.
- **Ranges move.** `^1.0.0` picks the highest `meridian-code-review-v1.*` tag;
  if a later chapter tags `v1.0.1`, this demo will resolve it.
- **Upstream availability.** The demo depends on the public repositories
  above staying available at the tags named.
- **No harness behaviour is tested.** Installing files into `.agents/skills/`
  says nothing about whether, when or how an agent activates them.
- Only the `copilot` target is exercised here; Chapter 6 covers targets.
- Tested on Linux x86_64 only (see `environment.txt` in the evidence).
