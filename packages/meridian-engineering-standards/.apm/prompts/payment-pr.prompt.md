---
description: Prepare a pull request for a change to a Meridian payment service
input:
  - ticket: "Ticket ID, for example PAY-142"
---

Prepare a pull request description for the current branch.

1. Summarize what changed and why in three sentences or fewer, and
   reference ${input:ticket}.
2. Run the `meridian-code-review` skill on the diff against `main` and
   paste its report unchanged.
3. Under "Payment standards", state for each rule in the payment
   standards instructions whether the change touches it and how.
4. List anything you could not verify. Do not claim tests pass unless
   you ran them.
