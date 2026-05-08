# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working in
this repository.

## Repository purpose

A small monorepo of CLI tools and Hammerspoon menu-bar widgets. Each
subdirectory is a self-contained tool. There is no top-level build, test, or
package manager — every tool runs directly off system binaries (Ruby stdlib,
Lua via Hammerspoon).

If you're being asked to set this up on a new machine, walk the user through
[SETUP.md](./SETUP.md). Skip steps for tools they say they don't want — each
tool stands alone, except that `log-work` shells out to `clockify` for hours
and the `tracker` Hammerspoon widget polls `clockify status`.

## Subdirectories

- `clockify/` — Ruby CLI (`clockify`) for time tracking. Two interchangeable
  backends: the Clockify REST API (when `CLOCKIFY_API_KEY` is set) or a
  local-only JSONL log at `~/.local/share/clockify/entries.jsonl`. Same
  subcommands either way: `log`, `start`, `stop`, `punch`, `status`, `day`,
  `week`, `open`. Has its own detailed `CLAUDE.md` and `README.md`.
- `log-work/` — Ruby CLI (`log-work`) that builds a month-shaped HTML
  timesheet from `git log` + `clockify log --json`. `--json` mode for LLM
  consumption.
- `hammerspoon/tracker/` — Menu bar widget combining Clockify status/actions
  with a Log Work timesheet runner. `init.lua` is the main module (status
  poll + dropdown). `logwork.lua` shells out to the `log-work` CLI with
  `--open`. Chrome links use plain `/usr/bin/open <url>` and let the default
  browser (Finicky if installed) route them.
- `hammerspoon/apps.lua` — Standalone apps launcher menu bar widget (`▾`).
  Single dropdown that runs `hs.application.launchOrFocus(...)` on click.
- `hammerspoon/init.lua` — The Hammerspoon entrypoint. Loads both widgets
  and binds **⌘⌃E** to `hs.reload()` and **⌘⌃P** to `tracker.punch()`.
- `finicky/finicky.js` — Finicky v4 config. Routes URLs to specific Chrome
  profiles by host. Has its own `CLAUDE.md` covering v4 gotchas.
- `open-profile/` — `open` Ruby wrapper around macOS `open(1)` that adds
  `-p PROFILE` for forcing a Chrome profile. Used by `log-work --open` so
  the local HTML timesheet lands in the right profile (Finicky only handles
  http/https, not local files).

## Install / wiring pattern

There is no install script. Each tool is wired up by hand-rolled symlinks
(see [SETUP.md](./SETUP.md) for the exact commands):

- Executables → `ln -sf ~/dev/cli/<tool>/<tool> ~/.local/bin/<tool>`
  (`~/.local/bin` should be on `$PATH`).
- Hammerspoon → symlink each module/dir under `~/.hammerspoon/`, then
  `require("...")` from `~/.hammerspoon/init.lua`. The `tracker/` directory
  symlink lets `require("tracker")` and `require("tracker.logwork")` both
  resolve.
- Finicky → `ln -sf ~/dev/cli/finicky/finicky.js ~/.finicky.js`, then set
  Finicky as the default browser via the app's UI.

Symlinks resolve to the live file — edits are picked up immediately. No
rebuild step. Reload Hammerspoon (menu icon → Reload Config) to apply Lua
changes.

## Cross-tool contracts

- `log-work` shells out to `clockify log --json -m MM -y YYYY` to get daily
  hours. The JSON shape (single-line object keyed by ISO date, days with
  `hours > 0` only, e.g. `{"2026-04-15":5.75}`) is a stable contract —
  breaking it silently breaks `log-work`.
- `clockify status` writes a cache at `~/.cache/clockify/status.json`
  (TTL 60s). `start`/`stop`/`punch` also write the cache so the Hammerspoon
  menu bar widget reflects toggles instantly without waiting for the next
  poll.
- The `tracker` Hammerspoon widget reads the cache directly rather than
  shelling out, so menu opens are instant.

## Conventions

- **Stdlib only** for the Ruby CLIs. No Gemfile, no bundler — `net/http`,
  `json`, `date`, `time`, `optparse`, `uri`. Don't add gems; the value of
  these tools is that they run against any system Ruby.
- **Single file per CLI.** If one grows enough to need splitting, switch to
  a real gem layout — don't bolt on a `lib/` directory in place.
- **Each subcommand owns its own `OptionParser`** so flags can mean
  different things per command (e.g. in `clockify`, `-d` is `--day` for
  `log`, `--description` for `start`).
- **Time handling.** Clockify API takes UTC ISO 8601 with `Z` suffix —
  always go through the script's `iso8601_z(time)` helper. Group entries
  into local-day buckets via `Time.parse(...).getlocal.to_date` so
  midnight-adjacent entries don't drift.
- **Exit codes.** `0` ok, `1` runtime/API error, `2` config/usage error.
- **One Hammerspoon module per concern.** Tool-specific modules live with
  the tool; only generic ones go in `hammerspoon/`.

## Configuration surface

Most personalisation flows through env vars in `~/.zshrc`. Where there's an
"EDIT ME" block at the top of a file, that's deliberate — it's where the
most likely customisation lives. Search for `EDIT ME` to find them all.

Required for full functionality:
- `LOG_WORK_AUTHOR` — git author name (must match commits exactly)

Optional / defaulted:
- `CLOCKIFY_API_KEY` — set to use the Clockify API; unset to use local-only JSONL mode
- `CLOCKIFY_BACKEND` — force `local` or `api` regardless of key presence
- `CLOCKIFY_PROJECT`, `CLOCKIFY_WEEKLY_LIMIT`, `CLOCKIFY_HOURLY_RATE`
- `LOG_WORK_REPO`, `LOG_WORK_SHEET_URL`, `LOG_WORK_CHROME_PROFILE`,
  `LOG_WORK_HOURLY_RATE`, `LOG_WORK_WEEKLY_CAP`, `LOG_WORK_WEEKLY_WARN`,
  `LOG_WORK_DEFAULT_BULLET`, `LOG_WORK_DEFAULT_HOURS`,
  `LOG_WORK_OPEN_PROFILE`

## Hammerspoon gotchas

Pitfalls baked into existing Lua and worth preserving when adding new modules:

- `hs.execute(cmd, true)` sources interactive `~/.zshrc` (needed for env
  vars like `CLOCKIFY_API_KEY`), which can prepend banners or iTerm
  shell-integration escape sequences to stdout. When parsing JSON from a
  subprocess, slice from the first `{` to the last `}` rather than trusting
  the whole output.
- Lua's `os.time` / `os.date` mishandle DST when round-tripping UTC. For
  ISO 8601 → epoch, shell out to BSD `date -j -u -f` instead.
- Hammerspoon's shell doesn't inherit `LANG` / `LC_ALL`; Ruby chokes on
  non-ASCII git output without them. Set `LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8`
  inline when shelling out to Ruby tools that touch git (see
  `hammerspoon/tracker/logwork.lua`).
- `hs.execute` is **synchronous** and blocks the entire Hammerspoon event
  loop — fine for fast cache reads, but a network-bound shell-out will
  freeze the menu bar (and any spinner you set won't paint until the call
  returns). For user-triggered actions, run async via
  `hs.task.new("/bin/zsh", callback, { "-l", "-i", "-c", cmd })` (mirrors
  `hs.execute(cmd, true)`'s shell semantics) and cycle a Braille spinner in
  the menu title with `hs.timer.doEvery(0.1, ...)` until the callback fires.
  See `hammerspoon/tracker/init.lua`. CLI tools that prompt on stdin can't
  be invoked from `hs.task` (no terminal) — use a non-interactive flag like
  `clockify punch -y`.
