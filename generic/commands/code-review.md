---
description: Run a code review with the configured Ollama model, save findings, and address them before any PR.
---

Run a code review using the Ollama `pi` harness.

Prerequisites: the Ollama `pi` harness must be installed and a review model
available. The model defaults to `glm-5.2:cloud` but can be overridden with the
`CODE_REVIEW_MODEL` environment variable.

1. Run the review harness from the project root and capture its full output:

    scripts/code_review.sh

   The script resolves the model internally (`$CODE_REVIEW_MODEL` if set, otherwise
   `glm-5.2:cloud`), so the invocation is a plain path with no brace expansion. To
   override the model for one run, use a plain assignment prefix:

    CODE_REVIEW_MODEL=some-model scripts/code_review.sh

2. Create the `docs/codereviews/` directory if it does not exist.
3. Capture the command's full output and save it to `docs/codereviews/` with a
   descriptive filename that includes the date and a short description of what was
   reviewed. (You — Claude — are responsible for writing the file; the command above
   does not redirect output itself.)
4. Read the saved output in full.
5. For each finding: either fix the issue, or write a brief explanation of why
   the finding is incorrect or does not apply. Document your responses alongside
   the review output.
6. Do not open a PR until all findings have been addressed or rebutted.
