Here are my suggestions for clearer phrasing:

**Current:**
> TypeScript payment service for Meridian. Handles card charges and refunds.
> Run the build, then the tests, before you open a pull request.

**Issues:**
1. **Ambiguous context** — "for Meridian" assumes the reader knows what Meridian is. Consider clarifying the domain.
2. **Vague scope** — "Handles card charges and refunds" could be more specific about what operations are supported.
3. **Instruction flow** — The last line mixes description with commands and could be clearer and more actionable.

**Suggested rewording:**

> # meridian-checkout
>
> TypeScript payment service for the Meridian platform. Processes credit card charges and refunds.
>
> ## Before opening a pull request
>
> 1. Run the build
> 2. Run the tests

Or more concisely:

> TypeScript payment service for the Meridian platform. Processes credit card charges and refunds.
>
> **Before submitting a pull request:** build and run tests.

The improvements:
- "for the Meridian platform" is slightly clearer than just "for Meridian"
- "Processes credit card charges and refunds" is more specific than "Handles"
- Breaking the PR workflow into a section or explicit steps makes it easier to follow
- "Before submitting" is more direct than "before you open"