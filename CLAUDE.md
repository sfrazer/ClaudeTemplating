# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## What this repo is

This is **not** an application — it's a shared library of Claude Code commands, snippets, project templates, and requirements-interview prompts. `setup.sh` assembles a subset of these files into a *target* project based on its project type. So most files here (`generic/commands/*.md`, `generic/claude-snippets/*.md`, `godot/templates/...`) are payloads installed elsewhere, not code that runs here.

Two scripts do the work:
- `setup.sh` — copies the right assets into the current project and writes `.claude/.template-manifest` (records a sha256 for each installed file).
- `check-updates.sh` — compares the manifest against the shared repo to report/apply drift (NEW, UPDATE, LOCALLY_MODIFIED, SNIPPET_DRIFT, etc.). Snippet changes are **report-only** — never auto-applied, because the target's `CLAUDE.md` is hand-assembled from snippets.

`lib/common.sh` is sourced by both scripts (do not execute it directly); it defines the supported-types contract.

## Bash conventions

**Authoring the scripts:**
- All scripts use `set -euo pipefail` and must be fully `shellcheck`-clean.
- Private helpers are prefixed with `_`.
- `shasum -a 256` is used for hashes (macOS has no `sha256sum`) — keep it.

**Running commands (keep them auto-approvable):** Invoke the test harness, the gate
commands, and one-off checks as plain, standalone commands — one per call. Do not chain
them with `&&`/`;`, pipe them into `grep`/`head`/`tail`, add `>`/`2>&1` redirection, or
wrap them in `$(...)`. A compound line cannot be statically analyzed by the permission
system and forces a manual approval, whereas separate bare commands stay auto-approvable.
`./tests/run.sh` already prints a summary and returns non-zero on failure, so there is no
need to filter its output. Prefer the simplest command that does the job; reach for a
pipeline only when a task genuinely needs one (and expect to approve it). This is the
same rule the generated projects get via the Bash Conventions snippet — we follow it here
too.

## Before committing changes to setup.sh / check-updates.sh / lib/common.sh

Run each of these as its own command (don't chain or pipe them — see Bash conventions):
```
shellcheck setup.sh check-updates.sh lib/common.sh tests/*.sh
bash -n setup.sh
bash -n check-updates.sh
./tests/run.sh      # the test harness — assembly, drift detection, settings.json, common.sh
```
The harness builds a `.git`-less copy of the asset trees in a temp dir and runs the
real scripts against it, so it is offline and side-effect free. Add a `test_*` function
to the matching `tests/test_*.sh` when you change behaviour. `./tests/run.sh <name>` runs
just `tests/test_<name>.sh`.

## Editing gotchas

- **Snippet concatenation order is hard-coded.** Generic snippets are listed explicitly (`wiki-contract.md`, `git-workflow.md`, then `bash-conventions.md`) in `setup.sh` (~line 129), not globbed — adding or renaming a generic snippet means updating that array. Asset-type snippets after them are sorted alphabetically.
- **Templates compose generic + asset.** `setup.sh` copies `generic/templates/` into every project and then the project-type's `templates/` on top (via `copy_templates_from`); `check-updates.sh`'s `enumerate_candidates` mirrors the same two-tier walk. Keep the two in sync — a template only reachable by one of them will show as perpetual drift or never install. `cp` preserves mode, so shell scripts checked in at 0755 arrive executable.
- **Adding a project type is a contract change in `lib/common.sh`:** add it to the `PROJECT_TYPES` array *and* map it to its asset folder in `asset_dir_for`. Then create that asset directory (e.g. `commands/`, `claude-snippets/`, `templates/`).

## Environment

- `CLAUDE_SHARED_REPO` points to this repo (defaults to `~/.claude-shared`). Scripts exit with guidance if it's unset and the default is missing.

## Git conventions

Branch names are descriptive kebab-case. Commit messages are prefixed `feat:` / `fix:` / `chore:`. Squash-merge to `main`; never commit directly to `main`.
