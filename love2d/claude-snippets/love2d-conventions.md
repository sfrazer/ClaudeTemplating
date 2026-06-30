## Love2D / Lua Conventions

Starter conventions for a [LÖVE](https://love2d.org/) (Love2D) game. LÖVE runs on
**LuaJIT** (Lua 5.1 semantics plus a few 5.2 extras like `goto`). Grow this section with
real lessons as the project matures — keep entries concrete ("this caused a bug"), not
generic style advice.

### Running the game

Put a real `love` executable on your `PATH`, or set the `LOVE_BIN` environment variable to
its full path — on macOS this is typically `/Applications/love.app/Contents/MacOS/love`.
Run the game from the project root (the directory holding `main.lua` / `conf.lua`):

```sh
love .
```

### Lua landmines (the ones that actually bite)

- **1-based indexing.** Arrays start at `1`. The `#t` length operator is **undefined** for
  a table with `nil` holes — don't `t[i] = nil` mid-array and then trust `#t`. To remove
  from an array either iterate **backwards** (`for i = #t, 1, -1`) or swap-with-last + pop.
- **Only `nil` and `false` are falsy.** `0` and `""` are truthy.
- **Globals by default.** A missing `local` silently creates a global — the single biggest
  Lua footgun. Declare `local` everywhere and run `luacheck` to catch accidental globals.
- **`:` vs `.` on methods.** `obj:method()` passes `self`; `obj.method()` does not. Pick one
  OOP library (e.g. `middleclass` / `classic`) rather than hand-rolling per file.
- **Lua patterns are not regex.** `string.match`/`gmatch` use Lua patterns (`%a`, `%d`).
- **No `continue`.** Use `goto continue` (LuaJIT supports it) or restructure with `if`.

### Love2D essentials

- **Frame-independence: multiply by `dt`.** Do `x = x + speed * dt` in `love.update(dt)`,
  never raw per-frame increments. Clamp a huge `dt` (after a hitch) so objects don't tunnel.
- **Load assets once, in `love.load`.** `love.graphics.newImage/newFont` and
  `love.audio.newSource` are expensive — never call them in `update`/`draw`. Cache them.
- **Colors are 0–1 floats** in LÖVE 11.x (`setColor(1, 1, 1)` is white), not 0–255. Most
  older tutorials use the 0–255 range — adjust.
- **`love.graphics` is a state machine.** `setColor`/`setFont`/transforms persist across
  draws. Wrap transforms in `love.graphics.push()`/`pop()` and reset color, or everything
  downstream inherits the last state.
- **Avoid per-frame allocations.** Creating tables/strings every frame (e.g.
  `string.format` in a hot loop) causes GC hitches — reuse buffers.
- **Save data through `love.filesystem`** (sandboxed to the identity dir set in
  `conf.lua`), not raw `io.*`. Audio: `"static"` source for short SFX, `"stream"` for music.

### Testing

Use [`busted`](https://lunarmodules.github.io/busted/) for unit tests and `luacheck` for
linting (both via `luarocks`). Logic that does not touch the `love.*` API tests directly
under plain Lua; for `love`-dependent code, mock the `love` table or use LÖVE's own test
harness. Run the suite with the `/run-tests` command, which invokes `scripts/run_tests.sh`
(ships with this template; resolves `busted` from `BUSTED_BIN` then `PATH`, and propagates
its exit code). A failing test is a blocker — do not open a PR with known failures.

### Useful references

- **LÖVE wiki** — <https://love2d.org/wiki> — canonical API reference, with per-function
  version notes.
- **"Programming in Lua" (PIL)** — <https://www.lua.org/pil/> — the definitive language book.
- **Sheepolution "How to LÖVE"** — <https://sheepolution.com/learn/book> — the best-regarded
  LÖVE tutorial.
- **`awesome-love2d`** — curated list of battle-tested libraries (`bump.lua` for AABB
  collision, HUMP for vector/timer/camera/gamestate, `anim8` for sprite animation, etc.).
