#!/usr/bin/env python3
"""Aggregate APM artifacts from several repositories into adoption metrics.

Reads, for each repository directory given on the command line:
  apm.yml          -> owner (author) and direct dependencies
  apm.lock.yaml    -> what was actually resolved (packages, refs, depth)
  policy-audit.json (optional) -> output of `apm audit --ci -f json`
and an exceptions register (exceptions.yml).

Prints a Markdown table plus a summary, and writes metrics.json.
Standard library only: the parser understands the simple YAML shapes that
APM 0.33.0 writes (lists of flat maps), not YAML in general.
"""
import argparse, datetime, json, os, sys

INTERNAL = "vibeprogrammer/reproducible-ai-agent-environments-demo"  # stands in for meridian-finance
BASELINE = "meridian-engineering-standards"
ROLE_PREFIX = "meridian-role-"


def _scalar(v):
    v = v.strip()
    if len(v) >= 2 and v[0] == v[-1] and v[0] in "'\"":
        v = v[1:-1]
    return v


def read_list_of_maps(path, key):
    """Return the list under top-level `key:` as a list of flat dicts."""
    items, cur, inside, item_indent = [], None, False, None
    with open(path, encoding="utf-8") as f:
        for raw in f:
            line = raw.rstrip("\n")
            if not line.strip() or line.lstrip().startswith("#"):
                continue
            indent = len(line) - len(line.lstrip(" "))
            body = line.strip()
            if indent == 0 and not body.startswith("- "):
                inside = line.startswith(key + ":")
                continue
            if not inside:
                continue
            if body.startswith("- ") and (item_indent is None or indent == item_indent):
                item_indent = indent
                cur = {}
                items.append(cur)
                body = body[2:]
            elif indent != item_indent + 2 or body.startswith("- "):
                continue  # nested lists/maps (deployed_files, hashes)
            if cur is not None and ":" in body:
                k, v = body.split(":", 1)
                if v.strip():
                    cur[k.strip()] = _scalar(v)
    return items


def read_top_scalar(path, key):
    with open(path, encoding="utf-8") as f:
        for line in f:
            if line.startswith(key + ":"):
                return _scalar(line.split(":", 1)[1])
    return None


def repo_metrics(repo, exceptions, today, policy_text):
    name = os.path.basename(os.path.normpath(repo))
    lock = os.path.join(repo, "apm.lock.yaml")
    deps = read_list_of_maps(lock, "dependencies") if os.path.exists(lock) else []
    owner = read_top_scalar(os.path.join(repo, "apm.yml"), "author") or "(none)"
    internal = [d for d in deps if d.get("repo_url", "").lower() == INTERNAL]
    third = [d for d in deps if d.get("repo_url", "").lower() != INTERNAL]
    base = [d for d in internal if d.get("name") == BASELINE]
    roles = sorted(d["name"] for d in internal if d.get("name", "").startswith(ROLE_PREFIX))
    depth = max([int(d.get("depth", "1")) for d in deps] or [0])
    audit_path = os.path.join(repo, "policy-audit.json")
    verdict, failed, warned = "not audited", [], []
    if os.path.exists(audit_path):
        with open(audit_path, encoding="utf-8") as f:
            audit = json.load(f)
        checks = audit.get("checks", [])
        failed = [c["name"] for c in checks if not c.get("passed")]
        # In warn mode a violated rule still "passes"; APM marks its message.
        warned = [c["name"] for c in checks if c.get("passed")
                  and ("(enforcement: warn)" in c.get("message", "") or "(warn)" in c.get("message", ""))]
        verdict = "pass" if audit.get("passed") else "fail"
    locked_names = {(d.get("repo_url", "") + "/" + d.get("virtual_path", "")).strip("/").lower() for d in deps}
    exc = []
    for e in exceptions:
        if (e.get("repo") == name and e.get("package", "").lower() in locked_names
                and e.get("id", "?") in policy_text):  # granted in the policy file
            days = (datetime.date.fromisoformat(e["expires"]) - today).days
            exc.append(f'{e["id"]} ({days}d left)' if days >= 0 else f'{e["id"]} (EXPIRED)')
    return {
        "repo": name,
        "owner": owner,
        "baseline": base[0].get("resolved_ref", base[0].get("resolved_commit", "?")[:12]) if base else "missing",
        "role_packages": roles,
        "internal": len(internal),
        "third_party": len(third),
        "locked": len(deps),
        "max_depth": depth,
        "policy": verdict,
        "failed_checks": failed,
        "warned_checks": warned,
        "exceptions": exc,
    }


def main():
    ap = argparse.ArgumentParser(description=__doc__.splitlines()[0])
    ap.add_argument("repos", nargs="+")
    ap.add_argument("--exceptions", required=True)
    ap.add_argument("--policy", required=True,
                    help="org policy file; an exception counts only if its id appears there")
    ap.add_argument("--today", default=datetime.date.today().isoformat())
    ap.add_argument("--json-out", default="metrics.json")
    ap.add_argument("--fail-on-expired", action="store_true",
                    help="exit 1 when an exception in use has expired")
    a = ap.parse_args()
    today = datetime.date.fromisoformat(a.today)
    exceptions = read_list_of_maps(a.exceptions, "exceptions")
    with open(a.policy, encoding="utf-8") as f:
        policy_text = f.read()
    rows = [repo_metrics(r, exceptions, today, policy_text) for r in a.repos]

    print("| repo | owner | baseline | role packages | internal | 3rd-party | policy | exceptions |")
    print("|---|---|---|---|---|---|---|---|")
    for r in rows:
        pol = r["policy"]
        if r["failed_checks"]:
            pol += " (" + ", ".join(r["failed_checks"]) + ")"
        if r["warned_checks"]:
            pol += f', rule warnings: {len(r["warned_checks"])}'
        print(f'| {r["repo"]} | {r["owner"]} | {r["baseline"]} | {", ".join(r["role_packages"]) or "-"} '
              f'| {r["internal"]} | {r["third_party"]} | {pol} | {", ".join(r["exceptions"]) or "-"} |')
    n = len(rows)
    summary = {
        "repos": n,
        "baseline_adopted": sum(r["baseline"] != "missing" for r in rows),
        "role_package_adopted": sum(bool(r["role_packages"]) for r in rows),
        "owner_declared": sum(r["owner"] != "(none)" for r in rows),
        "policy_pass": sum(r["policy"] == "pass" for r in rows),
        "policy_warnings": sum(len(r["warned_checks"]) for r in rows),
        "third_party_packages": sum(r["third_party"] for r in rows),
        "open_exceptions": sum(len(r["exceptions"]) for r in rows),
        "as_of": a.today,
    }
    print()
    print(f'baseline adopted: {summary["baseline_adopted"]}/{n}; role package: {summary["role_package_adopted"]}/{n}; '
          f'owner declared: {summary["owner_declared"]}/{n}; policy pass: {summary["policy_pass"]}/{n} '
          f'(rule warnings: {summary["policy_warnings"]}); '
          f'third-party packages: {summary["third_party_packages"]}; open exceptions: {summary["open_exceptions"]}')
    with open(a.json_out, "w", encoding="utf-8") as f:
        json.dump({"summary": summary, "repos": rows}, f, indent=2)
    expired = [e for r in rows for e in r["exceptions"] if "EXPIRED" in e]
    if a.fail_on_expired and expired:
        print("expired exceptions: " + ", ".join(expired))
        return 1
    return 0


if __name__ == "__main__":
    sys.exit(main())
