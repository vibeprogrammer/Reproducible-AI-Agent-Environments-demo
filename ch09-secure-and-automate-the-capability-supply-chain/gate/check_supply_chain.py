#!/usr/bin/env python3
"""Jon's pre-flight guard for Meridian's agent supply chain (Chapter 9).

  python3 check_supply_chain.py [--manifest apm.yml ...] [--ci-file F ...]

Fails (exit 1) when
  * a manifest carries something that looks like a credential (userinfo in
    a URL, or a GitHub token prefix): APM 0.33.0 installs such a URL and
    keeps the lockfile clean, but the secret stays in the committed apm.yml;
  * a git dependency in a manifest has no ref, so it floats with the
    default branch instead of being pinned to a tag or commit;
  * a CI file passes a flag that switches an APM gate off.
Standard library only. It is a tripwire for honest mistakes, not a defence
against someone who is trying to hide a bypass.
"""
import argparse, pathlib, re, sys

CREDENTIAL = [
    (re.compile(r"https?://[^/\s@\"']+@"), "credentials embedded in a URL"),
    (re.compile(r"\b(ghp|gho|ghu|ghs|ghr)_[A-Za-z0-9]{8,}"), "GitHub token"),
    (re.compile(r"\bgithub_pat_[A-Za-z0-9_]{8,}"), "GitHub fine-grained token"),
    (re.compile(r"^\s*token\s*:", re.M), "token: key in a manifest"),
]
BYPASS = ["--trust-transitive-mcp", "--force", "--no-policy",
          "APM_POLICY_DISABLE", "--allow-insecure", "--no-drift"]


def git_deps(text):
    """Yield (line_no, entry) for string entries under dependencies.apm."""
    in_apm = False
    for n, line in enumerate(text.splitlines(), 1):
        if re.match(r"^\s{2}apm:\s*$", line):
            in_apm = True
            continue
        if in_apm and re.match(r"^\s{2}\S", line):
            in_apm = False
        if in_apm:
            m = re.match(r"^\s*-\s+([^\s#][^\s]*)\s*$", line)
            if m and not m.group(1).startswith(("./", "../", "/", "~")):
                yield n, m.group(1)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--manifest", action="append", default=[])
    ap.add_argument("--ci-file", action="append", default=[])
    a = ap.parse_args()
    problems = []
    for f in a.manifest:
        text = pathlib.Path(f).read_text(encoding="utf-8")
        for rx, what in CREDENTIAL:
            for m in rx.finditer(text):
                line = text.count("\n", 0, m.start()) + 1
                problems.append(f"{f}:{line}: {what}")
        for n, dep in git_deps(text):
            if "#" not in dep:
                problems.append(f"{f}:{n}: unpinned dependency {dep}")
    for f in a.ci_file:
        for n, line in enumerate(
                pathlib.Path(f).read_text(encoding="utf-8").splitlines(), 1):
            if line.lstrip().startswith("#"):
                continue
            for flag in BYPASS:
                if re.search(re.escape(flag) + r"(?![\w-])", line):
                    problems.append(f"{f}:{n}: gate bypass {flag}")
    for p in problems:
        print("FAIL " + p)
    checked = len(a.manifest) + len(a.ci_file)
    print(f"checked {checked} file(s): {len(problems)} problem(s)")
    return 1 if problems else 0


if __name__ == "__main__":
    sys.exit(main())
