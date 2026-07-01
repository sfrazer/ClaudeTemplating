---
description: Export a shareable, unsigned macOS .app via scripts/export.sh, verify the pack, and zip it for hand-off.
---

Produce a shareable, unsigned macOS `.app` for this Godot project. This command is a thin
wrapper around `scripts/export.sh` — it does **not** reimplement export logic. Throughout,
substitute `<AppName>` with the `APP_NAME` you set in `scripts/export.sh`.

Run each script/command bare — do not pipe, redirect, or chain the export step with others
(see Bash Conventions). The pack-verification step in 3 genuinely needs a pipeline; run it
as its own command and expect a permission prompt.

1. **Pre-flight — STOP if any of these are unmet** (do not continue):
   - **The Godot editor is quit.** A running editor caches `project.godot` /
     `export_presets.cfg` in memory, while the CLI reads what is on disk — the usual cause
     of stale-config export errors (ETC2 disabled, "preset not found").
   - **The macOS export templates for this Godot version are installed**
     (Editor → Manage Export Templates…). A headless export fails without them.
   - **`scripts/export.sh` exists** and its `APP_NAME` / `PRESET` are set for this project.
     If the script does not exist, report that export is not configured for this project and
     stop — do not treat this as a failure.

2. **Export.** Run the exporter from the project root:

    scripts/export.sh

   It resolves the Godot binary (`GODOT_BIN`, then `godot4`/`godot` on PATH, then the default
   macOS app path), imports assets first, exports the configured unsigned preset to
   `build/<AppName>.app`, and reports and propagates its exit code. **If it exits non-zero,
   stop and fix the export — do not zip a failed build.**

3. **Verify the pack before hand-off — PROJECT-SPECIFIC, fill this in.** An export can
   succeed yet ship broken data: a runtime `res://` directory scan that ignores the `.remap`
   suffix returns nothing in an exported build (see "A runtime `res://` directory scan must
   tolerate the `.remap` suffix" in the Godot conventions). Grep the packed `.pck` for the
   resources your code loads via a **directory scan** and assert the count matches the source
   count and is non-zero.

   Replace the path/glob below with your directory-scanned resources. Example from the
   origin project (a `catalogue/` of `.tres` parts):

    grep -a -o "catalogue/[a-z_]*\.tres" "build/<AppName>.app/Contents/Resources/<AppName>.pck" | sort -u | wc -l
    ls source/data/catalogue/*.tres | wc -l

   The two counts must be **equal and greater than zero**. If the packed count is zero (or
   less than the source count), the export shipped empty data — stop and fix the scan (strip
   a trailing `.remap` before the extension check) before handing off.

4. **Zip for hand-off:**

    ditto -c -k --keepParent build/<AppName>.app build/<AppName>.zip

5. **Print recipient instructions** for the unsigned build. Because it is unsigned, Gatekeeper
   will block a normal double-click. Tell the recipient to either:
   - Right-click the app → **Open**, then confirm — macOS remembers the choice thereafter; or
   - Clear the quarantine attribute:

        xattr -dr com.apple.quarantine /path/to/<AppName>.app
