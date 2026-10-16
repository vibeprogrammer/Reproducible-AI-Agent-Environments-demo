# meridian-checkout

Synthetic stand-in for Meridian's checkout payment service (book demo
fixture). Chapter 5 declared its agent environment; Chapter 7 rolled the
review skill back to `meridian-code-review-v1.1.0`; Chapter 9 gates every
change to it in CI.

## Agent environment

The agent context is declared in `apm.yml` and pinned in `apm.lock.yaml`.
After cloning, restore it with:

```bash
apm install
git diff --exit-code -- apm.yml apm.lock.yaml
```

Repo-owned primitives live under `.apm/`. Everything `apm install`
generates for each tool is listed in `.gitignore` and is not committed.
