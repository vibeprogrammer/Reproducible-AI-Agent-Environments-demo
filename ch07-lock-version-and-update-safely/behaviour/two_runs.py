#!/usr/bin/env python3
"""two_runs.py -- run the same installed skill twice in Claude Code.

Usage: two_runs.py WORKSPACE OUTDIR [--runs N] [--model MODEL]

WORKSPACE is a meridian-checkout checkout where `apm install` has deployed
.claude/skills/meridian-code-review/. The script copies Chapter 2's bad.diff
into it as change.diff, asks Claude Code N times (default 2), each in a fresh
HOME, "Do a code review of change.diff.", and records for every run: whether
the Skill tool was invoked for meridian-code-review, the final text, and
which rule IDs (MR001-MR004) and verdict words the text contains.

It then compares the runs: identical text or not, and whether every run
passes the same deterministic checks (skill used, verdict "Changes
requested", all four rule IDs mentioned).

Needs ANTHROPIC_API_KEY (and optionally ANTHROPIC_BASE_URL) and the `claude`
CLI on PATH. Without a key it writes {"status": "skipped"} and exits 0, so
the rest of the demo still passes for readers without credentials.
Standard library only. Book demo for Chapter 7.
"""
import json
import os
import re
import shutil
import subprocess
import sys
import tempfile

PROMPT = "Do a code review of change.diff."
RULES = ["MR001", "MR002", "MR003", "MR004"]


def one_run(ws, model):
    home = tempfile.mkdtemp(prefix="claude-home-")
    env = {k: v for k, v in os.environ.items()}
    env.update({"HOME": home, "DISABLE_AUTOUPDATER": "1",
                "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"})
    cmd = ["claude", "-p", PROMPT, "--output-format", "stream-json",
           "--verbose", "--model", model, "--no-session-persistence",
           "--permission-mode", "dontAsk",
           "--allowedTools", "Skill,Read,Grep,Glob,Bash(python3:*)"]
    p = subprocess.run(cmd, cwd=ws, env=env, capture_output=True, text=True,
                       timeout=600)
    shutil.rmtree(home, ignore_errors=True)
    skill_used, text, used_model = False, "", None
    for line in p.stdout.splitlines():
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if ev.get("type") == "assistant":
            for c in ev.get("message", {}).get("content", []):
                if c.get("type") == "tool_use" and c.get("name") == "Skill" \
                        and "meridian-code-review" in json.dumps(c.get("input")):
                    skill_used = True
        if ev.get("type") == "result":
            text = ev.get("result") or ""
            used_model = ",".join(sorted((ev.get("modelUsage") or {}).keys()))
    return {
        "exit_code": p.returncode,
        "model_reported": used_model,
        "skill_invoked": skill_used,
        "rules_mentioned": [r for r in RULES if r in text],
        "verdict_changes_requested": bool(
            re.search(r"(?i)changes requested", text)),
        "verdict_approve_only": bool(re.search(r"(?i)\bapprove\b", text)) and
        not re.search(r"(?i)changes requested", text),
        "chars": len(text),
        "text": text,
    }


def main(argv):
    if len(argv) < 3:
        print(__doc__)
        return 2
    ws, out = argv[1], argv[2]
    runs = int(argv[argv.index("--runs") + 1]) if "--runs" in argv else 2
    model = argv[argv.index("--model") + 1] if "--model" in argv else \
        "claude-sonnet-5"
    os.makedirs(out, exist_ok=True)
    if not os.environ.get("ANTHROPIC_API_KEY") or not shutil.which("claude"):
        json.dump({"status": "skipped", "reason": "no ANTHROPIC_API_KEY or "
                   "no claude CLI"}, open(os.path.join(out, "summary.json"), "w"))
        print("skipped: no credentials")
        return 0
    version = subprocess.run(["claude", "--version"], capture_output=True,
                             text=True).stdout.strip()
    results = []
    for i in range(1, runs + 1):
        r = one_run(ws, model)
        with open(os.path.join(out, "run%d.md" % i), "w") as fh:
            fh.write(r.pop("text"))
        results.append(r)
    texts = [open(os.path.join(out, "run%d.md" % i)).read()
             for i in range(1, runs + 1)]
    passes = [r["skill_invoked"] and r["verdict_changes_requested"] and
              len(r["rules_mentioned"]) == 4 for r in results]
    summary = {
        "status": "ran", "claude_code": version, "model_requested": model,
        "prompt": PROMPT, "runs": results,
        "texts_identical": len(set(texts)) == 1,
        "checks_passed_per_run": passes,
    }
    json.dump(summary, open(os.path.join(out, "summary.json"), "w"), indent=2)
    print(json.dumps({k: v for k, v in summary.items() if k != "runs"},
                     indent=2))
    for i, r in enumerate(results, 1):
        print("run%d: skill=%s rules=%s changes_requested=%s chars=%d"
              % (i, r["skill_invoked"], ",".join(r["rules_mentioned"]),
                 r["verdict_changes_requested"], r["chars"]))
    return 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
