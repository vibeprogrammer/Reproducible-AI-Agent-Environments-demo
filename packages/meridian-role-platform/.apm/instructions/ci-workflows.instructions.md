---
description: Rules for Meridian CI and release workflows
applyTo: ".github/workflows/**"
---

- Pin third-party GitHub Actions to a full 40-character commit SHA, with
  the release tag in a trailing comment.
- Give every workflow an explicit `permissions:` block with the least
  access it needs; default to `contents: read`.
- Every repository that declares agent dependencies runs
  `apm audit --ci --policy org` as a required pull-request check.
- Never print secrets, tokens, or environment dumps in workflow logs.
