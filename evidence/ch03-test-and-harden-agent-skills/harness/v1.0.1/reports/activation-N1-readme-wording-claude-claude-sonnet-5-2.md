Current text:

> TypeScript payment service for Meridian. Handles card charges and refunds.
> Run the build, then the tests, before you open a pull request.

Suggestions:

1. **Line 3** — "Handles card charges and refunds" is fine, but pairing it with the first sentence as two short fragments reads choppily. Consider combining: "Meridian's TypeScript payment service for processing card charges and refunds." This also clarifies "meridian-checkout" is *the* service, not *a* service among several.

2. **Line 4** — "Run the build, then the tests, before you open a pull request" is a command-like instruction dropped into project description without transition. Two improvements:
   - Make it explicit these are commands to run, not just a sequence of ideas: "Before opening a pull request, run the build and test suite." (also fixes the slightly awkward "then the tests" construction)
   - If there are actual npm scripts (e.g., `npm run build && npm test`), naming them directly would be clearer than prose, e.g.: "Before opening a pull request, run `npm run build && npm test`."

Tightened version:

```
# meridian-checkout

Meridian's TypeScript payment service for processing card charges and refunds.

Before opening a pull request, run the build and test suite (`npm run build && npm test`).
```

Let me know if you'd like me to apply this.