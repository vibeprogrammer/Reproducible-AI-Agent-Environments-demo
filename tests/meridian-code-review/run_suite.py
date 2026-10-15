#!/usr/bin/env python3
"""Deterministic regression suite for the meridian-code-review skill.

Standard library only; no network; writes nothing outside a temporary
directory. Point it at a skill folder: the package source or an installed
copy such as .claude/skills/meridian-code-review.

  python3 run_suite.py --skill-dir PATH [--expect-version X.Y.Z] [--json FILE]

Exit 0 when every check passes, 1 when any check fails.
"""
import argparse, hashlib, json, os, pathlib, re, subprocess, sys, tempfile

HERE = pathlib.Path(__file__).resolve().parent
NAME_RE = re.compile(r"^[a-z0-9]+(-[a-z0-9]+)*$")
RESULTS = []


def check(cid, ok, detail=""):
    RESULTS.append({"id": cid, "ok": bool(ok), "detail": detail})
    print("  %s  %-40s %s" % ("PASS" if ok else "FAIL", cid, detail))


def frontmatter(text):
    """Parse the small YAML subset SKILL.md uses (scalars, >- blocks, one
    nested map). Good enough for linting; skills-ref is the spec's validator."""
    m = re.match(r"^---\n(.*?)\n---\n", text, re.S)
    if not m:
        return None, text
    data, key, block, parent = {}, None, None, None
    for line in m.group(1).splitlines():
        if block is not None and (line.startswith("  ") or not line.strip()):
            data[key] = (data[key] + " " + line.strip()).strip()
            continue
        block = None
        mm = re.match(r"^(\s*)([A-Za-z0-9_-]+):\s*(.*)$", line)
        if not mm:
            continue
        indent, k, v = mm.groups()
        if indent and parent:
            data.setdefault(parent, {})[k] = v.strip().strip('"')
            continue
        key, parent = k, None
        if v in (">-", ">", "|", "|-"):
            data[k], block = "", True
        elif v == "":
            data[k], parent = {}, k
        else:
            data[k] = v.strip().strip('"')
    return data, text[m.end():]


def tree_hash(root):
    h = hashlib.sha256()
    for p in sorted(pathlib.Path(root).rglob("*")):
        if p.is_file():
            h.update(str(p.relative_to(root)).encode()); h.update(p.read_bytes())
    return h.hexdigest()


AUDIT_HOOK = r"""
import sys, runpy, json
events = []
active = [True]
WATCH = ("socket.", "subprocess.", "os.system", "os.exec", "os.spawn",
         "os.remove", "os.rename", "os.mkdir", "os.rmdir", "shutil.",
         "urllib.", "http.")
def hook(name, args):
    if not active[0]:
        return
    if name == "open" and len(args) > 1 and isinstance(args[1], str) \
            and any(c in args[1] for c in "wax+"):
        events.append(["open-for-write", str(args[0])])
    elif name.startswith(WATCH):
        events.append([name, str(args)[:80]])
sys.addaudithook(hook)
script, out = sys.argv[1], sys.argv[2]
sys.argv = [script] + sys.argv[3:]
code = 0
try:
    runpy.run_path(script, run_name="__main__")
except SystemExit as e:
    code = e.code if isinstance(e.code, int) else 0
sys.stdout.flush()
active[0] = False   # stop recording before the harness writes its report
with open(out, "w") as fh:   # the harness's own report (after the run)
    json.dump({"events": events, "exit": code}, fh)
"""


def run_checker(skill, diff, tmp):
    script = skill / "scripts" / "check_money_rules.py"
    r = subprocess.run([sys.executable, "-I", str(script), "--diff", str(diff),
                        "--format", "json"], capture_output=True, text=True,
                       cwd=tmp, timeout=60)
    rules = None
    if r.returncode in (0, 1):
        try:
            rules = sorted(f["rule"] for f in json.loads(r.stdout)["findings"])
        except ValueError:
            rules = None
    return r, rules


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--skill-dir", required=True)
    ap.add_argument("--expect-version")
    ap.add_argument("--json")
    a = ap.parse_args()
    skill = pathlib.Path(a.skill_dir).resolve()
    exp = json.loads((HERE / "expectations.json").read_text())

    print("== structure and metadata")
    md = skill / "SKILL.md"
    check("skill-md-exists", md.is_file(), str(md.name))
    if not md.is_file():
        return finish(a)
    fm, body = frontmatter(md.read_text(encoding="utf-8"))
    check("frontmatter-present", fm is not None)
    fm = fm or {}
    name, desc = fm.get("name", ""), fm.get("description", "")
    check("name-matches-spec", bool(NAME_RE.match(name)) and len(name) <= 64, name)
    check("name-matches-folder", name == skill.name or skill.name == "pkg",
          "%s vs %s" % (name, skill.name))
    check("description-length", 0 < len(desc) <= 1024, "%d chars" % len(desc))
    check("description-says-what", bool(re.search(r"(?i)^review", desc)),
          "starts with what the skill does")
    check("description-says-when", "Use when" in desc, "has a 'Use when' clause")
    check("compatibility-length", len(fm.get("compatibility", "")) <= 500)
    check("body-under-500-lines", len(body.splitlines()) < 500,
          "%d lines" % len(body.splitlines()))
    meta_v = (fm.get("metadata") or {}).get("version") if isinstance(fm.get("metadata"), dict) else None
    apm_v = None
    if (skill / "apm.yml").is_file():
        mm = re.search(r"^version:\s*(\S+)", (skill / "apm.yml").read_text(), re.M)
        apm_v = mm.group(1) if mm else None
    check("version-consistent", meta_v is not None and meta_v == apm_v,
          "SKILL.md %s, apm.yml %s" % (meta_v, apm_v))
    if a.expect_version:
        check("version-is-expected", apm_v == a.expect_version,
              "expected %s" % a.expect_version)

    print("== resources referenced from SKILL.md")
    refs = sorted(set(re.findall(r"(?<![\w.-])((?:scripts|references|assets)/[\w./-]+\.\w+)", body)))
    missing = [r for r in refs if not (skill / r).is_file()]
    check("referenced-files-exist", refs and not missing,
          "%d referenced, missing: %s" % (len(refs), ", ".join(missing) or "none"))
    shipped = sorted(str(p.relative_to(skill)) for d in ("scripts", "references", "assets")
                     for p in (skill / d).rglob("*") if p.is_file())
    orphans = [p for p in shipped if p not in refs]
    check("no-orphan-resources", not orphans, "unreferenced: %s" % (", ".join(orphans) or "none"))

    print("== checker: exit-code contract and fixtures")
    with tempfile.TemporaryDirectory() as t:
        tmp = pathlib.Path(t)
        script = skill / "scripts" / exp["checker"].split("/", 1)[1]
        r = subprocess.run([sys.executable, "-I", str(script)], capture_output=True,
                           text=True, cwd=tmp, timeout=60)
        check("usage-error-exit-2", r.returncode == 2, "no arguments -> %d" % r.returncode)
        r = subprocess.run([sys.executable, "-I", str(script), "--diff", "missing.diff"],
                           capture_output=True, text=True, cwd=tmp, timeout=60)
        check("missing-input-exit-2", r.returncode == 2, "-> %d" % r.returncode)
        r = subprocess.run([sys.executable, "-I", str(script), "--help"],
                           capture_output=True, text=True, cwd=tmp, timeout=60)
        help_text = " ".join(r.stdout.split())
        check("help-documents-diff-semantics",
              "only added lines are checked" not in help_text and "MR002" in help_text,
              "--diff help must describe what diff mode really checks")
        for case in exp["cases"]:
            res, rules = run_checker(skill, HERE / "fixtures" / case["diff"], tmp)
            ok = res.returncode == case["exit"] and \
                (case["rules"] is None or rules == sorted(case["rules"]))
            label = ("known: " + case["known"]) if case.get("known") else case["why"]
            got = "exit %d, rules %s" % (res.returncode, rules)
            if "Traceback" in res.stderr:
                got += ", traceback"
            check("fixture:" + case["id"], ok, got if not ok else label)

        print("== side effects (read-only, no network, no subprocess)")
        hook = tmp / "audit_hook.py"; hook.write_text(AUDIT_HOOK)
        before = tree_hash(skill)
        work = tmp / "work"; work.mkdir()
        listing_before = sorted(os.listdir(work))
        r = subprocess.run([sys.executable, "-I", str(hook), str(script),
                            str(tmp / "events.json"), "--diff",
                            str(HERE / "fixtures" / "bad.diff")],
                           capture_output=True, text=True, cwd=work, timeout=60)
        ev = json.loads((tmp / "events.json").read_text())
        check("no-write-network-or-subprocess-events", not ev["events"],
              "%d audit events %s" % (len(ev["events"]), ev["events"][:3]))
        check("audited-run-still-finds-issues", ev["exit"] == 1, "exit %s" % ev["exit"])
        check("skill-folder-unchanged", tree_hash(skill) == before)
        check("working-dir-unchanged", sorted(os.listdir(work)) == listing_before)
    return finish(a)


def finish(a):
    failed = [r["id"] for r in RESULTS if not r["ok"]]
    print("== %d checks, %d passed, %d failed%s" % (
        len(RESULTS), len(RESULTS) - len(failed), len(failed),
        (": " + ", ".join(failed)) if failed else ""))
    if a.json:
        pathlib.Path(a.json).write_text(json.dumps(
            {"checks": RESULTS, "passed": len(RESULTS) - len(failed),
             "failed": failed}, indent=1))
    return 1 if failed else 0


if __name__ == "__main__":
    sys.exit(main())
