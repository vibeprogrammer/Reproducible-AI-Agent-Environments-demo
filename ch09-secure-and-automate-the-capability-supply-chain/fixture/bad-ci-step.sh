#!/usr/bin/env bash
# A CI step someone "fixed" by switching a gate off (Chapter 9, step 9).
# The guard in gate/check_supply_chain.py must reject this file.
set -euo pipefail
apm install --frozen --trust-transitive-mcp
apm audit --ci
