# meridian-engineering-standards

Meridian's shared engineering standards for payment services, as one
APM package. Fictional demo package for the book *Reproducible AI Agent
Environments* (Chapter 8).

It contains:

- `.apm/instructions/payment-standards.instructions.md` — money in
  integer minor units, idempotency keys on payment-mutating calls, no
  card data or PII in logs, ISO 4217 currency codes.
- `.apm/prompts/payment-pr.prompt.md` — prepares a pull request for a
  payment change and runs the review skill.
- A dependency on the `meridian-code-review` skill, pinned to
  `meridian-code-review-v1.1.0`. Consumers get the skill transitively.

Install it in a consuming project:

```yaml
dependencies:
  apm:
    - vibeprogrammer/Reproducible-AI-Agent-Environments-demo/packages/meridian-engineering-standards#meridian-engineering-standards-v1.0.0
```

Releases are git tags named `meridian-engineering-standards-vX.Y.Z`.
Tags are never moved; a fix is a new version. See CHANGELOG.md.

Tested with APM v0.33.0.
