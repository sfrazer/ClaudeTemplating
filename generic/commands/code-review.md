---
description: Run a code review with the Ollama cloud model, save findings, and address them before any PR.
---

Run a code review using the Ollama cloud model.

1. Run the following command from the project root:

    ollama launch pi --model glm-5.2:cloud -- -p "review this code and return your findings"

2. Create the `docs/codereviews/` directory if it does not exist.
3. Save the full output to `docs/codereviews/` with a descriptive filename that
   includes the date and a short description of what was reviewed.
4. Read the saved output in full.
5. For each finding: either fix the issue, or write a brief explanation of why
   the finding is incorrect or does not apply. Document your responses alongside
   the review output.
6. Do not open a PR until all findings have been addressed or rebutted.
