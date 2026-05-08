# hammerspoon

Two menu bar widgets backed by [Hammerspoon](https://www.hammerspoon.org/):

- **`apps.lua`** — `▾` dropdown launcher. Hand-curated list of apps; clicking
  an entry runs `hs.application.launchOrFocus(...)`. Pairs with Hidden Bar /
  Bartender so you can hide each app's own menu icon and still reach it
  quickly.
- **`tracker/`** — Clockify status + Log Work runner. Menubar shows today's
  hour total (and live elapsed when clocked in). Dropdown exposes Punch
  (start/stop), Refresh, Open Clockify in Chrome, and Generate timesheet (runs
  the `log-work` CLI).

The Hammerspoon entrypoint (`init.lua`) loads both widgets and binds two
hotkeys: **⌘⌃E** to reload Hammerspoon, **⌘⌃P** to punch in/out.

## Install

Hammerspoon looks for everything under `~/.hammerspoon/`. Symlink each piece in:

```bash
mkdir -p ~/.hammerspoon
ln -sf ~/dev/cli/hammerspoon/init.lua  ~/.hammerspoon/init.lua
ln -sf ~/dev/cli/hammerspoon/apps.lua  ~/.hammerspoon/apps.lua
ln -sf ~/dev/cli/hammerspoon/tracker   ~/.hammerspoon/tracker
```

(Adjust source paths for wherever you cloned this. The directory symlink at
`~/.hammerspoon/tracker` points at the whole `tracker/` folder so
`require("tracker")` and `require("tracker.logwork")` both resolve.)

Reload Hammerspoon (menu icon → Reload Config) to pick up changes.

## Configure

- **`apps.lua`** — edit the `APPS` table near the top to add/remove launcher
  entries. `app` is the value passed to `hs.application.launchOrFocus`.
- **`tracker/init.lua`** — edit `TITLE_PREFIX` (the short text shown in the
  menubar before the status icon). Two characters works well.
- **`tracker/logwork.lua`** — set `$LOG_WORK_REPO` in your shell rc, or edit
  the `REPO` constant at the top, to point at the git repo to summarise.

## Gotchas worth preserving

- `hs.execute(cmd, true)` sources interactive `~/.zshrc` (needed for env vars
  like `CLOCKIFY_API_KEY`), which can prepend banners or iTerm shell-integration
  escape sequences to stdout. When parsing JSON from a subprocess, slice from
  the first `{` to the last `}` rather than trusting the whole output.
- Lua's `os.time` / `os.date` mishandle DST when round-tripping UTC. For
  ISO 8601 → epoch, shell out to BSD `date -j -u -f` instead.
- Hammerspoon's shell doesn't inherit `LANG` / `LC_ALL`; Ruby chokes on
  non-ASCII git output without them. Set them inline when shelling out to
  Ruby tools that touch git (see `tracker/logwork.lua`).
- `hs.execute` is **synchronous** and blocks the entire Hammerspoon event loop
  — fine for fast cache reads, but a network-bound shell-out will freeze the
  menu bar (and any spinner you set won't paint until the call returns). For
  user-triggered actions, run async via
  `hs.task.new("/bin/zsh", callback, { "-l", "-i", "-c", cmd })` (mirrors
  `hs.execute(cmd, true)`'s shell semantics) and cycle a Braille spinner in
  the menu title with `hs.timer.doEvery(0.1, ...)` until the callback fires.
- CLI tools that prompt on stdin can't be invoked from `hs.task` (no terminal)
  — use a non-interactive flag like `clockify punch -y`.
