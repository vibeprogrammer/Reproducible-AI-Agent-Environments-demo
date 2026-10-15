#!/usr/bin/env python3
"""Inventory scattered agent configuration (Chapter 1 demo, stdlib only).

Walks one project directory and any number of simulated home directories,
classifies every agent-context file it recognizes by primitive type, harness
and scope, hashes it, and reports:

  * drift   - files that share a logical name but differ in content
  * dupes   - files that share a logical name and are byte-identical
  * rules   - which instruction files state each team rule (keyword probes)
  * mcp     - MCP servers per file, with pinned / unpinned / remote status

The path table below is the auditor's own map, built from APM v0.33.0's
targets matrix and MCP docs. It is a heuristic: a file the map does not know
is reported as "unclassified" under a harness directory, never silently
skipped.

Usage:
  audit_inventory.py --project DIR [--home NAME=DIR ...] [--rules FILE]
                     --out-md REPORT.md --out-json INVENTORY.json
"""
import argparse, fnmatch, hashlib, json, os, re, sys
from collections import defaultdict

# (glob relative to the scanned root, primitive type, harness)
PROJECT_MAP = [
    (".github/copilot-instructions.md", "instructions", "copilot"),
    (".github/instructions/*.instructions.md", "instructions", "copilot"),
    (".github/prompts/*.prompt.md", "prompt", "copilot"),
    (".github/agents/*.agent.md", "agent", "copilot"),
    (".github/hooks/*.json", "hook", "copilot"),
    (".vscode/mcp.json", "mcp", "copilot (VS Code)"),
    ("AGENTS.md", "instructions", "multi (AGENTS.md)"),
    ("CLAUDE.md", "instructions", "claude"),
    (".claude/CLAUDE.md", "instructions", "claude"),
    (".claude/rules/*.md", "instructions", "claude"),
    (".claude/commands/*.md", "command", "claude"),
    (".claude/agents/*.md", "agent", "claude"),
    (".claude/skills/*/SKILL.md", "skill", "claude"),
    (".claude/settings.json", "hook/settings", "claude"),
    (".mcp.json", "mcp", "claude"),
    (".cursorrules", "instructions", "cursor (legacy)"),
    (".cursor/rules/*.mdc", "instructions", "cursor"),
    (".cursor/commands/*.md", "command", "cursor"),
    (".cursor/agents/*.md", "agent", "cursor"),
    (".cursor/hooks.json", "hook", "cursor"),
    (".cursor/mcp.json", "mcp", "cursor"),
    (".agents/skills/*/SKILL.md", "skill", "shared (.agents)"),
    (".codex/agents/*.toml", "agent", "codex"),
    (".codex/hooks.json", "hook", "codex"),
    ("GEMINI.md", "instructions", "gemini"),
]
USER_MAP = [
    (".copilot/instructions/*.instructions.md", "instructions", "copilot"),
    (".copilot/prompts/*.prompt.md", "prompt", "copilot"),
    (".copilot/mcp-config.json", "mcp", "copilot (CLI)"),
    (".claude/CLAUDE.md", "instructions", "claude"),
    (".claude/commands/*.md", "command", "claude"),
    (".claude/agents/*.md", "agent", "claude"),
    (".claude/skills/*/SKILL.md", "skill", "claude"),
    (".claude.json", "mcp", "claude"),
    (".agents/skills/*/SKILL.md", "skill", "shared (.agents)"),
]
HARNESS_DIRS = (".github", ".claude", ".cursor", ".vscode", ".agents",
                ".copilot", ".codex", ".gemini")
SKIP_DIRS = {".git", "node_modules", "dist", "apm_modules", "src"}


def walk(root):
    for dirpath, dirnames, filenames in os.walk(root):
        dirnames[:] = sorted(d for d in dirnames if d not in SKIP_DIRS)
        for f in sorted(filenames):
            full = os.path.join(dirpath, f)
            yield os.path.relpath(full, root).replace(os.sep, "/"), full


def classify(rel, mapping):
    for pattern, kind, harness in mapping:
        if fnmatch.fnmatchcase(rel, pattern) and rel.count("/") == pattern.count("/"):
            return kind, harness
    return None


def logical_name(rel, kind):
    """A name that lets copies of 'the same' primitive find each other."""
    if kind == "skill":
        return "skill:" + rel.split("/")[-2]
    if kind == "mcp":
        return None  # MCP files are compared per server, below
    base = rel.split("/")[-1]
    for suffix in (".instructions.md", ".prompt.md", ".agent.md", ".mdc", ".md"):
        if base.endswith(suffix):
            base = base[: -len(suffix)]
            break
    if kind == "instructions":
        return None  # instruction files are compared by rule coverage
    return "%s:%s" % ("prompt/command", base.lower())


def sha256(path):
    with open(path, "rb") as fh:
        return hashlib.sha256(fh.read()).hexdigest()


def mcp_servers(path):
    try:
        data = json.load(open(path, encoding="utf-8"))
    except (OSError, ValueError) as exc:
        return [{"server": "?", "status": "unreadable", "detail": str(exc)}]
    servers = data.get("servers") or data.get("mcpServers") or {}
    out = []
    for name, spec in sorted(servers.items()):
        if "url" in spec:
            out.append({"server": name, "status": "remote",
                        "detail": spec["url"]})
            continue
        cmd = spec.get("command", "")
        args = [a for a in spec.get("args", []) if not a.startswith("-")]
        pkg = args[0] if args else ""
        if cmd in ("npx", "bunx", "pnpm", "yarn"):
            pinned = "@" in pkg.lstrip("@")
        elif cmd in ("uvx", "pipx"):
            pinned = "==" in pkg or "@" in pkg
        elif cmd == "docker":
            img = args[-1] if args else ""
            pinned = "@sha256:" in img or (":" in img and not img.endswith(":latest"))
            pkg = img
        else:
            pinned = None
        status = {True: "pinned", False: "UNPINNED", None: "unknown"}[pinned]
        out.append({"server": name, "status": status,
                    "detail": "%s %s" % (cmd, pkg)})
    return out


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--project", required=True)
    ap.add_argument("--home", action="append", default=[], metavar="NAME=DIR")
    ap.add_argument("--rules")
    ap.add_argument("--out-md", required=True)
    ap.add_argument("--out-json", required=True)
    a = ap.parse_args()

    roots = [("project", a.project, PROJECT_MAP)]
    for item in a.home:
        name, _, path = item.partition("=")
        roots.append(("user:" + name, path, USER_MAP))

    items, unclassified = [], []
    for scope, root, mapping in roots:
        for rel, full in walk(root):
            hit = classify(rel, mapping)
            if hit is None:
                if rel.split("/")[0] in HARNESS_DIRS:
                    unclassified.append({"scope": scope, "path": rel})
                continue
            kind, harness = hit
            items.append({"scope": scope, "path": rel, "type": kind,
                          "harness": harness, "sha256": sha256(full),
                          "bytes": os.path.getsize(full), "_full": full})

    # Drift and duplicates among copies of the same logical primitive.
    groups = defaultdict(list)
    for it in items:
        key = logical_name(it["path"], it["type"])
        if key:
            groups[key].append(it)
    drift, dupes = [], []
    for key, members in sorted(groups.items()):
        if len(members) < 2:
            continue
        variants = defaultdict(list)
        for m in members:
            variants[m["sha256"]].append("%s %s" % (m["scope"], m["path"]))
        entry = {"name": key, "copies": len(members),
                 "variants": [{"sha256": h[:12], "files": f}
                              for h, f in sorted(variants.items())]}
        (drift if len(variants) > 1 else dupes).append(entry)

    # Team-rule coverage across instruction files and prompt/command copies.
    coverage = []
    if a.rules:
        rules = json.load(open(a.rules, encoding="utf-8"))["rules"]
        for it in items:
            if it["type"] not in ("instructions", "prompt", "command"):
                continue
            text = open(it["_full"], encoding="utf-8").read()
            row = {"file": "%s %s" % (it["scope"], it["path"]), "rules": {}}
            for r in rules:
                if r.get("contradicts") and re.search(r["contradicts"], text, re.I):
                    row["rules"][r["id"]] = "CONTRADICTS"
                elif re.search(r["present"], text, re.I):
                    row["rules"][r["id"]] = "yes"
                else:
                    row["rules"][r["id"]] = "-"
            coverage.append(row)
        rule_ids = [r["id"] for r in rules]
    else:
        rule_ids = []

    mcp = []
    for it in items:
        if it["type"] == "mcp":
            for s in mcp_servers(it["_full"]):
                mcp.append(dict(s, file="%s %s" % (it["scope"], it["path"]),
                                harness=it["harness"]))
    by_server = defaultdict(set)
    for s in mcp:
        by_server[s["server"]].add(s["detail"])
    mcp_drift = sorted(k for k, v in by_server.items() if len(v) > 1)

    for it in items:
        it.pop("_full")
    result = {"items": items, "unclassified": unclassified, "drift": drift,
              "duplicates": dupes, "rule_coverage": coverage, "mcp": mcp,
              "mcp_drift": mcp_drift}
    with open(a.out_json, "w", encoding="utf-8") as fh:
        json.dump(result, fh, indent=2)

    L = ["# Agent environment inventory", "",
         "Scanned: " + ", ".join("%s" % s for s, _, _ in roots), "",
         "| Scope | Path | Type | Harness | SHA-256 (12) |",
         "| --- | --- | --- | --- | --- |"]
    for it in items:
        L.append("| %s | `%s` | %s | %s | `%s` |" % (
            it["scope"], it["path"], it["type"], it["harness"], it["sha256"][:12]))
    L += ["", "## Drift (same name, different content)", ""]
    for d in drift or [{"name": "none"}]:
        if d["name"] == "none":
            L.append("None found.")
            continue
        L.append("- **%s**: %d copies, %d variants" % (
            d["name"], d["copies"], len(d["variants"])))
        for v in d["variants"]:
            L.append("  - `%s`: %s" % (v["sha256"], "; ".join(v["files"])))
    L += ["", "## Duplicates (same name, identical content)", ""]
    L += ["- **%s**: %s" % (d["name"], "; ".join(d["variants"][0]["files"]))
          for d in dupes] or ["None found."]
    if coverage:
        L += ["", "## Team-rule coverage (keyword probes, heuristic)", "",
              "| File | " + " | ".join(rule_ids) + " |",
              "| --- | " + " | ".join("---" for _ in rule_ids) + " |"]
        for row in coverage:
            L.append("| `%s` | %s |" % (row["file"], " | ".join(
                row["rules"][r] for r in rule_ids)))
    L += ["", "## MCP servers", "", "| File | Server | Status | Detail |",
          "| --- | --- | --- | --- |"]
    for s in mcp:
        L.append("| `%s` | %s | %s | `%s` |" % (
            s["file"], s["server"], s["status"], s["detail"]))
    if mcp_drift:
        L += ["", "Servers configured differently across files: "
              + ", ".join(mcp_drift)]
    L += ["", "## Unclassified files under harness directories", ""]
    L += ["- %s `%s`" % (u["scope"], u["path"]) for u in unclassified] or ["None."]
    L += ["", "## Not visible to this audit", "",
          "- Settings stored only in a harness UI or cloud account.",
          "- Model versions, harness versions and runtime permissions.",
          "- What a remote MCP server does when called.",
          "- Secrets referenced by placeholders (values are never read)."]
    with open(a.out_md, "w", encoding="utf-8") as fh:
        fh.write("\n".join(L) + "\n")

    print("items=%d drift=%d duplicates=%d unpinned_mcp=%d remote_mcp=%d "
          "mcp_drift=%d unclassified=%d" % (
              len(items), len(drift), len(dupes),
              sum(s["status"] == "UNPINNED" for s in mcp),
              sum(s["status"] == "remote" for s in mcp),
              len(mcp_drift), len(unclassified)))
    return 0


if __name__ == "__main__":
    sys.exit(main())
