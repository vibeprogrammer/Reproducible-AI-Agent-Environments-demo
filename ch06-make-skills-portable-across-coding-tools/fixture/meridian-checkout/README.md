# meridian-checkout

Synthetic stand-in for Meridian's checkout payment service (book demo
fixture for Chapters 5 and 6 of *Reproducible AI Agent Environments*).

## Agent environment

The agent context for this repository is declared in `apm.yml` and pinned
in `apm.lock.yaml`. After cloning, restore it with:

```bash
apm install
```

Repo-owned primitives live under `.apm/`. Tool-specific notes come from
separate packages (`../agent-packages/` in this demo) that reach only their
own tool; see `PORTABILITY.md` for the checklist. Everything `apm install`
generates for each tool is listed in `.gitignore` and is not committed.
