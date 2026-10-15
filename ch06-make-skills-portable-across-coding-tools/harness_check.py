#!/usr/bin/env python3
"""Ask a real coding agent harness whether it discovered what APM deployed.

Usage:
  harness_check.py claude|codex WORKSPACE CASE RUNS OUTDIR

Credentials come from standard variables only:
  claude: ANTHROPIC_API_KEY (optional ANTHROPIC_BASE_URL), model CLAUDE_MODEL
  codex:  OPENAI_API_KEY (optional OPENAI_BASE_URL), model CODEX_MODEL
Without credentials the case is reported as skipped (exit 0, status
"skipped"). Each run gets a fresh, empty HOME / CODEX_HOME, so nothing from
the machine's own agent configuration leaks in. Model output is
non-deterministic: the script reports pass counts over RUNS runs.

Writes OUTDIR/<harness>-<case>.json with every answer (normalized: no keys,
no base URLs, no session ids, no costs) and prints a one-line summary.
"""
import json, os, re, shutil, subprocess, sys, tempfile

CASES = {
    # Claude Code only: what the session loaded at start-up (its init
    # event lists skills, agents, slash commands and MCP servers).
    "inventory": {
        "prompt": "Reply with the single word OK.",
        "claude_tools": "",
        "pass": r"OK",
        "init_must_list": ("skills", "meridian-code-review"),
    },
    # Is the skill in the harness's skill list at all? No tools needed.
    "skill-listed": {
        "prompt": ("Without using any tools, list the names of the agent "
                   "skills available to you in this session, one per line. "
                   "Reply with the names only. If there are none, reply NONE."),
        "claude_tools": "Skill",
        "pass": r"meridian-code-review",
    },
    # Can the harness load the skill's body and answer from it?
    "skill-used": {
        "prompt": ("Use the meridian-code-review skill. According to that "
                   "skill, what does rule MR004 check? Answer in one sentence."),
        "claude_tools": "Skill,Read",
        "pass": r"4217",
    },
    # Always-on project instructions (no file scope).
    "instructions-always": {
        "prompt": ("Without using any tools and without reading files: "
                   "according to the instructions you were given for this "
                   "project, where is the meridian-code-review skill "
                   "installed? Give the path, or reply UNKNOWN."),
        "claude_tools": "",
        "pass": r"\.(claude|agents)/skills/meridian-code-review",
    },
    # File-scoped money rules (applyTo: src/**/*.ts). The phrase
    # "not even partially" appears only in that instructions file.
    "instructions-money": {
        "prompt": ("Without using any tools and without reading files: what "
                   "do the instructions you were given for this project say "
                   "about logging card data? Quote the sentence exactly, or "
                   "reply UNKNOWN."),
        "claude_tools": "",
        "pass": r"not even partially",
    },
    # Claude Code only: the same question after the agent has read one
    # file that matches the rule's scope (src/**/*.ts). Only that file may
    # be read for the run to count.
    "instructions-money-after-read": {
        "prompt": ("Read the file src/payments/create-payment.ts. Then, "
                   "without reading any other file, quote exactly what the "
                   "instructions you were given for this project say about "
                   "logging card data, or reply UNKNOWN."),
        "claude_tools": "Read",
        "pass": r"not even partially",
        "only_reads": r"src/.*\.ts$",
    },
}

SECRET_PATTERNS = []


def normalize(text):
    if not isinstance(text, str):
        return text
    for s in SECRET_PATTERNS:
        if s:
            text = text.replace(s, "<redacted>")
    return text


def run_claude(ws, case, home):
    model = os.environ.get("CLAUDE_MODEL", "claude-sonnet-5")
    env = {k: v for k, v in os.environ.items()}
    env.update({"HOME": home, "DISABLE_AUTOUPDATER": "1",
                "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"})
    tools = case["claude_tools"]
    cmd = ["claude", "-p", case["prompt"], "--output-format", "stream-json",
           "--verbose", "--no-session-persistence", "--model", model,
           "--tools", tools]
    if tools:
        cmd += ["--allowedTools", tools]
    p = subprocess.run(cmd, cwd=ws, env=env, capture_output=True, text=True,
                       timeout=300)
    answer, used_model, tool_uses, skills_seen = "", None, [], None
    for line in p.stdout.splitlines():
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        if ev.get("type") == "system" and ev.get("subtype") == "init":
            skills_seen = {
                "skills": ev.get("skills"),
                "agents": ev.get("agents"),
                "slash_commands": ev.get("slash_commands"),
                "mcp_servers": ev.get("mcp_servers"),
            }
        if ev.get("type") == "assistant":
            for c in ev.get("message", {}).get("content", []):
                if c.get("type") == "tool_use":
                    tool_uses.append({"tool": c.get("name"),
                                      "input": c.get("input")})
        if ev.get("type") == "result":
            answer = ev.get("result") or ""
            mu = ev.get("modelUsage") or {}
            used_model = ",".join(sorted(mu)) or None
    return {"rc": p.returncode, "answer": answer, "model": used_model or model,
            "tool_uses": tool_uses, "init": skills_seen,
            "commands_run": [t for t in tool_uses if t["tool"] == "Bash"]}


def run_codex(ws, case, home):
    model = os.environ.get("CODEX_MODEL", "gpt-6-sol")
    codex_home = os.path.join(home, ".codex")
    os.makedirs(codex_home, exist_ok=True)
    base = os.environ.get("OPENAI_BASE_URL")
    cfg = [f'model = "{model}"']
    if base:
        cfg = ['model_provider = "custom"', f'model = "{model}"', "",
               "[model_providers.custom]", 'name = "custom"',
               f'base_url = "{base}"', 'env_key = "OPENAI_API_KEY"',
               'wire_api = "responses"']
    with open(os.path.join(codex_home, "config.toml"), "w") as f:
        f.write("\n".join(cfg) + "\n")
    env = {k: v for k, v in os.environ.items()}
    env.update({"HOME": home, "CODEX_HOME": codex_home})
    cmd = ["codex", "exec", "--json", "--skip-git-repo-check",
           "--sandbox", "read-only", "-m", model, case["prompt"]]
    p = subprocess.run(cmd, cwd=ws, env=env, capture_output=True, text=True,
                       timeout=300)
    answer, commands = "", []
    for line in p.stdout.splitlines():
        try:
            ev = json.loads(line)
        except ValueError:
            continue
        item = ev.get("item") or {}
        if ev.get("type") == "item.completed":
            if item.get("type") == "agent_message":
                answer = item.get("text", "")
            elif item.get("type") == "command_execution":
                commands.append(item.get("command"))
    return {"rc": p.returncode, "answer": answer, "model": model,
            "commands_run": commands,
            "stderr_tail": "" if p.returncode == 0 else p.stderr[-400:]}


def main():
    harness, ws, case_name, runs, outdir = sys.argv[1:6]
    runs = int(runs)
    case = CASES[case_name]
    key = "ANTHROPIC_API_KEY" if harness == "claude" else "OPENAI_API_KEY"
    base = "ANTHROPIC_BASE_URL" if harness == "claude" else "OPENAI_BASE_URL"
    SECRET_PATTERNS.extend([os.environ.get(key), os.environ.get(base)])
    os.makedirs(outdir, exist_ok=True)
    out = os.path.join(outdir, f"{harness}-{case_name}.json")
    label = os.path.basename(os.path.normpath(ws))
    if not os.environ.get(key) or not shutil.which(harness):
        rec = {"harness": harness, "case": case_name, "workspace": label,
               "status": "skipped", "reason": f"no {key} or no {harness} binary"}
        json.dump(rec, open(out, "w"), indent=2)
        print(f"{harness} {case_name} on {label}: skipped (no credentials)")
        return 0
    version = subprocess.run([harness, "--version"], capture_output=True,
                             text=True).stdout.strip()
    results = []
    for i in range(runs):
        home = tempfile.mkdtemp(prefix=f"h-{harness}-")
        try:
            r = (run_claude if harness == "claude" else run_codex)(ws, case, home)
        except subprocess.TimeoutExpired:
            r = {"rc": "timeout", "answer": "", "commands_run": []}
        finally:
            shutil.rmtree(home, ignore_errors=True)
        r["passed"] = bool(re.search(case["pass"], r.get("answer") or "", re.I))
        if "only_reads" in case:
            reads = [str((t.get("input") or {}).get("file_path", ""))
                     for t in r.get("tool_uses", [])]
            if not reads or not all(re.search(case["only_reads"], p)
                                    for p in reads):
                r["passed"] = False
                r["note"] = "did not read exactly the scoped file(s)"
        if "init_must_list" in case:
            field, name = case["init_must_list"]
            r["passed"] = name in ((r.get("init") or {}).get(field) or [])
        # A "without tools" case only counts if no command was run.
        if not case["claude_tools"] and r.get("commands_run"):
            r["passed"] = False
            r["note"] = "ran a command; not counted as discovery"
        results.append({k: normalize(v) if isinstance(v, str) else v
                        for k, v in r.items()})
    passed = sum(1 for r in results if r["passed"])
    rec = {"harness": harness, "version": version, "case": case_name,
           "workspace": label, "prompt": case["prompt"],
           "pass_pattern": case["pass"], "runs": runs, "passed": passed,
           "status": "ran", "results": results}
    text = normalize(json.dumps(rec, indent=2))
    open(out, "w").write(text + "\n")
    print(f"{harness} {case_name} on {label}: {passed}/{runs}")
    return 0


if __name__ == "__main__":
    sys.exit(main())
