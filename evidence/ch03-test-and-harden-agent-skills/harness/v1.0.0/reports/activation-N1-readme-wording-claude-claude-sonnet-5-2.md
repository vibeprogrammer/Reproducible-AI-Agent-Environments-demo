It's short and already fairly clear, but a couple tweaks would tighten it up:

1. **Line 3–4 split feels abrupt.** Consider merging the description and the instruction into a flow, or adding a blank line between them so they read as two distinct thoughts rather than a run-on:
   > TypeScript payment service for Meridian. Handles card charges and refunds.
   >
   > Run the build, then the tests, before you open a pull request.

2. **"Run the build, then the tests"** is a bit terse/ambiguous for a newcomer — it doesn't say *how*. Slightly clearer:
   > Before opening a pull request, run the build and test suite (e.g. `npm run build && npm test`).

   (Adjust the actual command to whatever this repo uses — I didn't see a package.json command referenced here.)

3. **"Handles card charges and refunds"** could be a touch more specific about scope, e.g. "Processes card charges and refunds" (slightly more active/precise verb than "handles").

Net suggestion:

> # meridian-checkout
>
> TypeScript payment service for Meridian. Processes card charges and refunds.
>
> Before opening a pull request, run the build and the test suite.

This keeps it just as short but makes the pre-PR instruction read as a clear action item rather than a terse fragment.