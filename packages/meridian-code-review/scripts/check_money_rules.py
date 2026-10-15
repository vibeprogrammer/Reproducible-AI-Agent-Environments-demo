#!/usr/bin/env python3
"""Check a diff or source files against Meridian's money rules.

Standard library only. Read-only: the script never writes files and never
uses the network.

Rules:
  MR001  money held as a floating-point value
  MR002  payment, charge or refund created without an idempotency key
  MR003  card data or personal data passed to a logger
  MR004  currency code that is not an upper-case ISO 4217 alphabetic code

Usage:
  check_money_rules.py --diff change.diff        # only added lines
  check_money_rules.py --diff -                  # diff on stdin
  check_money_rules.py --files src/a.ts src/b.ts
  add --format json for machine-readable output

Exit codes: 0 no findings, 1 findings, 2 usage or input error.
"""
import argparse
import json
import re
import sys

# A money-looking identifier: amount, totalPrice, shippingFee, unit_price ...
MONEY_NAME = (r"(?:\b(?:amount|price|total|subtotal|fee|balance|cost)\w*"
              r"|\b[a-z]\w*(?:Amount|Price|Total|Fee|Balance|Cost)\w*"
              r"|\b\w+_(?:amount|price|total|fee|balance|cost)\w*)")
# Names that already say "minor units" are fine even with Number().
MINOR_OK = re.compile(r"(?i)(minor|cents|_ore\b|ore[A-Z])")

FLOAT_PATTERNS = [
    # amount = 19.99 / amount: 19.99 / const totalPrice = 0.5
    (re.compile(MONEY_NAME + r"\s*[:=]\s*-?\d+\.\d+"),
     "decimal literal assigned to a money field"),
    # parseFloat(...) anywhere on a line that mentions money
    (re.compile(r"parseFloat\s*\(.*" + MONEY_NAME + r"|"
                + MONEY_NAME + r".*parseFloat\s*\("),
     "parseFloat() on a money value"),
    # amount.toFixed(2)
    (re.compile(MONEY_NAME + r"[\w.\]\)]*\.toFixed\s*\("),
     "toFixed() on a money value (formatting as arithmetic)"),
    # amount: number -> only flag when a float-y default or division appears
    (re.compile(MONEY_NAME + r"\s*[:=][^;\n]*/\s*100\b"),
     "division by 100 produces a fractional money value"),
]

CREATE_CALL = re.compile(
    r"(?i)\b(?:payments?|charges?|refunds?|paymentIntents?)\s*\.\s*create\s*\(|"
    r"\bcreate(?:Payment|Charge|Refund)\w*\s*\(")
IDEMPOTENCY = re.compile(r"(?i)idempotency[-_]?key|idempotencyKey")
WINDOW = 8  # lines after the call that may carry its options object

LOG_CALL = re.compile(
    r"\b(?:console\.(?:log|info|warn|error|debug)|"
    r"(?:logger|log|this\.logger|this\.log)\.(?:info|warn|error|debug|trace|log))\s*\(")
SENSITIVE = re.compile(
    r"(?i)\b(?:card(?:Number|_number|holder\w*)?|pan|cvv|cvc|cvv2|"
    r"expiry\w*|exp(?:Month|Year)|iban|ssn|dateOfBirth|dob)\b")
MASKED = re.compile(r"(?i)last4|lastFour|masked|redact")

CURRENCY = re.compile(r"""(?i)\bcurrency\w*\s*[:=]\s*(['"`])([^'"`]*)\1""")
ISO_4217 = re.compile(r"^[A-Z]{3}$")


def lines_from_diff(text):
    """Yield (path, line_number, text, touched) for the new side of a diff.

    Context lines are yielded too (touched=False) so that a rule can look
    at the code around a change; findings are only reported on lines the
    change touched. A deletion marks the next new-side line as touched.
    """
    path, new_line, pending_delete = None, 0, False
    hunk = re.compile(r"^@@ -\d+(?:,\d+)? \+(\d+)(?:,\d+)? @@")
    for raw in text.splitlines():
        if raw.startswith("+++ "):
            target = raw[4:].strip()
            path = target[2:] if target.startswith("b/") else target
            continue
        if raw.startswith("--- "):
            continue
        m = hunk.match(raw)
        if m:
            new_line = int(m.group(1))
            continue
        if path is None:
            continue
        if raw.startswith("+"):
            yield path, new_line, raw[1:], True
            new_line += 1
            pending_delete = False
        elif raw.startswith("-"):
            pending_delete = True
        elif raw.startswith(" ") or raw == "":
            yield path, new_line, raw[1:], pending_delete
            new_line += 1
            pending_delete = False


def lines_from_files(paths):
    for p in paths:
        with open(p, encoding="utf-8") as fh:
            for i, line in enumerate(fh, 1):
                yield p, i, line.rstrip("\n"), True


def check(lines):
    lines = list(lines)
    findings = []

    def add(rule, path, n, msg, text):
        findings.append({"rule": rule, "file": path, "line": n,
                         "message": msg, "code": text.strip()[:120]})

    for idx, (path, n, text, touched) in enumerate(lines):
        stripped = text.strip()
        if stripped.startswith(("//", "*", "#")):
            continue
        if CREATE_CALL.search(text):
            span = [(t, tt) for (p, _, t, tt) in lines[idx:idx + WINDOW + 1]
                    if p == path]
            # Report when the change touched the call or its options object.
            if any(tt for _, tt in span) and \
                    not any(IDEMPOTENCY.search(t) for t, _ in span):
                add("MR002", path, n,
                    "payment/charge/refund created without an idempotency key",
                    text)
        if not touched:
            continue
        for pattern, msg in FLOAT_PATTERNS:
            if pattern.search(text) and not MINOR_OK.search(text):
                add("MR001", path, n, msg, text)
                break
        if LOG_CALL.search(text) and SENSITIVE.search(text) \
                and not MASKED.search(text):
            add("MR003", path, n, "card or personal data passed to a logger",
                text)
        for m in CURRENCY.finditer(text):
            if not ISO_4217.match(m.group(2)):
                add("MR004", path, n,
                    "currency %r is not an upper-case ISO 4217 code"
                    % m.group(2), text)
    return findings


def main(argv=None):
    ap = argparse.ArgumentParser(
        description="Check a diff or files against Meridian's money rules.")
    src = ap.add_mutually_exclusive_group(required=True)
    src.add_argument("--diff", metavar="FILE",
                     help="unified diff to check ('-' reads stdin); "
                          "only added lines are checked")
    src.add_argument("--files", nargs="+", metavar="PATH",
                     help="source files to check in full")
    ap.add_argument("--format", choices=["text", "json"], default="text")
    args = ap.parse_args(argv)

    try:
        if args.diff:
            text = sys.stdin.read() if args.diff == "-" else \
                open(args.diff, encoding="utf-8").read()
            findings = check(lines_from_diff(text))
        else:
            findings = check(lines_from_files(args.files))
    except OSError as exc:
        print("error: cannot read input: %s" % exc, file=sys.stderr)
        return 2

    if args.format == "json":
        print(json.dumps({"findings": findings, "count": len(findings)},
                         indent=2))
    else:
        for f in findings:
            print("%s:%d: %s %s" % (f["file"], f["line"], f["rule"],
                                    f["message"]))
            print("    %s" % f["code"])
        print("%d finding(s)" % len(findings))
    return 1 if findings else 0


if __name__ == "__main__":
    sys.exit(main())
