Here are my suggestions for clearer wording:

**Current:**
```
TypeScript payment service for Meridian. Handles card charges and refunds.
Run the build, then the tests, before you open a pull request.
```

**Suggested improvements:**

1. **First line:** Consider separating the purpose from the technology:
   - *"Payment service for Meridian that processes card charges and refunds"* — more active than "handles" and makes the service's role clearer upfront.

2. **Second line:** The instruction is clearer as a positive direction rather than a conditional:
   - *"Build and test your changes before opening a pull request"* — more direct and easier to scan.
   - Alternatively: *"Before submitting a pull request, run the build and tests"* — reorders for flow.

3. **Structural suggestion:** If this grows, consider a small "Getting Started" or "Contributing" section so the setup instructions don't live in the description:
   ```
   # meridian-checkout
   
   Payment service for Meridian that processes card charges and refunds.
   
   ## Contributing
   
   Build and test before opening a pull request.
   ```

The main issue is that "handles" is passive and "run...before you open" puts the action after the condition, making it slightly harder to parse quickly.