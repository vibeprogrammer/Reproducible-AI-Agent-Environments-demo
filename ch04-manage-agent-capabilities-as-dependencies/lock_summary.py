#!/usr/bin/env python3
"""Print one line per dependency recorded in apm.lock.yaml (stdlib only).

Reads only the top-level `dependencies:` list and the scalar keys this
chapter discusses. It is a reading aid, not a lockfile parser.
"""
import sys

KEYS = ("repo_url", "virtual_path", "resolved_ref", "resolved_commit",
        "version", "depth", "resolved_by", "package_type", "constraint",
        "resolved_tag")


def entries(path):
    out, cur, inside = [], None, False
    for raw in open(path, encoding="utf-8"):
        line = raw.rstrip("\n")
        if not line.startswith(" ") and not line.startswith("-"):
            inside = line.startswith("dependencies:")
            continue
        if not inside:
            continue
        if line.startswith("- "):
            cur = {}
            out.append(cur)
            line = "  " + line[2:]
        if cur is None or not line.startswith("  ") or line.startswith("   "):
            continue
        key, _, val = line.strip().partition(":")
        if key in KEYS:
            cur[key] = val.strip().strip("'")
    return out


def main():
    path = sys.argv[1] if len(sys.argv) > 1 else "apm.lock.yaml"
    for e in entries(path):
        name = e.get("repo_url", "?")
        if e.get("virtual_path"):
            name += "/" + e["virtual_path"]
        depth = e.get("depth", "1")
        parts = [f"depth={depth}", name,
                 f"ref={e.get('resolved_ref', '(none)')}",
                 f"commit={e.get('resolved_commit', '?')[:12]}",
                 f"version={e.get('version', '?')}",
                 f"type={e.get('package_type', '?')}"]
        if "resolved_by" in e:
            parts.append(f"resolved_by={e['resolved_by']}")
        if "constraint" in e:
            parts.append(f"constraint={e['constraint']}")
        print("  ".join(parts))


if __name__ == "__main__":
    main()
