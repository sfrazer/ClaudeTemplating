## Bash Conventions

**Keep Bash commands auto-approvable.** Do not put `${VAR:-default}` (default
expansion) or `${ARR[idx]}` (array subscript, e.g. `${PIPESTATUS[0]}`) in commands
you invoke directly — they trigger a brace-expansion permission alert that cannot be
auto-approved. Put that logic inside a script in `scripts/` and invoke the plain path.
Plain `$?`, `$VAR`, and `"$VAR"` are fine. To override an env var for one run, use a
plain assignment prefix: `VAR=value scripts/foo.sh`.
