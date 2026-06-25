# Shared Claude Code Commands Repo — Setup Prompt

---

You are setting up a shared GitHub repo that stores reusable Claude Code commands,
hooks, project templates, and interview prompts, organised by project type. The repo
will be used across multiple machines. A `setup.sh` script assembles the correct
subset of these files into a new project repo based on project type.

Before writing any files, look up the current Claude Code documentation for:
- The correct structure for slash command files in `.claude/commands/`

Use the live documentation, not your training data.

---

## Step 0 — Create the GitHub repo (optional)

If the repo does not already exist, create it now using the `gh` CLI:

```bash
gh repo create <repo-name> --private --clone
cd <repo-name>
```

If the repo already exists and you are inside it, skip this step.

---

## Target repo structure

```
generic/
  claude-snippets/
    wiki-contract.md
    git-workflow.md
  commands/
    code-review.md
    run-tests.md
godot/
  claude-snippets/
    godot-conventions.md
  commands/
    screenshot-check.md
  templates/
    source/
      debug/
        tests/
          godot_screenshot.sh
          screenshot_helper.gd
interviews/
  base.md
  overlays/
    godot-game.md
setup.sh
README.md
```

---

## File contents

### `generic/claude-snippets/wiki-contract.md`

```markdown
## Wiki Contract

The wiki is the authoritative record of all project decisions. It lives in `docs/wiki/`.

**Reading:** Before making any architectural, behavioural, or design decision, check
the relevant wiki document. Do not fill gaps from assumptions — if the wiki is silent
on something, flag it and ask before proceeding.

**Writing:** When a decision is made that is not yet in the wiki, update the relevant
document before closing the task. If a wiki document contains something incorrect,
correct it as part of the same task. Treat an out-of-date wiki as a bug.

**Pre-PR check:** Before opening any pull request, confirm that all wiki documents
reflect the current state of the code. An out-of-date wiki is a merge blocker.
```

---

### `generic/claude-snippets/git-workflow.md`

Inline the full contents of the Godot-specific section from the project's existing
`Claude-git-workflow.md`. This includes:
- Branch strategy
- Commit timing
- What not to commit
- Pre-PR checklist
- Project specific notes

Do not summarise — copy the content in full so it is authoritative for worker agents.

---

### `generic/commands/code-review.md`

```markdown
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
```

---

### `generic/commands/run-tests.md`

```markdown
Run the full test suite and report results.

1. Run `scripts/run_tests.sh` from the project root.
2. If any tests fail, stop and fix them before proceeding.
3. Do not open a PR with known test failures.
```

---

### `godot/claude-snippets/godot-conventions.md`

Inline the full contents of the Godot-specific section from the project's existing
`Claude-Godot-Generic.md`. This includes:
- Project structure
- Scene ownership rules
- Scene tree layer order
- Project settings checklist
- GDScript conventions
- Key rules (the four physics/sprite gotchas)
- Spawner system
- Level loading
- Debug tools
- Unit testing (GUT)
- Visual verification (screenshot)

Do not summarise — copy the content in full so it is authoritative for worker agents.

---

### `godot/commands/screenshot-check.md`

```markdown
Run the Godot screenshot tool and analyse the output for errors.

1. Run the screenshot helper script:

`source/debug/tests/godot_screenshot.sh`

To capture a specific scene:

`source/debug/tests/godot_screenshot.sh res://path/to/scene.tscn /tmp/task_screenshot.png`

To open the result in Preview after capture (macOS) (only do this if user requests seeing the screenshot):

`source/debug/tests/godot_screenshot.sh --preview res://path/to/scene.tscn /tmp/task_screenshot.png`

2. Check the exit code. A non-zero exit means errors were detected in the log —
   review them before proceeding.
3. If the screenshot was saved, examine it visually and confirm the scene renders
   as expected.
4. If errors are present, address them before marking the task complete.
```

---



### `godot/templates/source/debug/tests/godot_screenshot.sh`

```bash
#!/usr/bin/env bash
# godot_screenshot.sh — render a Godot scene, save a screenshot, check for errors
#
# Temporarily adds a screenshot autoload to project.godot, runs the project
# headlessly (or with display), saves a PNG, then restores project.godot.
#
# Usage:
#   godot_screenshot.sh [--preview] [scene_path] [output_png]
#
# Arguments (any order):
#   --preview      Open result in Preview.app after capture (macOS)
#   scene_path     res:// path to run as main scene (optional; uses project default)
#   output_png     Where to save the result (default: /tmp/godot_screenshot.png)
#
# Exits non-zero if any SCRIPT ERROR or ERROR lines appear in the log.

set -euo pipefail

PREVIEW=false
SCENE=""
OUTPUT="/tmp/godot_screenshot.png"
LOG="/tmp/godot_screenshot.log"

for arg in "$@"; do
  case "$arg" in
    --preview) PREVIEW=true ;;
    res://*) SCENE="$arg" ;;
    *.png) OUTPUT="$arg" ;;
  esac
done

GODOT=$(command -v godot4 2>/dev/null \
  || command -v godot 2>/dev/null \
  || echo "/Applications/Godot.app/Contents/MacOS/Godot")

if [[ ! -x "$GODOT" ]]; then
  echo "ERROR: Godot not found at $GODOT" >&2
  exit 1
fi

SCRIPT_DIR="$(cd "$(dirname "$0")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/../../.." && pwd)"
PROJECT_GODOT="$PROJECT_ROOT/project.godot"
PROJECT_GODOT_BAK="$PROJECT_ROOT/project.godot.screenshot_bak"
HELPER_PATH="res://source/debug/tests/screenshot_helper.gd"

cp "$PROJECT_GODOT" "$PROJECT_GODOT_BAK"

cleanup() {
  if [[ -f "$PROJECT_GODOT_BAK" ]]; then
    mv "$PROJECT_GODOT_BAK" "$PROJECT_GODOT"
  fi
}
trap cleanup EXIT

{
  cat "$PROJECT_GODOT_BAK"
  echo ""
  echo "[autoload]"
  echo ""
  echo "ScreenshotHelper=\"*$HELPER_PATH\""
} > "$PROJECT_GODOT"

ARGS=("--path" "$PROJECT_ROOT")
if [[ -n "$SCENE" ]]; then
  ARGS+=("--scene" "$SCENE")
fi

export SCREENSHOT_PATH="$OUTPUT"

echo "Rendering..."
"$GODOT" "${ARGS[@]}" > "$LOG" 2>&1 || true

if grep -qE "^ERROR|SCRIPT ERROR" "$LOG"; then
  echo "=== Errors detected ===" >&2
  grep -E "^ERROR|SCRIPT ERROR" "$LOG" >&2
  exit 1
fi

if [[ -f "$OUTPUT" ]]; then
  echo "Screenshot saved: $OUTPUT"
  if $PREVIEW; then
    open "$OUTPUT"
  fi
else
  echo "WARNING: Screenshot file not written. Check $LOG for details." >&2
fi

exit 0
```

---

### `godot/templates/source/debug/tests/screenshot_helper.gd`

```gdscript
extends Node

# Autoload: captures a screenshot after WAIT_FRAMES rendered frames then quits.
# Activated by godot_screenshot.sh via a temporary project.godot override.
# Output path is read from OS environment variable SCREENSHOT_PATH,
# defaulting to /tmp/godot_screenshot.png.

const WAIT_FRAMES: int = 8

var _frames_waited: int = 0


func _process(_delta: float) -> void:
	_frames_waited += 1
	if _frames_waited < WAIT_FRAMES:
		return
	var path: String = OS.get_environment("SCREENSHOT_PATH")
	if path.is_empty():
		path = "/tmp/godot_screenshot.png"
	var image: Image = get_viewport().get_texture().get_image()
	image.save_png(path)
	print("Screenshot saved: ", path)
	get_tree().quit()
```

---

### `interviews/base.md`

```markdown
# Project Requirements Interview

> This file is assembled by setup.sh. Do not run it directly — run the assembled
> version in your project directory instead.

You are acting as a senior software architect conducting a structured requirements
interview. Your job is to gather everything needed to produce six output documents
at the end of this session:

1. **Product brief** — what the project is, who it's for, and what success looks like
2. **User stories** — key user actions and experiences, prioritised
3. **Architecture plan** — system boundaries, module responsibilities, data flow
4. **Platform & delivery plan** — per-platform constraints, distribution targets,
   performance envelope
5. **Memory & context store schema** — what documents the wiki needs, what goes in
   each one
6. **Build plan** — work broken into discrete, scoped tasks ready for delegation to
   worker agents

Do not produce any of these documents yet. Interview me first.

## Interview rules

- Ask **one question at a time**. Wait for my answer before continuing.
- Start broad, move to specific.
- If an answer is vague, probe it once before moving on.
- When you have enough on a topic, explicitly say "moving on" and shift to the next.
- Keep a running mental model of what you have been told. Do not ask things already
  answered.
- After all areas are covered, summarise what you have heard and ask me to confirm
  or correct before producing any documents.

## Interview areas

### 1. Project identity
What is this project? What problem does it solve or experience does it create?
Is there a reference product or aesthetic you are targeting?

### 2. User experience & scope
Who are the users? What is the minimum viable feature set versus the full vision?
Are there features that are non-negotiable on day one?

### 3. Platform targets & constraints
Which platforms must ship together versus which can come later? Are there
platform-specific UX expectations? What is the performance floor?

### 4. Technical preferences & constraints
Is there an existing codebase, engine preference, or language constraint? Any
tooling, frameworks, or libraries already decided?

### 5. AI & agent workflow
Will AI be used only during development, or also at runtime? What is the tolerance
for worker agent autonomy — large tasks or narrow ones? Is there a preference for
local models, cloud models, or both?

### 6. Memory & persistence
Does state need to persist across sessions? Is there a server, or is this fully
client-side? For the development wiki — is there a preferred format?

### 7. Team & process
Sole developer or team? Rough timeline or milestone target? Which phase do you want
to reach first — prototype, vertical slice, full build?

### 8. Open risks & unknowns
What is the part of this project you are least certain about? Are there technical
bets being made that have not been validated yet?

## When the interview is complete

Summarise what you have learned across all eight areas. Ask me to confirm, correct,
or add anything. Once confirmed, do the following in order:

1. Write the six output documents directly into `docs/wiki/` using these filenames:
   - `docs/wiki/product-brief.md`
   - `docs/wiki/user-stories.md`
   - `docs/wiki/architecture.md`
   - `docs/wiki/platform-delivery.md`
   - `docs/wiki/json-schema.md` (or omit if not applicable)
   - `docs/wiki/build-plan.md`

2. Update `CLAUDE.md` — do not replace it. A starter CLAUDE.md already exists with
   generic snippets baked in. Fill in only the project-specific sections:
   - Project name and description
   - The wiki table (one row per doc, with the correct trigger condition for each)
   - Intended project structure

   Leave all other sections untouched.

Write with precision and no hedging — these documents will be used by worker agents
throughout the build.

*Begin the interview now. Start with area 1.*
```

---

### `interviews/overlays/godot-game.md`

```markdown
## Overlay: Godot game

Apply these additions during the interview when the project type is a Godot game.

### Area 1 additions
- What kind of game — genre, tone, core loop?
- What does a single session feel like for a player?
- Is there a reference game or aesthetic you are targeting?

### Area 2 additions
- Single player or multiplayer? Synchronous or asynchronous?
- Are there mechanics that are non-negotiable on day one?

### Area 5 additions
- Will AI be used at runtime (e.g. AI opponents, procedural content)?

### Area 6 additions
- Does game state need to persist across sessions (saves, scores, unlocks)?
```

---

### `setup.sh`

Write a bash script that does the following:

1. Presents a TUI selection menu (using `select` or a simple numbered list) asking
   the user to choose a project type. Initially support:
   - `generic`
   - `godot-game`

2. Optionally accepts the project type as a command-line argument to skip the menu:
   ```bash
   ./setup.sh godot-game
   ```

3. Pulls the latest from the shared commands repo (this repo). The repo path should
   be configurable via an environment variable `CLAUDE_SHARED_REPO`, defaulting to
   a sensible location such as `~/.claude-shared`. If the environment variable is not found, exit with a useful message about how to configure it such as creating `~/.claude-shared`

4. Creates the following directories in the current project if they do not exist:
   - `.claude/commands/`
   - `docs/wiki/`
   - `scripts/`

5. Copies the assembled files into the project:
   - `generic/commands/*.md` → `.claude/commands/`
   - `<project-type>/commands/*.md` → `.claude/commands/`
   - Copies `<project-type>/templates/` into the project root, preserving directory
     structure, without overwriting existing files

6. Assembles `CLAUDE.md` from snippets in this order:
   - `generic/claude-snippets/wiki-contract.md`
   - `generic/claude-snippets/git-workflow.md`
   - `<project-type>/claude-snippets/*.md` (alphabetical order)
   - Appends a clearly marked `## Project` section with placeholder text for the
     user (or interview) to fill in

7. Assembles the interview prompt by concatenating:
   - `interviews/base.md`
   - `interviews/overlays/<project-type>.md` (if it exists)
   - Writes the result to `INTERVIEW.md` in the project root

8. Prints a short summary of what was copied and reminds the user to:
   - Run `INTERVIEW.md` in a fresh Claude Code session to complete project setup
   - Commit the assembled files to the project repo

Do not overwrite `CLAUDE.md` if it already exists.

---

### `README.md`

Write a README that explains:
- What this repo is and how it is used
- How to run `setup.sh` for a new project
- How to add a new project type (new folder, snippets, overlay, commands, hooks)
- How to update an existing project when shared snippets change (re-run `setup.sh`,
  review diffs)
- The `CLAUDE_SHARED_REPO` environment variable

---

## Final steps

Once all files are created:

1. Make `setup.sh` and all `.sh` files executable (`chmod +x`).
2. Create an initial commit with message `chore: initial repo scaffold`.
3. If the repo was created in step 0, push to GitHub: `git push -u origin main`. Otherwise create a branch and a PR