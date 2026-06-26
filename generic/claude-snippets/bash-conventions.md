## Bash Conventions

These rules keep the commands you type auto-approvable, so routine tasks (tests,
review, screenshots) run without a permission prompt. The permission system can only
auto-approve a command it can statically analyze — anything it cannot read falls back
to a manual approval.

**Prefer the simplest, standalone command.** Whenever possible, run one plain command
at a time rather than a compound shell line. Avoid `&&`/`;` chaining, pipes into
`grep`/`head`/`tail`, `>`/`2>&1` redirection, `$(...)` command substitution, and `echo`
banners — a compound line such as `./scripts/run_tests.sh 2>&1 | grep -E ... | head`
cannot be statically analyzed and will prompt, even when each part would be approved on
its own. If several things need doing (e.g. import, then test, then screenshot), run
them as separate bare commands instead of one chain. Reach for a pipeline only when a
task genuinely needs one, and expect to approve it.

This applies in particular to the **provided scripts** (`scripts/run_tests.sh`,
`scripts/code_review.sh`, `source/debug/tests/godot_screenshot.sh`, etc.): invoke each
as its own command — just the path, optionally a single `VAR=value` prefix and plain
arguments. They already print a concise summary and propagate their exit code, so run
each bare and read its output directly; there is no need to filter it.

**Keep commands free of brace expansion.** Do not put `${VAR:-default}` (default
expansion) or `${ARR[idx]}` (array subscript, e.g. `${PIPESTATUS[0]}`) in commands you
invoke directly — they trigger a brace-expansion alert that cannot be auto-approved.
Put that logic inside a script in `scripts/` and invoke the plain path. Plain `$?`,
`$VAR`, and `"$VAR"` are fine. To override an env var for one run, use a plain
assignment prefix: `VAR=value scripts/foo.sh`.
