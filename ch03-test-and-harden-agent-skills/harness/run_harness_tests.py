#!/usr/bin/env python3
"""Activation, adherence, conflict and permission tests for meridian-code-review
in real agent harnesses (Claude Code and Codex CLI).

Standard variables only:
  ANTHROPIC_API_KEY (+ optional ANTHROPIC_BASE_URL)   -> Claude Code runs
  OPENAI_API_KEY    (+ optional OPENAI_BASE_URL)      -> Codex CLI runs
A harness whose key is missing is reported as "skipped: no credentials".

Usage:
  run_harness_tests.py --ref meridian-code-review-v1.0.0 --runs 3 --out DIR
                       [--suite activation,conflict,permissions]
                       [--configs claude:claude-sonnet-5,claude:claude-haiku-4-5,codex:gpt-6-sol]
Model output is non-deterministic: the script reports pass rates over N runs.
"""
import argparse, concurrent.futures as cf, json, os, pathlib, re, shutil
import subprocess, sys, tempfile, time

HERE = pathlib.Path(__file__).resolve().parent
DEMO = HERE.parent
REPO = DEMO.parent
PKG = "vibeprogrammer/Reproducible-AI-Agent-Environments-demo/packages/meridian-code-review"
CASES = json.loads((HERE / "cases.json").read_text())
SKILL = "meridian-code-review"


def sh(cmd, cwd, env=None, timeout=300):
    return subprocess.run(cmd, cwd=cwd, env=env, capture_output=True, text=True,
                          timeout=timeout, shell=isinstance(cmd, str))


def template(ref, tmp):
    """One real APM install of the skill at `ref`, reused for every run."""
    proj = tmp / "template" / "meridian-checkout"
    home = tmp / "template" / "home"
    proj.mkdir(parents=True); home.mkdir()
    env = {**os.environ, "HOME": str(home), "APM_PROGRESS": "never"}
    sh("git init -q .", proj)
    r = sh(["apm", "install", f"{PKG}#{ref}", "--target", "claude,codex"], proj, env)
    if r.returncode != 0:
        sys.exit("apm install failed:\n" + r.stdout + r.stderr)
    fx = DEMO / "fixtures" / "workspace"
    shutil.copytree(fx, proj, dirs_exist_ok=True)
    return proj


def workspace(tpl, tmp, extra=None, skill_patch=None):
    ws = pathlib.Path(tempfile.mkdtemp(prefix="ws-", dir=tmp))
    proj = ws / "meridian-checkout"
    shutil.copytree(tpl, proj, ignore=shutil.ignore_patterns(".git"))
    (ws / "home").mkdir()
    for rel, text in (extra or {}).items():
        (proj / rel).write_text(text)
    if skill_patch:
        for d in (".claude/skills", ".agents/skills"):
            p = proj / d / SKILL / "SKILL.md"
            p.write_text(skill_patch(p.read_text()))
    sh("git init -q . && git add -A && git -c user.name=demo "
       "-c user.email=demo@meridian.example commit -qm base", proj)
    return ws, proj


def run_claude(model, prompt, ws, proj, extra_args=()):
    env = {**os.environ, "HOME": str(ws / "home"), "DISABLE_AUTOUPDATER": "1",
           "CLAUDE_CODE_DISABLE_NONESSENTIAL_TRAFFIC": "1"}
    cmd = ["claude", "-p", prompt, "--output-format", "stream-json", "--verbose",
           "--model", model, "--no-session-persistence",
           "--max-budget-usd", "0.40", *extra_args]
    r = sh(cmd, proj, env, timeout=420)
    events = [json.loads(l) for l in r.stdout.splitlines() if l.startswith("{")]
    skills, tools, bash, results, report, denied, used, mode = [], [], [], {}, "", [], None, None
    for e in events:
        if e.get("type") == "system" and e.get("subtype") == "init":
            mode = e.get("permissionMode")
        if e.get("type") == "assistant":
            for c in e["message"]["content"]:
                if c.get("type") == "tool_use":
                    tools.append(c["name"])
                    if c["name"] == "Skill":
                        skills.append(c["input"].get("skill", ""))
                    if c["name"] == "Bash":
                        bash.append((c["id"], c["input"].get("command", "")))
        if e.get("type") == "user":
            for c in e["message"].get("content", []):
                if isinstance(c, dict) and c.get("type") == "tool_result":
                    results[c.get("tool_use_id")] = str(c.get("content"))[:2000]
        if e.get("type") == "result":
            report = e.get("result") or ""
            denied = e.get("permission_denials") or []
            used = sorted((e.get("modelUsage") or {}).keys())
    # The checker ran when one of its calls returned checker output.
    checker_ran = any("check_money_rules" in c and "finding" in results.get(i, "")
                      for i, c in bash)
    return {"activated": SKILL in skills, "skills_invoked": skills,
            "tools": tools, "commands": [c for _, c in bash],
            "permission_mode": mode,
            "permission_denials": [d.get("tool_name") for d in denied],
            "denied_commands": [str((d.get("tool_input") or {}).get("command", ""))[:200]
                                for d in denied],
            "checker_ran": checker_ran, "models_used": used,
            "report": report, "exit_code": r.returncode}


def run_codex(model, prompt, ws, proj, extra_args=()):
    home = ws / "home"; ch = home / ".codex"; ch.mkdir(parents=True)
    base = os.environ.get("OPENAI_BASE_URL", "https://api.openai.com/v1")
    (ch / "config.toml").write_text(
        f'model_provider = "custom"\nmodel = "{model}"\n'
        f'[model_providers.custom]\nname = "custom"\nbase_url = "{base}"\n'
        f'env_key = "OPENAI_API_KEY"\nwire_api = "responses"\n')
    env = {**os.environ, "HOME": str(home), "CODEX_HOME": str(ch)}
    cmd = ["codex", "exec", "--skip-git-repo-check", "--sandbox", "read-only",
           "--json", *extra_args, prompt]
    r = sh(cmd, proj, env, timeout=420)
    events = [json.loads(l) for l in r.stdout.splitlines() if l.startswith("{")]
    cmds, report, checker_ran = [], "", False
    for e in events:
        it = e.get("item") or {}
        if e.get("type") == "item.completed" and it.get("type") == "command_execution":
            cmds.append(it.get("command", ""))
            if "check_money_rules" in it.get("command", "") and \
                    "finding" in (it.get("aggregated_output") or ""):
                checker_ran = True
        if e.get("type") == "item.completed" and it.get("type") == "agent_message":
            report = it.get("text", "")
    read_skill = any(re.search(SKILL + r"/SKILL\.md", c) for c in cmds)
    return {"activated": read_skill, "commands": cmds, "report": report,
            "checker_ran": checker_ran, "permission_mode": "sandbox read-only",
            "models_used": [model], "exit_code": r.returncode}


# ---- deterministic scoring of a review report ------------------------------
VERDICTS = ("Approve", "Approve with comments", "Changes requested")

def score_report(text):
    m = re.search(r"\*\*Verdict:\*\*\s*([^\n]+)", text)
    verdict = m.group(1).strip().strip("*").strip() if m else None
    checks = {
        "verdict_line": verdict is not None,
        "verdict_allowed": verdict in VERDICTS,
        "verdict_changes_requested": verdict == "Changes requested",
        "checker_line": bool(re.search(r"\*\*Checker:\*\*", text)),
        "section_violations": "## Money rule violations" in text,
        "section_other": "## Other findings" in text,
        "rules_mr001_to_mr004": all(r in text for r in ("MR001", "MR002", "MR003", "MR004")),
    }
    return verdict, checks


def section(text, title):
    m = re.search(r"(?im)^#+\s*" + re.escape(title) + r"[^\n]*\n(.*?)(?=^#+\s|\Z)", text, re.S)
    return m.group(1) if m else ""


def mr003_in_violations(text):
    return "MR003" in section(text, "Money rule violations")


def mentions_conflict(text):
    return bool(re.search(r"(?i)conflict|contradict|AGENTS\.md|CLAUDE\.md", text))


def checker_claims_findings(text):
    m = re.search(r"\*\*Checker:\*\*([^\n]*)", text)
    return bool(m and re.search(r"\b[1-9]\d* finding", m.group(1)))


def norm(text, ws):
    return text.replace(str(ws), "<workspace>")


def main():
    if len(sys.argv) == 3 and sys.argv[1] == "--rescore":
        return rescore(sys.argv[2])
    ap = argparse.ArgumentParser()
    ap.add_argument("--ref", required=True)
    ap.add_argument("--runs", type=int, default=3)
    ap.add_argument("--out", required=True)
    ap.add_argument("--suite", default="activation,conflict,permissions")
    ap.add_argument("--configs", default="claude:claude-sonnet-5,claude:claude-haiku-4-5,codex:gpt-6-sol")
    ap.add_argument("--jobs", type=int, default=6)
    a = ap.parse_args()
    out = pathlib.Path(a.out); (out / "reports").mkdir(parents=True, exist_ok=True)
    have = {"claude": bool(os.environ.get("ANTHROPIC_API_KEY")),
            "codex": bool(os.environ.get("OPENAI_API_KEY"))}
    configs = [tuple(c.split(":", 1)) for c in a.configs.split(",")]
    skipped = sorted({h for h, _ in configs if not have[h]})
    configs = [c for c in configs if have[c[0]]]
    tmp = pathlib.Path(tempfile.mkdtemp(prefix="raae-ch03-harness-"))
    tpl = template(a.ref, tmp)
    versions = {"claude": sh(["claude", "--version"], tmp).stdout.strip(),
                "codex": sh(["codex", "--version"], tmp).stdout.strip()}
    jobs = []
    suites = a.suite.split(",")
    if "activation" in suites:
        for case in CASES["activation"]:
            for h, m in configs:
                for i in range(a.runs):
                    jobs.append(("activation", case, h, m, i, {}))
    if "conflict" in suites:
        for h, m in configs:
            for i in range(a.runs):
                jobs.append(("conflict", CASES["conflict"], h, m, i, {}))
    if "permissions" in suites:
        for variant in ("no-allowed-tools", "allowed-tools"):
            for h, m in configs:
                if h != "claude" or m != configs[0][1]:
                    continue
                for i in range(a.runs):
                    jobs.append(("permissions", {**CASES["permissions"], "variant": variant}, h, m, i, {}))

    def one(job):
        suite, case, h, m, i, _ = job
        extra, patch, args = {}, None, ()
        if suite == "conflict":
            extra = case["files"]
        if suite == "permissions":
            args = ("--permission-mode", "dontAsk", "--allowedTools", "Skill,Read,Grep,Glob")
            if case["variant"] == "allowed-tools":
                patch = lambda s: s.replace("\nlicense: MIT\n",
                                            "\nlicense: MIT\nallowed-tools: Bash(python3 *)\n", 1)
        ws, proj = workspace(tpl, tmp, extra, patch)
        t0 = time.time()
        fn = run_claude if h == "claude" else run_codex
        res = fn(m, case["prompt"], ws, proj, args)
        res["seconds"] = round(time.time() - t0, 1)
        res["report"] = norm(res["report"], ws)
        res.update({"suite": suite, "case": case["id"], "harness": h, "model": m, "run": i + 1})
        if suite == "permissions":
            res["variant"] = case["variant"]
        name = f"{suite}-{case['id']}{'-' + case['variant'] if suite == 'permissions' else ''}-{h}-{m}-{i+1}.md"
        (out / "reports" / name).write_text(res["report"])
        res["report_file"] = "reports/" + name
        # changes in the workspace (side effects of the agent run)
        st = sh("git status --porcelain", proj).stdout.strip()
        res["workspace_changes"] = st.splitlines() if st else []
        for k in ("commands", "tools", "denied_commands"):
            if k in res:
                res[k] = [norm(x, ws)[:300] for x in res[k]]
        shutil.rmtree(ws, ignore_errors=True)
        return res

    results = []
    with cf.ThreadPoolExecutor(a.jobs) as ex:
        for r in ex.map(one, jobs):
            results.append(r)
            print(f"{r['suite']:11} {r['case']:24} {r['harness']}:{r['model']:18} run {r['run']} "
                  f"activated={r['activated']}", flush=True)
    for r in results:
        r["report"] = (out / r["report_file"]).read_text()
    summary = summarize(results)
    doc = {"ref": a.ref, "runs_per_case": a.runs, "harness_versions": versions,
           "skipped": [f"{h}: no credentials" for h in skipped],
           "date_utc": time.strftime("%Y-%m-%dT%H:%M:%SZ", time.gmtime()),
           "summary": summary, "results": results}
    for r in results:
        r.pop("report", None)
    (out / "results.json").write_text(json.dumps(doc, indent=1))
    print(json.dumps({"summary": summary, "skipped": doc["skipped"]}, indent=1))
    shutil.rmtree(tmp, ignore_errors=True)


def summarize(results):
    s = {}
    for r in results:
        key = f"{r['harness']}:{r['model']}"
        pm = s.setdefault("permission_modes_seen", {}).setdefault(key, [])
        if r.get("permission_mode") and r["permission_mode"] not in pm:
            pm.append(r["permission_mode"])
        if r["suite"] == "activation":
            case = next(c for c in CASES["activation"] if c["id"] == r["case"])
            ok = r["activated"] == case["should_trigger"]
            d = s.setdefault("activation", {}).setdefault(key, {})
            kind = "should_trigger" if case["should_trigger"] else "near_miss"
            d.setdefault(kind, [0, 0]); d[kind][0] += ok; d[kind][1] += 1
            d.setdefault("by_case", {}).setdefault(r["case"], [0, 0])
            d["by_case"][r["case"]][0] += ok; d["by_case"][r["case"]][1] += 1
            if case["should_trigger"] and r["activated"]:
                v, checks = score_report_text(r)
                checks["checker_ran"] = r.get("checker_ran", False)
                checks["no_files_written"] = not r["workspace_changes"]
                a = s.setdefault("adherence", {}).setdefault(key, {})
                for k, val in checks.items():
                    a.setdefault(k, [0, 0]); a[k][0] += val; a[k][1] += 1
        elif r["suite"] == "conflict":
            v, checks = score_report_text(r)
            c = s.setdefault("conflict", {}).setdefault(key, {"activated": [0, 0], "mr003_in_violations": [0, 0],
                                                               "conflict_reported": [0, 0],
                                                               "verdict_changes_requested": [0, 0]})
            c["activated"][0] += r["activated"]; c["activated"][1] += 1
            c["mr003_in_violations"][0] += mr003_in_violations(r["report"]); c["mr003_in_violations"][1] += 1
            c["conflict_reported"][0] += mentions_conflict(r["report"]); c["conflict_reported"][1] += 1
            c["verdict_changes_requested"][0] += v == "Changes requested"; c["verdict_changes_requested"][1] += 1
        elif r["suite"] == "permissions":
            p = s.setdefault("permissions", {}).setdefault(f"{key} [{r['variant']}]", {
                "activated": [0, 0], "bash_denied": [0, 0], "checker_ran": [0, 0],
                "checker_line_claims_findings": [0, 0]})
            ran = r["checker_ran"]
            p["activated"][0] += r["activated"]; p["activated"][1] += 1
            p["bash_denied"][0] += "Bash" in r["permission_denials"]; p["bash_denied"][1] += 1
            p["checker_ran"][0] += ran; p["checker_ran"][1] += 1
            p["checker_line_claims_findings"][0] += checker_claims_findings(r["report"])
            p["checker_line_claims_findings"][1] += 1
    return s


def score_report_text(r):
    return score_report(r["report"])


def rescore(out):
    """Recompute the summary from saved reports (scoring changes need no reruns)."""
    out = pathlib.Path(out)
    doc = json.loads((out / "results.json").read_text())
    for r in doc["results"]:
        r["report"] = (out / r["report_file"]).read_text()
    doc["summary"] = summarize(doc["results"])
    for r in doc["results"]:
        r.pop("report", None)
    (out / "results.json").write_text(json.dumps(doc, indent=1))
    print(json.dumps(doc["summary"], indent=1))


if __name__ == "__main__":
    main()
