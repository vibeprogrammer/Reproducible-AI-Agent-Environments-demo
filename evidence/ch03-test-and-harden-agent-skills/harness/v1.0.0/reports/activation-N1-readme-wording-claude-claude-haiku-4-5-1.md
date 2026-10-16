Here are some suggestions for clearer phrasing in the README:

**Line 3–4:**
- **Current:** "TypeScript payment service for Meridian. Handles card charges and refunds. Run the build, then the tests, before you open a pull request."
- **Issues:** 
  - "Handles card charges and refunds" is vague—what does "handles" mean? (process, validate, store?)
  - The instruction about build and tests sits oddly in the description; it reads like a requirement mixed with product description
  - No command examples given, so "Run the build" and "the tests" aren't actionable without digging elsewhere

**Clearer alternatives:**

1. **Separate description from workflow:**
   ```
   # meridian-checkout
   
   TypeScript payment service for Meridian that processes card charges and refunds.
   
   ## Getting Started
   
   Before opening a pull request, run:
   ```
   npm run build
   npm test
   ```
   ```

2. **Or, keep it brief but more specific:**
   ```
   # meridian-checkout
   
   Payment service for processing card charges and refunds. Built in TypeScript.
   
   Build and test before opening a pull request.
   ```

3. **Most concise with actionable next step:**
   ```
   # meridian-checkout
   
   Processes card charges and refunds for Meridian.
   
   Run `npm run build && npm test` before opening a pull request.
   ```

The main improvements: clarify what "handles" means, separate the workflow instruction from the description, and optionally include the actual commands so they're copy-paste ready.