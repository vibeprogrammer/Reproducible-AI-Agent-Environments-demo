# Meridian money rules (detail)

LOAD this file when a change touches amounts, currencies, payment, charge or
refund creation, or logging. The checker script catches common shapes of
these violations; this file explains the rules so you can catch the rest.

## MR001: money is an integer count of minor units

Store, compute and transmit amounts as integers in the currency's minor
unit: cents for EUR and USD, ore for NOK. A field name should say so
(`amountMinor`, `totalMinor`).

Violations to look for:

- decimal literals in money fields (`amount: 19.99`);
- `parseFloat`, `Number(x) / 100`, or `toFixed` used in arithmetic rather
  than for display;
- summing or multiplying amounts that arrived as strings with a decimal
  point;
- rounding "fixes" such as `Math.round(total * 100) / 100`.

Formatting for display is fine at the edge (an `Intl.NumberFormat` call in a
view), as long as the value it formats is derived from integer minor units.

Not every currency has two decimal places (JPY has none, some have three).
Do not hard-code `100` as the minor-unit factor for every currency.

## MR002: every creating call carries an idempotency key

Any call that can create, capture or authorize a payment, charge, refund or
payout must send an idempotency key, so a retry after a timeout cannot move
money twice.
The key must be stable for the logical operation (derived from the order ID
or the incoming request's key), not generated fresh on every retry.

Violations to look for:

- a create call with no key;
- a capture or authorize call with no key (the checker looks for these
  since 1.1.0);
- a key built from `Date.now()`, `Math.random()` or a new UUID inside a
  retry loop;
- a retry wrapper that re-issues the call without passing the key through.

## MR003: never log card data or personal data

Never pass full card numbers (PAN), CVV/CVC, expiry dates, IBANs, national
ID numbers or dates of birth to a logger, an error message, an analytics
event or an exception that is reported externally. Log the payment ID, the
order ID, or a masked last-4.

Watch for whole objects being logged (`logger.info({ req })`,
`console.log(payment)`): the object may carry card fields even when the
line does not name them. The checker cannot see this case.

## MR004: ISO 4217 currency codes

Currency codes are the three-letter upper-case alphabetic codes from
ISO 4217 (`EUR`, `USD`, `NOK`). Symbols (`€`) and lower-case codes are not
accepted at Meridian's API boundary.
