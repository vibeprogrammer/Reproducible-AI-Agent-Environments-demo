The README is short — here's a pass at clearer phrasing:

**Current:**
> TypeScript payment service for Meridian. Handles card charges and refunds.
> Run the build, then the tests, before you open a pull request.

**Issues:**
- "Run the build, then the tests" doesn't say *how* (no commands given) — a newcomer can't act on it.
- "Handles card charges and refunds" is slightly vague about scope (is this the service of record, or one of several?).

**Suggested rewording:**

```md
# meridian-checkout

A TypeScript service that processes card charges and refunds for Meridian.

Before opening a pull request, run the build and test suite:

    npm run build
    npm test
```

(Swap in the actual commands if they differ.) This keeps the same content but:
- Leads with "A TypeScript service that..." for a more natural sentence flow.
- Turns the instruction into an actionable checklist with real commands instead of a vague directive.