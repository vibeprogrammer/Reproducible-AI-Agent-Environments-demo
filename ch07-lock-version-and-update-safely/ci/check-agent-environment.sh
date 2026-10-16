#!/usr/bin/env bash
# check-agent-environment.sh -- Meridian's CI gate for the agent environment
# (Chapter 7). Run from the root of a fresh meridian-checkout checkout.
# The build fails when:
#   - installing from the committed lockfile would change apm.yml or
#     apm.lock.yaml (the lockfile does not describe the manifest, or a
#     locked commit cannot be fetched any more)
#   - apm install --frozen finds manifest/lockfile or MCP config drift
#   - a deployed file is missing or no longer matches its locked hash
# Policy enforcement is left out on purpose (--no-policy); Chapter 10 adds it.
#
# Why not just `apm install --frozen` first? With APM v0.33.0, on a cold
# checkout (no apm_modules/) of a project that declares MCP servers,
# `apm install --frozen` stopped with "package manifest not found ...
# re-run 'apm install'" before downloading anything (observed 2026-10-15,
# see the Chapter 7 demo evidence). A normal install reuses the locked
# commits, and the git diff check turns any lockfile change into a failure.
set -euo pipefail
apm --version
apm install
git diff --exit-code -- apm.yml apm.lock.yaml
apm install --frozen
apm audit --ci --no-policy
