# claude-git.md — Git Workflow Guidelines

---

### Branch Strategy

- Always create a new branch before starting work on a feature or system.
- Branch naming: use descriptive kebab-case names reflecting the feature (`spawner-system`, `player-combat`, `ui-pause-menu`).
- Never commit directly to `main`.
- Merge back to `main` via pull request with squash merge to keep history clean.
- After merging, pull `main` locally before starting the next branch.

---

### Commit Timing

Commit when:
- Something works that didn't before
- You're about to attempt something experimental
- End of a working session (work-in-progress commits on a branch are fine)

Do not wait until a large feature is complete. Small, frequent commits on a branch are preferable to one large commit.

---

### What Not to Commit

The `.gitignore` should exclude:
- Exported builds
- Editor configuration folders
- Local backup directories

The `.gitattributes` should route binary assets through Git LFS:
- `.png`, `.wav`, `.ogg`, `.mp3`, `.mp4`, and any other binary asset formats used in the project

Do not stage or commit files that match these exclusions. If in doubt, check `.gitignore` and `.gitattributes` at the repo root before staging.

---

### Pre-PR Checklist

Before opening any pull request, run the following steps in order:

1. Confirm wiki documents are up to date.
2. Run `/run-tests`. All tests must pass.
3. If any changes affected the UI, run `/screenshot-check` and analyse the output.
4. Run `/code-review`. Save the full output to `docs/codereviews/` with a descriptive name.
5. Address any findings from the review, or document why a finding is incorrect.
6. Only open the PR once all steps pass cleanly.

---

### Godot-Specific Note

When adding Git to an existing Godot project, Version Control Metadata must be initialized via `Project → Version Control → Create/Override Version Control Metadata` with Git selected. This only needs to be done once.

