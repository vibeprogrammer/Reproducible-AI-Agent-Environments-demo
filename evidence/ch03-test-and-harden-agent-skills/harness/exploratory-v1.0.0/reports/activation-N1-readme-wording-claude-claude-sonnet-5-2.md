This is a very short README, so there's little to fix, but a few small clarity tweaks:

1. **Line 3** — "Handles card charges and refunds" is fine, but combining it with line 1 reads a bit terse. Consider: "A TypeScript payment service for Meridian that processes card charges and refunds." (adds articles/verb for smoother flow).

2. **Line 4** — "Run the build, then the tests, before you open a pull request" is ambiguous about *how* — doesn't say which commands. Consider something like: "Before opening a pull request, run the build (`npm run build`) and tests (`npm test`)." This also reorders to lead with the actionable condition ("Before X, do Y") rather than burying it at the end.

3. Minor: "then the tests" implies strict sequencing, but it's unclear if that's actually required (e.g., does the build need to succeed first?) or just a suggested order. If there's no real dependency, "Run the build and tests before opening a pull request" is clearer and avoids implying an enforced order that may not exist.

No factual/content changes needed — just tightening phrasing and making the instruction concrete (actual commands) if you want it fully actionable.