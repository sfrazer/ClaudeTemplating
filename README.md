# ClaudeTemplating — Shared Claude Code Commands Repo

A shared repository of reusable Claude Code commands, snippets, project templates,
and requirements-interview prompts, organised by project type. `setup.sh` assembles
the correct subset of these files into a new project based on the project type you
choose.

## What's in here

```
generic/                 # Applies to every project type
  claude-snippets/       # CLAUDE.md building blocks (wiki contract, git workflow, bash conventions)
  commands/              # Slash commands copied into every project
  templates/             # Files copied into every project (e.g. scripts/code_review.sh)
godot/                   # Godot-game assets
  claude-snippets/       # Godot conventions snippet
  commands/              # Godot-specific slash commands
  templates/             # Files copied into the project tree (preserving structure)
love2d/                  # Love2D/Lua game assets
  claude-snippets/       # Love2D + Lua conventions snippet
  templates/             # Files copied into the project tree (e.g. scripts/run_tests.sh)
puppet/                  # Puppet control-repo assets (brownfield, Puppet 5 → 6)
  claude-snippets/       # Puppet conventions snippet
interviews/
  base.md                # The core requirements interview
  overlays/              # Interview additions by overlay name (e.g. game.md, shared by game types)
lib/
  common.sh              # Shared helpers sourced by both scripts
tests/                   # Dependency-free bash test harness (./tests/run.sh)
setup.sh                 # The assembler
check-updates.sh         # Detect/apply shared-repo changes in an existing project
```

Snippets in `claude-snippets/` are concatenated into a starter `CLAUDE.md`. The
generic snippets come first in a **fixed order** — `wiki-contract.md`, `git-workflow.md`,
then `bash-conventions.md` — followed by the project-type's snippets in **alphabetical**
order. (The generic order is hard-coded in `setup.sh` so the wiki contract always leads;
only asset snippets are sorted.) Files in `commands/` follow the
[Claude Code slash-command format](https://code.claude.com/docs/en/slash-commands):
each `.md` file under a project's `.claude/commands/` becomes `/<filename>` (optional
YAML frontmatter such as `description` and `argument-hint` controls how it appears in
autocomplete).

### Command prerequisites

- **`/code-review`** runs `scripts/code_review.sh` (shipped as a generic template),
  which drives the Ollama `pi` harness with a cloud model. Install the harness and make
  a model available; the model defaults to `glm-5.2:cloud` and can be overridden with
  the `CODE_REVIEW_MODEL` environment variable. The script keeps the model-defaulting
  logic out of the invocation so the command stays auto-approvable.
- **`/run-tests`** runs `scripts/run_tests.sh`. The Godot template ships a GUT runner
  there and the Love2D template a `busted` runner (resolved from `BUSTED_BIN` then
  `PATH`; install with `luarocks install busted`); for other project types the script is
  absent and the command reports "tests not configured" rather than failing — add your
  own `scripts/run_tests.sh` to enable the suite.
- **`/export-build`** (Godot) runs `scripts/export.sh` to produce a shareable, unsigned
  macOS `.app`, verifies the pack, and zips it for hand-off. The Godot template ships
  `export.sh`; set its `APP_NAME` and `PRESET` (a macOS *unsigned* export preset) for your
  project, and install the macOS export templates for your Godot version. Requires macOS
  (`ditto`, `xattr`).

## Using it for a new project

1. Make this repo available on the machine and point `CLAUDE_SHARED_REPO` at it
   (see below).
2. From the root of your **new project**, run the assembler:

   ```bash
   "$CLAUDE_SHARED_REPO/setup.sh"            # interactive menu
   "$CLAUDE_SHARED_REPO/setup.sh" godot      # skip the menu
   ```

   Supported project types: `generic`, `godot`, `love2d`, `puppet`.

3. `setup.sh` will:
   - Create `.claude/commands/`, `docs/wiki/`, and `scripts/` if missing.
   - Copy the generic commands plus any project-type commands into `.claude/commands/`.
   - Copy the generic `templates/` plus any project-type `templates/` into your project
     root, preserving structure (never overwriting existing files).
   - Assemble a starter `CLAUDE.md` from the snippets (only if one does not already
     exist), ending with a `## Project` section for you to fill in.
   - Assemble `.claude/settings.json` (only if one does not already exist) with
     permission allow-rules for the provided scripts, so Claude can run them bare
     without a permission prompt (see the Bash Conventions snippet).
   - Assemble `INTERVIEW.md` from `interviews/base.md` plus the matching overlay.
   - Write `.claude/.template-manifest` recording the project type and the
     install-time hash of every file it placed (used by `check-updates.sh`).

4. Run `INTERVIEW.md` in a fresh Claude Code session to complete project setup, then
   commit the assembled files to your project repo.

## The `CLAUDE_SHARED_REPO` environment variable

`setup.sh` finds this repo via `CLAUDE_SHARED_REPO`, defaulting to `~/.claude-shared`.
If neither the variable nor the default directory exists, the script exits with
instructions. Set it in your shell profile:

```bash
export CLAUDE_SHARED_REPO=/path/to/ClaudeTemplating
```

Or clone/symlink the repo to the default location:

```bash
git clone <repo-url> ~/.claude-shared
```

## Adding a new project type

1. Create a top-level folder for it (e.g. `web/`) with any of:
   - `claude-snippets/*.md` — concatenated into `CLAUDE.md` (alphabetical order).
   - `commands/*.md` — slash commands copied into `.claude/commands/`.
   - `templates/...` — files mirrored into the project root, preserving structure.
2. Add an interview overlay under `interviews/overlays/` (optional). Overlays are keyed
   by overlay name, not project type, so several types can share one — e.g. game types
   share `game.md`.
3. Register the type in `lib/common.sh` (shared by both scripts):
   - Add it to the `PROJECT_TYPES` array.
   - Add a `case` entry in `asset_dir_for()` mapping the project type to its asset folder
     (they usually match, but the mapping is kept explicit so a type can diverge).
   - Add a `case` entry in `overlay_for()` if the type has an interview overlay (return
     the overlay basename, e.g. `game`); omit it to get no overlay.

## Updating an existing project when shared files change

Use `check-updates.sh` from the project root. It compares the project's installed
files against the shared repo using the manifest `setup.sh` wrote, and tells new
commands/templates apart from ones you have edited locally:

```bash
"$CLAUDE_SHARED_REPO/check-updates.sh"            # report drift, exit non-zero if any
"$CLAUDE_SHARED_REPO/check-updates.sh" --apply    # install new/updated commands & templates
"$CLAUDE_SHARED_REPO/check-updates.sh" --apply --force  # also overwrite locally-edited files
```

Other flags: `--no-pull` (skip the `git pull` of the shared repo), `--type <type>`
(needed only in the no-manifest fallback below). The report groups findings as **NEW**,
**UPDATE**, **MISSING**, **LOCALLY MODIFIED**, **SNIPPET DRIFT**, and **REMOVED
UPSTREAM**; it exits non-zero while actionable drift remains, so it works in a pre-PR
check.

Notes:
- **Snippets are report-only.** They are concatenated into `CLAUDE.md`, which is
  hand-assembled, so the checker flags snippet changes but never edits `CLAUDE.md`.
  Reconcile those by hand (or re-run `setup.sh` in a throwaway dir and diff). Snippet
  drift keeps being reported until `CLAUDE.md` reflects the change.
- **Locally modified files** are skipped by `--apply` unless you add `--force`.
- **No manifest?** Projects set up before the manifest existed fall back to a direct
  content comparison (which cannot distinguish a local edit from an upstream update).
  Pass `--type <project-type>`, or just re-run `setup.sh <project-type>` once to
  generate a manifest for precise checks going forward.

## Changelog

Newest first; each entry links to its pull request.

### 2026-07-01

- **Godot macOS export tooling + export gotchas**
  ([#17](https://github.com/sfrazer/ClaudeTemplating/pull/17)) — adds an `/export-build`
  command (a thin wrapper around a shipped `scripts/export.sh` that produces an unsigned
  macOS `.app`, verifies the packed `.pck` for directory-scanned resources, zips it with
  `ditto`, and prints Gatekeeper-bypass instructions) and two Godot conventions rules: a
  runtime `res://` directory scan must tolerate the `.remap` suffix (or exported data
  silently vanishes), and asset references must match the file's on-disk case.
- **New `puppet` project type**
  ([#16](https://github.com/sfrazer/ClaudeTemplating/pull/16)) — adds a Puppet control-repo
  type aimed at an existing installation mid-migration from Puppet 5 to 6. Ships a
  `puppet-conventions.md` snippet (5→6 migration landmines like the removed-from-core
  resource types, roles & profiles, Hiera 5, idempotency/validation) and a brownfield
  interview overlay (`interviews/overlays/puppet.md`) that surveys the imported codebase
  first, then fills gaps and remaps the base output docs to a control repo. Conventions +
  interview only — no template/test runner yet. Registered in `lib/common.sh`.

### 2026-06-30

- **New `love2d` project type**
  ([#15](https://github.com/sfrazer/ClaudeTemplating/pull/15)) — adds a Love2D/Lua game
  type: a lean `love2d-conventions.md` snippet (Lua landmines, Love2D essentials, busted
  testing, references) and a `busted`-based `scripts/run_tests.sh`. Shares the `game`
  interview overlay with `godot`. Registered in `lib/common.sh` (`PROJECT_TYPES`,
  `asset_dir_for`, `overlay_for`).
- **Rename `godot-game` → `godot`; share one game interview overlay**
  ([#14](https://github.com/sfrazer/ClaudeTemplating/pull/14)) — the Godot project type
  is now just `godot` (matching its asset folder), and the interview overlay moves to
  `interviews/overlays/game.md`, resolved via a new `overlay_for` mapping in
  `lib/common.sh` so multiple game types can share it. **Breaking:** projects whose
  `.template-manifest` records `type=godot-game` should update it to `type=godot` (or
  re-run `setup.sh godot`) for `check-updates.sh` to keep working.
- **`code_review.sh` invokes `pi` directly**
  ([#13](https://github.com/sfrazer/ClaudeTemplating/pull/13)) — the generic code-review
  wrapper now pipes empty stdin into `pi --no-session` instead of `ollama launch pi`,
  keeping each review run stateless. Model defaulting and the auto-approvable bare-path
  invocation are unchanged.

### 2026-06-28

- **Godot conventions: input gotchas**
  ([#12](https://github.com/sfrazer/ClaudeTemplating/pull/12)) — add two real-world
  Godot notes to the godot-conventions snippet: buttons can get stuck "pressed" when a
  drag's mouse-release is consumed elsewhere (with the deferred `disabled` toggle fix),
  and headless GUT can't simulate GUI mouse interaction (so verify real capture/press
  routing in-app, not in unit tests).

### 2026-06-27

- **`SCREENSHOT_SETUP` hook for the godot screenshot helper**
  ([#10](https://github.com/sfrazer/ClaudeTemplating/pull/10)) — the screenshot helper
  can now run an optional `setup(scene)` hook (a `res://` GDScript, coroutine-aware) to
  drive a scene into a non-default state — selection handles, drag/hover, a loaded view —
  before capturing, instead of only the default first-frame state. Behaviour-preserving
  when unset; a misconfigured hook fails fast.

### 2026-06-26

- **Auto-approve `settings.json` + a test harness**
  ([#8](https://github.com/sfrazer/ClaudeTemplating/pull/8)) — `setup.sh` assembles a
  starter `.claude/settings.json` with permission allow-rules for the provided scripts
  (so Claude runs them bare without a prompt), and a dependency-free bash test harness
  lands under `tests/` (`./tests/run.sh`) covering assembly, drift detection,
  settings.json generation, and `lib/common.sh`. The Bash Conventions snippet is
  generalized to "prefer the simplest, standalone command."
- **Contract to run provided scripts bare**
  ([#7](https://github.com/sfrazer/ClaudeTemplating/pull/7)) — adds a Bash Conventions
  rule (and reinforces the `/run-tests` and `/screenshot-check` commands) telling Claude
  to invoke provided scripts as their own command; compound shell lines can't be
  statically analyzed and force a permission prompt.

### 2026-06-25

- **Bake auto-approvable tooling into the template**
  ([#6](https://github.com/sfrazer/ClaudeTemplating/pull/6)) — `setup.sh` can create a
  GitHub remote (on by default; `--no-repo`/`--public`; never touches an existing repo);
  ships `scripts/code_review.sh` (generic) and a fuller `scripts/run_tests.sh` (godot) as
  templates with `/code-review` pointing at the wrapper; templates now compose
  generic + asset.
- **Initial scaffold, `check-updates.sh`, and hardening fixes**
  ([#1](https://github.com/sfrazer/ClaudeTemplating/pull/1)–[#5](https://github.com/sfrazer/ClaudeTemplating/pull/5))
  — the assembler, the update checker, and early code-review/robustness fixes.
