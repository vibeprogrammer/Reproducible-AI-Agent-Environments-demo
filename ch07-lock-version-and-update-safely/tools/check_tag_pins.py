#!/usr/bin/env python3
"""check_tag_pins.py -- does each locked tag still point at the locked commit?

APM's lockfile records, per Git dependency, the ref you asked for
(resolved_ref) and the commit it resolved to (resolved_commit). APM v0.33.0
replays the recorded commit, so a tag that moves upstream does not change
what you install -- but `apm outdated` compares tag names, not commits, and
does not report the move. This script asks the remote directly with
`git ls-remote` and prints one line per locked tag:

  OK      <dep> <ref> -> <commit>          tag still points at the locked commit
  MOVED   <dep> <ref> locked <a> remote <b> tag now points somewhere else
  GONE    <dep> <ref>                      tag no longer exists upstream
  SKIP    <dep> <ref>                      ref is a branch or SHA (not a tag)

Exit code: 0 when every tag is OK or skipped, 1 when any tag MOVED or is GONE,
2 on usage or read errors. Standard library only; reads apm.lock.yaml in the
current directory (or the path given as the first argument). Part of the
book demo for Chapter 7 of "Reproducible AI Agent Environments".
"""
import re
import subprocess
import sys


def entries(text):
    """Yield one dict per item of the top-level `dependencies:` list."""
    block = re.search(r"^dependencies:\n((?:[ -].*\n?)*)", text, re.M)
    if not block:
        return
    for item in re.split(r"^- ", block.group(1), flags=re.M):
        fields = {}
        for line in item.splitlines():
            m = re.match(r"^\s*([a-z_]+): (.+)$", line)
            if m and m.group(1) not in fields:
                fields[m.group(1)] = m.group(2).strip().strip("'\"")
        if "repo_url" in fields:
            yield fields


def clone_url(d):
    repo = d.get("materialization_repo_url", d["repo_url"])
    if repo.startswith(("https://", "http://")):
        return repo
    host = d.get("host", "github.com")
    port = ":" + d["port"] if d.get("port") else ""
    scheme = "http" if d.get("is_insecure") == "true" else "https"
    return "%s://%s%s/%s.git" % (scheme, host, port, repo)


def main(argv):
    path = argv[1] if len(argv) > 1 else "apm.lock.yaml"
    try:
        text = open(path, encoding="utf-8").read()
    except OSError as exc:
        print("error: %s" % exc, file=sys.stderr)
        return 2
    bad = 0
    for d in entries(text):
        name = d["repo_url"] + ("/" + d["virtual_path"] if d.get("virtual_path") else "")
        ref, locked = d.get("resolved_ref"), d.get("resolved_commit", "")
        if not ref or re.fullmatch(r"[0-9a-f]{7,40}", ref):
            print("SKIP    %s %s" % (name, ref or "-"))
            continue
        out = subprocess.run(
            ["git", "ls-remote", clone_url(d), "refs/tags/" + ref,
             "refs/tags/" + ref + "^{}"],
            capture_output=True, text=True, timeout=60)
        if out.returncode != 0:
            print("error: git ls-remote failed for %s" % name, file=sys.stderr)
            return 2
        refs = dict(reversed(l.split("\t")) for l in out.stdout.split("\n") if l)
        remote = refs.get("refs/tags/" + ref + "^{}") or refs.get("refs/tags/" + ref)
        if remote is None:
            heads = subprocess.run(["git", "ls-remote", "--heads", clone_url(d), ref],
                                   capture_output=True, text=True, timeout=60)
            if heads.stdout.strip():
                print("SKIP    %s %s (branch)" % (name, ref))
                continue
            print("GONE    %s %s" % (name, ref))
            bad += 1
        elif remote == locked:
            print("OK      %s %s -> %s" % (name, ref, locked[:12]))
        else:
            print("MOVED   %s %s locked %s remote %s" % (name, ref, locked[:12], remote[:12]))
            bad += 1
    return 1 if bad else 0


if __name__ == "__main__":
    sys.exit(main(sys.argv))
