## Bash Conventions

These rules keep the commands you type auto-approvable, so routine tasks (tests,
review, screenshots) run without a permission prompt. The permission system can only
auto-approve a command it can statically analyze — anything it cannot read falls back
to a manual approval.

**Run provided scripts bare.** Invoke a project script (`scripts/run_tests.sh`,
`scripts/code_review.sh`, `source/debug/tests/godot_screenshot.sh`, etc.) as its own
command — just the path, optionally a single `VAR=value` prefix and plain arguments.
Do **not** bundle it into a larger shell line: no `&&`/`;` chaining, no pipes into
`grep`/`head`/`tail`, no `>`/`2>&1` redirection, no `$(...)` command substitution, no
wrapping `echo` banners. A compound line such as
`./scripts/run_tests.sh 2>&1 | grep -E ... | head` cannot be statically analyzed and
will prompt, even though the script on its own would be approved. These scripts already
print a concise summary and propagate their exit code, so run each one bare and read
its output directly. When you need several (e.g. import, test, screenshot), run them as
separate bare commands — never one chain.

**Keep ad-hoc commands auto-approvable too.** Do not put `${VAR:-default}` (default
expansion) or `${ARR[idx]}` (array subscript, e.g. `${PIPESTATUS[0]}`) in commands you
invoke directly — they trigger a brace-expansion alert that cannot be auto-approved.
Put that logic inside a script in `scripts/` and invoke the plain path. Plain `$?`,
`$VAR`, and `"$VAR"` are fine. To override an env var for one run, use a plain
assignment prefix: `VAR=value scripts/foo.sh`.
