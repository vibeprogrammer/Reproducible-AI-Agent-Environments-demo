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
./verify-all.sh        # or: bash ch05-declare-and-restore/run.sh
```

## License

MIT (see [LICENSE](LICENSE)).
