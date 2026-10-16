The README is short and already fairly clear, but a few tweaks would tighten it up:

1. **Line 3–4 run together as one paragraph** — "Handles card charges and refunds." and the build/test instruction are different kinds of information (what it does vs. how to work with it). Splitting them into separate lines/paragraphs would make the structure clearer at a glance.

2. **"Run the build, then the tests"** is a bit terse — it doesn't say *how* (no commands given). Since this is likely a Node/TypeScript project, something like "Run `npm run build`, then `npm test`, before opening a pull request" would be more actionable, assuming those are the actual commands.

3. **"before you open a pull request"** mixes second person ("you") with otherwise neutral, factual tone. Either consistently use instructional imperative ("before opening a pull request") or address the reader directly throughout — just for consistency.

4. Consider adding a one-line **purpose/context** sentence — e.g., why this service exists or what system it's part of (checkout flow for Meridian) — since "Handles card charges and refunds" tells *what* it does but not *where it fits*.

Suggested rewrite:

```markdown
# meridian-checkout

TypeScript payment service for Meridian, handling card charges and refunds.

Before opening a pull request, run the build and the test suite.
```

Want me to apply one of these, or just keep it as feedback for now?