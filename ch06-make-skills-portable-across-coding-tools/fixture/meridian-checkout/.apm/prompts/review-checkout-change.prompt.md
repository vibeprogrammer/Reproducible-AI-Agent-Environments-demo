---
description: Review the current change to meridian-checkout with the Meridian code-review skill.
input:
  - focus: "Optional focus area, for example idempotency or logging"
---

Review the staged change in this repository. Use the
`meridian-code-review` skill and its checker script. Focus on
${input:focus} when it is set; otherwise apply every rule.
Report blockers first, then suggestions, with file:line references.
