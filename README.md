# ClaudeTemplating — Shared Claude Code Commands Repo

A shared repository of reusable Claude Code commands, snippets, project templates,
and requirements-interview prompts, organised by project type. `setup.sh` assembles
the correct subset of these files into a new project based on the project type you
choose.

## What's in here

```
generic/                 # Applies to every project type
  claude-snippets/       # CLAUDE.md building blocks (wiki contract, git workflow)
  commands/              # Slash commands copied into every project
godot/                   # Godot-game assets
  claude-snippets/       # Godot conventions snippet
  commands/              # Godot-specific slash commands
  templates/             # Files copied into the project tree (preserving structure)
interviews/
  base.md                # The core requirements interview
  overlays/              # Per-project-type interview additions (e.g. godot-game.md)
setup.sh                 # The assembler
```

Snippets in `claude-snippets/` are concatenated into a starter `CLAUDE.md`. Files in
`commands/` follow the [Claude Code slash-command format](https://code.claude.com/docs/en/slash-commands):
each `.md` file under a project's `.claude/commands/` becomes `/<filename>` (optional
YAML frontmatter such as `description` and `argument-hint` controls how it appears in
autocomplete).

## Using it for a new project

1. Make this repo available on the machine and point `CLAUDE_SHARED_REPO` at it
   (see below).
2. From the root of your **new project**, run the assembler:

   ```bash
   "$CLAUDE_SHARED_REPO/setup.sh"            # interactive menu
   "$CLAUDE_SHARED_REPO/setup.sh" godot-game # skip the menu
   ```

   Supported project types: `generic`, `godot-game`.

3. `setup.sh` will:
   - Create `.claude/commands/`, `docs/wiki/`, and `scripts/` if missing.
   - Copy the generic commands plus any project-type commands into `.claude/commands/`.
   - Copy the project-type `templates/` into your project root (never overwriting
     existing files).
   - Assemble a starter `CLAUDE.md` from the snippets (only if one does not already
     exist), ending with a `## Project` section for you to fill in.
   - Assemble `INTERVIEW.md` from `interviews/base.md` plus the matching overlay.

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
2. Add an interview overlay at `interviews/overlays/<project-type>.md` (optional).
3. Register the type in `setup.sh`:
   - Add it to the `PROJECT_TYPES` array.
   - Add a `case` entry in `asset_dir_for()` mapping the project type to its folder
     (the project type and folder name can differ, e.g. `godot-game` → `godot`).

## Updating an existing project when shared snippets change

1. Pull the latest in this repo (or let `setup.sh` do it — it runs `git pull` first).
2. Re-run `setup.sh <project-type>` from the project root.
3. Commands and templates are re-copied (templates never overwrite existing files);
   `CLAUDE.md` is **not** overwritten if it already exists. Review the diff with
   `git diff` and reconcile any snippet changes into your project's `CLAUDE.md` by
   hand.
