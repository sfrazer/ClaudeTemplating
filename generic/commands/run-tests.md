---
description: Run the full test suite via scripts/run_tests.sh and report results.
---

Run the full test suite and report results.

1. If `scripts/run_tests.sh` does not exist, report that tests are not configured
   for this project and stop — do not treat this as a failure.
2. Otherwise run `scripts/run_tests.sh` from the project root. Run it bare — do not
   pipe, redirect, or chain it with other commands (see Bash Conventions). The script
   prints a summary line and propagates its exit code, so read its output directly.
3. If any tests fail, stop and fix them before proceeding.
4. Do not open a PR with known test failures.
