#!/usr/bin/env python3
"""Print a readable summary of a harness results.json (no model calls)."""
import json, sys

d = json.load(open(sys.argv[1]))
print("ref: %s, runs per case: %s, date: %s" % (d["ref"], d["runs_per_case"], d["date_utc"]))
print("harnesses: %s; %s" % (d["harness_versions"]["claude"], d["harness_versions"]["codex"]))
for s in d.get("skipped", []):
    print("skipped:", s)
pct = lambda p: "%d/%d" % (p[0], p[1])
for config, a in d["summary"].get("activation", {}).items():
    print("activation  %-26s should-trigger %s  near-miss %s" % (
        config, pct(a["should_trigger"]), pct(a["near_miss"])))
for config, a in d["summary"].get("adherence", {}).items():
    print("adherence   %-26s %s" % (config, ", ".join(
        "%s %s" % (k, pct(v)) for k, v in a.items())))
for config, c in d["summary"].get("conflict", {}).items():
    print("conflict    %-26s %s" % (config, ", ".join(
        "%s %s" % (k, pct(v)) for k, v in c.items())))
for config, p in d["summary"].get("permissions", {}).items():
    print("permissions %-40s %s" % (config, ", ".join(
        "%s %s" % (k, pct(v)) for k, v in p.items())))
