Here are some suggestions for clearer phrasing in the README:

**Line 3:** "TypeScript payment service for Meridian. Handles card charges and refunds."
- **Suggestion:** "A TypeScript service that processes card charges and refunds for Meridian." This more clearly states the action and role of the service.
- Or: "Payment processing service for Meridian — handles card charges and refunds." (clearer separation of purpose and functionality)

**Line 4:** "Run the build, then the tests, before you open a pull request."
- **Issues:** 
  - Slightly awkward verb sequence ("run the build" vs "build the project")
  - The imperative tone without context feels like it belongs in a contributing guide, not the README intro
  
- **Suggestions:**
  - "Build and run tests before submitting a pull request." (more concise, parallel structure)
  - "Build the project and run tests before opening a pull request." (more explicit)
  - If this is meant as a development prerequisite, consider: "Before submitting a PR, run `npm run build && npm test`." (more actionable, shows the commands)

**Overall:** The README is very brief. Consider whether you want to add sections like Prerequisites, Installation, or Development to give context for that last instruction.