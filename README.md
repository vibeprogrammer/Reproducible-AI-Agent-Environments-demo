# Reproducible AI Agent Environments — demos

Runnable examples and verification evidence for the book *Reproducible AI Agent Environments: Build, Package, and Govern AI Primitives with Agent Package Manager* by Maxim Salnikov. The manuscript lives in [vibeprogrammer/Reproducible-AI-Agent-Environments](https://github.com/vibeprogrammer/Reproducible-AI-Agent-Environments).

> **Status:** demos are being added chapter by chapter. This README lists only demos that exist in the repository.

## Pinned version

Every demo is written and tested against **APM v0.33.0** ([release](https://github.com/microsoft/apm/releases/tag/v0.33.0)). `scripts/lib.sh` refuses to run a demo with any other `apm` version.

## How the demos work

- Each `chNN-*/run.sh` creates a fresh temporary workspace with its own `HOME`, runs the chapter's commands, checks the results, and writes `evidence/chNN-*/` (transcript, environment, result).
- `packages/` holds Meridian's shareable APM packages. Demos install them as real Git dependencies from this public repository, pinned to per-package tags such as `meridian-code-review-v1.0.0`.
- Dependencies are public or synthetic. No secrets or tokens are needed.

```bash
git clone https://github.com/vibeprogrammer/Reproducible-AI-Agent-Environments-demo.git
cd Reproducible-AI-Agent-Environments-demo
./verify-all.sh        # or: bash ch05-declare-and-restore-environments-with-apm/run.sh
```

## Demos

One folder per chapter; each `run.sh` writes its evidence to `evidence/<folder>/`. Check counts are from a fresh-clone `verify-all.sh` run on 16 October 2026 with APM v0.33.0 and no model credentials, so steps that drive a real harness skip themselves (Chapters 3, 6 and 7 record those runs in their committed evidence). Chapter 2's count is from a rerun after a fix to its own script (b7e7320). Appendix A of the book has the details.

| Chapter | Folder | Checks |
| --- | --- | --- |
| 1 | [`ch01-audit-the-agent-environment/`](ch01-audit-the-agent-environment/) | 46 passed |
| 2 | [`ch02-build-a-reusable-agent-skill/`](ch02-build-a-reusable-agent-skill/) | 55 passed |
| 3 | [`ch03-test-and-harden-agent-skills/`](ch03-test-and-harden-agent-skills/) | 42 passed |
| 4 | [`ch04-manage-agent-capabilities-as-dependencies/`](ch04-manage-agent-capabilities-as-dependencies/) | 48 passed |
| 5 | [`ch05-declare-and-restore-environments-with-apm/`](ch05-declare-and-restore-environments-with-apm/) | 119 passed |
| 6 | [`ch06-make-skills-portable-across-coding-tools/`](ch06-make-skills-portable-across-coding-tools/) | 92 passed |
| 7 | [`ch07-lock-version-and-update-safely/`](ch07-lock-version-and-update-safely/) | 98 passed |
| 8 | [`ch08-package-and-share-agent-capabilities/`](ch08-package-and-share-agent-capabilities/) | 139 passed |
| 9 | [`ch09-secure-and-automate-the-capability-supply-chain/`](ch09-secure-and-automate-the-capability-supply-chain/) | 84 passed |
| 10 | [`ch10-govern-and-scale-across-teams/`](ch10-govern-and-scale-across-teams/) | 75 passed |

Shared Meridian packages consumed by the demos as Git dependencies live in [`packages/`](packages/); each release is a per-package tag such as `meridian-code-review-v1.1.0`.

## License

MIT (see [LICENSE](LICENSE)).
