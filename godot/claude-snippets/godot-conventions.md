## Godot Conventions

Distilled from project architecture and lessons-learned documentation.

### Running Godot internally

Put a real `godot` (or `godot4`) executable on your `PATH`, or set the `GODOT_BIN`
environment variable to its full path — on macOS this is typically
`/Applications/Godot.app/Contents/MacOS/Godot`. Do **not** rely on a shell alias:
aliases are only available in interactive shells and are not visible to scripts such
as `godot_screenshot.sh`, which look up `GODOT_BIN`, then `godot4`/`godot` on `PATH`,
then the default macOS app path.

### Project Structure

```
assets/          # Raw art, textures, audio
source/
  core/          # MainGame scene, autoloads, high-level systems
  data/          # Resources and definitions (e.g. EnemyDefinition)
  gameplay/      # Player, enemies, NPCs, components, mechanics
  levels/        # Level scenes, scenery, level-specific objects
  shaders/
  ui/            # HUDs, menus, pause screens
  debug/         # Debug-only tools — must not ship
```

### Scene Ownership Rules

- **MainGame** is the application root and coordinator. It owns the layer structure, initializes systems, and handles scene transitions. It must not become a god object.
- **Level scenes** own geometry, TileMapLayers, backgrounds, environment settings, and spawn markers. Levels do NOT own the player.
- **Player** is instantiated by MainGame and added to the entity root. Level scenes expose spawn point markers; MainGame moves the player there.
- **Entity root** holds players, enemies, NPCs, pickups, and active objects — not embedded inside levels.
- **Effect root** holds temporary visual effects.
- UI layers (HUD, Pause, Transition, Debug) are separate CanvasLayers with explicit z-ordering. Leave gaps between layer values.

### Scene Tree Layer Order

| Layer         | Process Mode     |
|---------------|------------------|
| MainGame      | Always           |
| World         | Pausable         |
| HUD           | Pausable         |
| Pause         | When Paused      |
| Transition    | Always           |
| Debug         | Always           |

Set process modes intentionally — never rely on inherited defaults.

### Project Settings Checklist

Apply these before writing gameplay code:

- **Resolution:** Viewport 1920×1080 (or 1024×768). Dev window override: 2000×1200.
- **Stretch:** Mode = `canvas_items`, Aspect = `keep`, Scale Mode = `integer`.
- **Physics layer names:** World, Player, Enemy, Interactable (under Layer Names → 2D Physics and 2D Render).
- **Input map:** Name actions by intent (`jump`, `interact`, `shoot`, `pause`) not by button. Map each to both keyboard and controller. Add `debug_quit` → Escape. Add `sprint` for dev use even if not in final design.
- **UI mouse filter:** Set full-screen Control nodes to `Mouse Filter = Ignore`. Set DebugTextOverlay `Behavior Recursive = Disabled`.
- **Version:** Use `major.minor.patch` (start at `0.1.0`) under Application → Config → Version.
- **Debug overlay:** Show FPS and version string from project settings at startup.
- **FPS cap:** Always set before shipping. Also set during editor development to avoid fan noise.

### GDScript Conventions

- **Always use static typing.** Declare variable types explicitly. Enable `untyped declaration = warn` under Project Settings → Debug → GDScript.
- **Script section order:** Follow Godot's recommended layout (signals, enums, constants, exports, vars, onready, built-in overrides, public functions, private functions). Define this once and stick to it.
- Use `@onready` variables for node references; drag-and-drop with Ctrl in the editor to auto-format.

### Key Rules (Things That Caused Real Problems)

#### Never flip direction by negative X scale
Multiplying a node's X scale by -1 propagates to all children including Area2Ds, collision shapes, and raycasts. Visible collision shapes will look correct but physics interactions will be wrong.
- **Do:** Use `Sprite2D.flip_h` for visuals. Explicitly reposition or swap stored transforms for physics nodes.

#### Use `offset` not `position` for sprite alignment
`position` is inherited by children (including spawn markers and collision shapes). `offset` only affects the texture.
- **Rule:** Position = game truth. Offset = art alignment.

#### Be careful with `preload` in long-lived nodes
`preload` creates a persistent reference. If a node that never leaves the scene tree preloads a chain of scenes, those assets are never freed.
- **Do:** Keep preloads as close as possible to where they are used. A node that is removed should own its preloads so they are freed with it.

#### Do not place enemies directly in level scenes
Enemies placed in the level process continuously regardless of player proximity.
- **Do:** Use a spawner with `VisibleOnScreenNotifier2D` so enemies only exist when relevant.

#### Buttons can get stuck "pressed" after a drag
If a `BaseButton` (`TextureButton`, etc.) begins a drag on `button_down` and the drag's mouse-release is consumed elsewhere — e.g. a higher-priority `_input` handler calling `set_input_as_handled()` before the GUI sees it — the button never receives its `button_up` and Godot leaves it internally pressed. The next click on that button is swallowed (it just clears the stuck press); a *different* button working fine is the diagnostic tell.
- **Fix:** After the drag starts, clear the press state by toggling `disabled` true→false, deferred — so it runs after the current input frame and never renders disabled.

#### A runtime `res://` directory scan must tolerate the `.remap` suffix
In an exported build, Godot converts text resources and `DirAccess.get_files()` lists them as `<name>.tres.remap` (the `.remap` redirects `load()` to the packed binary), where in-editor they are plain `<name>.tres`. Code that scans a directory and filters on a `.tres`/`.tscn` extension matches nothing in the export, so the data silently vanishes — the editor looks fine but the export ships empty (this caused an empty parts box in a real export).
- **Do:** Strip a trailing `.remap` before the extension check; `load()` follows the remap in both environments. Verify the exported `.pck` actually contains the scanned resources (see the `/export-build` command's pack-verification step).

#### Asset references must match the file's on-disk case
macOS is case-insensitive, so a `.tscn`/`.tres` that references `res://assets/Foo.PNG` when the file on disk is `Foo.png` loads fine locally but fails on case-sensitive platforms and warns at export time ("Case mismatch"). The editor gives no error, so it's easy to commit.
- **Do:** Make each asset reference's case exactly match the file on disk.

### Spawner System

Each spawner is a `Marker2D` with a `VisibleOnScreenNotifier2D` and a `Timer`.

**EnemyDefinition resource** (custom resource) holds:
- `PackedScene` — the enemy scene
- `Texture2D` — editor preview
- Default spawn conditions for that enemy type

The spawner references an `EnemyDefinition`, not the scene directly. This decouples the spawner from enemy internals and makes level setup data-driven.

**Spawner state (explicit):**
- Has active instance?
- Is instance on screen?
- Is cooldown running?
- Is this a one-time spawn already used?
- Has it re-entered the screen (for re-entry mode)?

**Spawn check pattern:** All events (screen enter/exit, enemy death, timer) call a single deferred `_check_spawn()`. One function answers: am I blocked right now? If not, spawn.

**Instantiation:** Goes through a spawn manager that adds enemies to the entity root — not inside the level. This keeps the scene tree inspectable during debug.

**Respawn modes (examples):**
- One-time only
- Respawn after leaving and re-entering screen
- Respawn on timer with random delay
- Respawn immediately when visible and available

### Level Loading

All scene transitions go through a single `load_level()` function in MainGame. Callers never need to know the implementation details. The function:
1. Defers the change to idle frame
2. Frees the current level if one exists
3. Waits a frame for cleanup
4. Loads and instantiates the new scene, cast as `BaseLevel` (safety check)
5. Places the player at the level's spawn marker
6. Connects the camera

### Debug Tools

- **God mode:** Separate player state with fast movement, no gravity, hurtbox disabled. Dev only — do not ship.
- **Global time scale:** Use for debugging or slow-motion effects.
- **Alt + right-click** in editor: select specific overlapping nodes (requires select mode).
- **Favorite scenes:** Right-click in FileSystem to mark frequently used scenes.
- **Color folders/files:** Useful for navigating large projects.
- **MSDF fonts:** Enable under Project Settings → GUI → Theme → Font if fonts look blurry.

### Unit Testing (GUT)

This project uses [GUT (Godot Unit Test)](https://github.com/bitwes/Gut) for automated testing. If GUT is not already installed, install it from source.

#### What to Test

Any logic that can be tested in isolation should have a corresponding test. This includes:
- Spawner state and spawn condition checks
- EnemyDefinition resource validation
- Player state transitions
- Input handling logic
- Level loading and scene casting safety checks
- Any utility or data processing functions

UI layout, shader behavior, and physics interactions are out of scope for unit tests.

#### Test Location

Place tests under `source/debug/tests/` mirroring the structure of the source they cover.
For example, a test for `source/gameplay/spawner.gd` lives at `source/debug/tests/test_spawner.gd`.

#### Writing Tests

- Every test script must extend `GutTest`.
- Test methods must be prefixed with `test_`.
- Use `assert_eq`, `assert_true`, `assert_null` etc. rather than raw `assert`.
- Each test should cover one behavior. Prefer many small tests over fewer broad ones.
- Use `before_each` to reset state between tests rather than relying on test order.

#### Running Tests (Headless)

Run the full suite with the `/run-tests` command, which invokes `scripts/run_tests.sh`.
That script ships with the project template; it resolves the Godot binary (`GODOT_BIN`,
then `godot4`/`godot` on `PATH`, then the default macOS app path), runs
`--headless --import` first so a fresh clone or CI runner is set up, then runs the GUT
suite and prints and propagates its own exit code (so callers never need
`${PIPESTATUS[0]}` to read the result through a pipe).

If for some reason `scripts/run_tests.sh` is missing, run the suite directly:

```sh
godot --headless --import          # once, to import the project
godot --headless -s res://addons/gut/gut_cmdln.gd
```

**Important:** use `gut_cmdln.gd`, not `gut_cli.gd`. `gut_cli.gd` extends `Node` and cannot be used with `-s`; `gut_cmdln.gd` extends `SceneTree` and works correctly. GUT reads `.gutconfig.json` at the project root and exits non-zero if any tests fail.

#### When to Run Tests

- Run the full test suite before opening a pull request. All tests must pass.
- Run relevant tests after any change to a system that has test coverage.
- A failing test is a blocker — do not open a PR with known failures.

#### Known GUT Gotchas

- **`push_error` in tests causes failure.** GUT treats any `push_error` call during a test frame as an unexpected error, failing the test even if all assertions pass. Do not write tests that exercise code paths that call `push_error`.
- **JSON type mismatch on deserialize.** `JSON.parse_string()` returns an untyped `Array`; you cannot assign it directly to `Array[Dictionary]`. Iterate and append each element explicitly instead of using `.duplicate()`.
- **Empty string passed to `JSON.parse_string()`** triggers an engine-level error that GUT flags as unexpected. Guard with `if json_string.is_empty(): return false` before calling the parser.
- **Headless GUT can't simulate GUI mouse interaction.** Pushing synthetic InputEventMouseButtons via Viewport.push_input() does not drive Control mouse-picking in a headless run — the press never reaches the button, so any test that "clicks" a Control by position silently does nothing (it'll read as zero presses, not a failure). Godot's internal button press/capture state (status.press_attempt, viewport gui.mouse_focus) is also not settable from script. So bugs in real GUI capture/press routing can't be reproduced in unit tests — verify those in-app, and have tests guard the wiring and logic instead (signals emitted, state-clearing helpers behave, mode locks respected).

### Visual Verification (Screenshot)

For tasks that require visual confirmation that a scene renders correctly, use the claude command `/screenshot-check`
