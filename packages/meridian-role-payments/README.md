# meridian-role-payments

Role bundle for Meridian engineers who change payment-creating and refund
code paths. It adds one instruction on top of the baseline package
`meridian-engineering-standards`; it does not include the baseline itself.

- Owner: `meridian-finance/payments-team` (Priya is the maintainer).
- Consume it beside the baseline:

```yaml
dependencies:
  apm:
    - vibeprogrammer/Reproducible-AI-Agent-Environments-demo/packages/meridian-engineering-standards#meridian-engineering-standards-v1.0.0
    - vibeprogrammer/Reproducible-AI-Agent-Environments-demo/packages/meridian-role-payments#meridian-role-payments-v1.0.0
```

Part of the companion demos for Chapter 10 of *Reproducible AI Agent
Environments*. Meridian and `meridian-finance` are fictional.
