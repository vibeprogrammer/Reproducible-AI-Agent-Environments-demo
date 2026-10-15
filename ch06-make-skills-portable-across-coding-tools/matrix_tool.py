#!/usr/bin/env python3
"""Helpers for the Chapter 6 demo: snapshot a workspace, diff two snapshots,
strip progress-bar noise from APM output, and build the compatibility matrix
from real install runs.

  matrix_tool.py snap DIR OUT.json         record every file (path + sha256)
  matrix_tool.py diff BEFORE AFTER OUT.txt list new and changed files
  matrix_tool.py clean < raw > clean       drop progress-bar lines
  matrix_tool.py matrix TRIALS HARNESS OUT_PREFIX
      TRIALS/<target>/{project,home,files.txt,install.log,rc[,compile.*]}
      HARNESS/*.json (from harness_check.py; may be empty)
      writes OUT_PREFIX.md and OUT_PREFIX.json

Standard library only.
"""
import hashlib, json, os, re, sys

SKIP_DIRS = {"apm_modules", ".git", ".cache", ".npm"}


def snap(root, out):
    files = {}
    for dp, dns, fns in os.walk(root):
        dns[:] = [d for d in dns if d not in SKIP_DIRS]
        for f in fns:
            p = os.path.join(dp, f)
            rel = os.path.relpath(p, root)
            with open(p, "rb") as fh:
                files[rel] = hashlib.sha256(fh.read()).hexdigest()
    json.dump(files, open(out, "w"), indent=0, sort_keys=True)


def diff(before, after, out):
    b, a = json.load(open(before)), json.load(open(after))
    lines = [f"new {k}" for k in sorted(a) if k not in b]
    lines += [f"changed {k}" for k in sorted(a) if k in b and a[k] != b[k]]
    open(out, "w").write("\n".join(lines) + ("\n" if lines else ""))


NOISE = re.compile(r"^\s*\[[#.]+\]\s+\d+%|^\s*> resolve ")


def clean():
    for line in sys.stdin:
        line = line.replace("\x1b[?25l", "").replace("\x1b[?25h", "")
        if NOISE.search(line) or not line.strip():
            continue
        sys.stdout.write(line)


# ---------------------------------------------------------------- matrix
def read(path):
    try:
        return open(path, encoding="utf-8", errors="replace").read()
    except OSError:
        return ""


def trial_files(tdir, listing="files.txt"):
    """(display_path, absolute_path) for every new or changed file."""
    out = []
    for line in read(os.path.join(tdir, listing)).splitlines():
        if not line.strip():
            continue
        kind, rel = line.split(" ", 1)
        if rel.startswith("home/"):
            disp, absp = "~/" + rel[5:], os.path.join(tdir, rel)
        else:
            rel2 = rel[len("project/"):] if rel.startswith("project/") else rel
            disp, absp = rel2, os.path.join(tdir, "project", rel2)
        out.append((disp, absp))
    return out


def folder(p):
    return p.rsplit("/", 1)[0] + "/" if "/" in p else p


def label_prompt(p):
    if p.endswith(".prompt.md"):
        return "prompt"
    if p.endswith(".toml"):
        return "command (TOML)"
    if "/workflows/" in p:
        return "workflow"
    return "command"


def classify(tdir):
    files = [(d, a) for d, a in trial_files(tdir)
             if not d.startswith("~/.apm/") and d not in (".gitignore",
                                                          "apm.lock.yaml")]
    log = read(os.path.join(tdir, "install.log"))
    cells = {}
    sk = [d for d, _ in files if d.endswith("skills/meridian-code-review/SKILL.md")]
    cells["skill"] = ", ".join(sorted(p[: -len("meridian-code-review/SKILL.md")]
                                      for p in sk)) or "-"
    ins = [d for d, _ in files if "money-handling" in d]
    if ins:
        cells["instructions"] = ", ".join(sorted(ins))
    else:
        comp = [d for d, _ in trial_files(tdir, "compile-files.txt")]
        hit = [d for d in comp
               if "not even partially" in read(os.path.join(tdir, "project", d))]
        if hit:
            cells["instructions"] = "compiled into " + ", ".join(sorted(hit))
        else:
            cells["instructions"] = "-"
    pr = [d for d, _ in files if "review-checkout-change" in d]
    cells["prompt"] = ", ".join(f"{d} ({label_prompt(d)})" for d in sorted(pr)) or "-"
    ag = [d for d, _ in files if "payments-reviewer" in d]
    cells["agent"] = ", ".join(sorted(ag)) or "-"
    hk = [d for d, a in files if not d.endswith(".sh")
          and "money-rules-reminder" in read(a)
          and "apm-hooks" not in d]
    cells["hook"] = ", ".join(sorted(hk)) or "-"
    mcp = [d for d, a in files if "ledger-mcp" in read(a)]
    if mcp:
        cells["mcp"] = ", ".join(sorted(mcp))
    elif "No selected target supports MCP" in log:
        cells["mcp"] = "no MCP client: install fails"
    else:
        cells["mcp"] = "-"
    notes = []
    if any("claude-code-notes" in d for d, _ in files):
        notes.append("claude notes")
    if any("cursor-notes" in d for d, _ in files):
        notes.append("cursor notes")
    cells["tool_notes"] = ", ".join(notes) or "-"
    cells["exit"] = read(os.path.join(tdir, "rc")).strip() or "?"
    msgs = []
    if "Run 'apm compile'" in log:
        msgs.append("asks for apm compile")
    if "requires an experimental flag" in log:
        msgs.append("needs experimental flag")
    m = re.search(r"\[i\] Targets: ([^\n(]+)", log)
    cells["resolved_as"] = m.group(1).strip() if m else "?"
    cells["messages"] = "; ".join(msgs) or "-"
    return cells


def harness_summary(hdir):
    """{workspace_label: [record, ...]}"""
    out = {}
    if not os.path.isdir(hdir):
        return out
    for f in sorted(os.listdir(hdir)):
        if f.endswith(".json"):
            rec = json.load(open(os.path.join(hdir, f)))
            out.setdefault(rec.get("workspace"), []).append(rec)
    return out


CASE_LABEL = {
    "inventory": "skill listed at start-up",
    "skill-listed": "names the skill",
    "skill-used": "answers from the skill",
    "instructions-always": "follows always-on instructions",
    "instructions-money": "follows file-scoped money rules",
    "instructions-money-after-read": "follows them after reading src/*.ts",
}


def runtime_cell(recs):
    if not recs:
        return "unverified"
    parts = []
    for r in recs:
        lab = CASE_LABEL.get(r["case"], r["case"])
        if r.get("status") == "skipped":
            parts.append(f"{lab}: skipped (no credentials)")
        else:
            parts.append(f"{lab} {r['passed']}/{r['runs']}")
    h = recs[0]
    name = {"claude": "Claude Code", "codex": "Codex CLI"}[h["harness"]]
    ver = (h.get("version") or "").split()
    ver = next((v for v in ver if re.match(r"\d+\.\d+", v)), "")
    return f"{name} {ver}: " + "; ".join(parts)


COLS = [("skill", "Skill"), ("instructions", "Instructions"),
        ("prompt", "Prompt"), ("agent", "Agent"), ("hook", "Hook"),
        ("mcp", "MCP server"), ("tool_notes", "Tool notes"),
        ("exit", "Exit"), ("messages", "APM says")]

ORDER = ["copilot", "vscode", "intellij", "claude", "cursor", "codex",
         "gemini", "antigravity", "opencode", "windsurf", "kiro", "grok-build",
         "hermes", "agent-skills", "grok-cloud", "openclaw"]

# Which harness workspace verifies which target (label -> target).
RUNTIME_FOR = {"claude": "claude", "codex": "codex"}


def short(cells):
    got = []
    for key, lab in [("skill", "skill"), ("instructions", "instructions"),
                     ("prompt", "prompt"), ("agent", "agent"),
                     ("hook", "hook"), ("mcp", "MCP")]:
        v = cells[key]
        if v == "-" or v.startswith("no MCP"):
            continue
        if key == "instructions" and v.startswith("compiled"):
            got.append("instructions (compiled)")
        elif key == "prompt" and "(prompt)" not in v:
            got.append("prompt as " + v.split("(")[-1].rstrip(")"))
        else:
            got.append(lab)
    return ", ".join(got)


def matrix(trials, hdir, prefix):
    targets = [t for t in ORDER if os.path.isdir(os.path.join(trials, t))]
    targets += sorted(t for t in os.listdir(trials)
                      if t not in targets and os.path.isdir(os.path.join(trials, t)))
    rows = {t: classify(os.path.join(trials, t)) for t in targets}
    hs = harness_summary(hdir)
    for t in targets:
        recs = [r for lab, rs in hs.items() if RUNTIME_FOR.get(lab) == t for r in rs]
        rows[t]["runtime"] = runtime_cell(recs)
    json.dump({"rows": rows, "harness": hs}, open(prefix + ".json", "w"), indent=2)
    L = ["# Compatibility matrix: meridian-checkout on APM v0.33.0", "",
         "Generated by matrix_tool.py from the install runs in this evidence "
         "folder. Each row is a fresh copy of the fixture installed with "
         "`apm install --target <target>` (experimental rows after "
         "`apm experimental enable <target>`). `-` means APM wrote nothing "
         "for that primitive. Paths starting with `~/` are user-level files "
         "written into the run's isolated HOME.", "",
         "## Summary: APM deploys vs runtime verified", "",
         "| Target | APM deploys | Runtime verified |", "|---|---|---|"]
    for t in targets:
        c = rows[t]
        dep = short(c) or "nothing"
        if c["exit"] != "0":
            dep += f" (exit {c['exit']})"
        L.append(f"| {t} | {dep} | {c['runtime']} |")
    L += ["", "## Where each primitive landed", "",
          "| Target | " + " | ".join(lab for _, lab in COLS) + " |",
          "|---" * (len(COLS) + 1) + "|"]
    for t in targets:
        c = rows[t]
        vals = [c[k].replace("|", "\\|") for k, _ in COLS]
        L.append(f"| {t} | " + " | ".join(vals) + " |")
    if hs:
        L += ["", "## Runtime checks", "",
              "| Harness | Workspace (installed for) | Check | Result |",
              "|---|---|---|---|"]
        for lab, recs in sorted(hs.items()):
            for r in recs:
                res = ("skipped (no credentials)" if r.get("status") == "skipped"
                       else f"{r['passed']}/{r['runs']}")
                L.append(f"| {r['harness']} | {lab} | "
                         f"{CASE_LABEL.get(r['case'], r['case'])} | {res} |")
    open(prefix + ".md", "w").write("\n".join(L) + "\n")


if __name__ == "__main__":
    cmd = sys.argv[1]
    if cmd == "snap":
        snap(sys.argv[2], sys.argv[3])
    elif cmd == "diff":
        diff(sys.argv[2], sys.argv[3], sys.argv[4])
    elif cmd == "clean":
        clean()
    elif cmd == "matrix":
        matrix(sys.argv[2], sys.argv[3], sys.argv[4])
    else:
        sys.exit("unknown command " + cmd)
