# meridian-checkout

Synthetic stand-in for Meridian's checkout payment service (book demo
fixture for Chapter 5 of *Reproducible AI Agent Environments*).

## Agent environment

The agent context for this repository is declared in `apm.yml` and pinned
in `apm.lock.yaml`. After cloning, restore it with:

```bash
apm install
```

Repo-owned primitives live under `.apm/`. Everything `apm install`
generates for each tool is listed in `.gitignore` and is not committed.
