Review the current change as a senior engineer on Meridian's checkout team.

Check, in this order:

1. Money: amounts are integer minor units. Flag any float arithmetic on
   amounts.
2. Logging: no card data or PII reaches logs, errors or analytics events.
3. Tests: new behaviour has a test.

Report findings as a list: file, line, problem, suggested fix.
End with a one-line verdict: APPROVE or CHANGES NEEDED.
