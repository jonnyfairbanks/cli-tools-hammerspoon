# CLAUDE.md

Guidance for Claude Code working in this directory.

## Overview

`clockify` is a time-tracking CLI (Ruby, stdlib only) with two interchangeable
backends:

- **ApiBackend** — talks to the Clockify REST API. Used when `CLOCKIFY_API_KEY`
  is set, or when `CLOCKIFY_BACKEND=api` is forced.
- **LocalBackend** — append-only JSONL log at
  `~/.local/share/clockify/entries.jsonl`. Used when there's no API key, or
  when `CLOCKIFY_BACKEND=local` is forced.

Both backends return entries in the Clockify API shape (`timeInterval` with
`start`/`end`/`duration`, `description`, `projectId`, plus a decorated
`project` name). The `cmd_*` methods, the status cache shape, and the
`log --json` output are all backend-agnostic — `log-work` and the
Hammerspoon widget don't know or care which backend is in use.

To add a new backend, subclass `Backend` and implement four methods:
`find_running_entry`, `start_entry(project, desc)`, `stop_entry(running)`,
`entries_in_range(project, t1, t2)`. See `LocalBackend` for the simplest
reference impl.

## Subcommands

- `clockify` (no args) / `clockify --help` — print top-level usage (including which backend is active) and exit 0.
- `clockify log [-m MM] [-y YYYY] [-d DD] [-p PROJECT] [--json]` — report hours per day for a month (or single day) on the configured project. `--json` emits machine-readable output.
- `clockify start [-p PROJECT] [-d DESCRIPTION]` — clock in. Errors out (exit 1) if an entry is already running.
- `clockify stop` — stop the currently running entry. Warns (exit 1) if none.
- `clockify punch [-p PROJECT] [-d DESCRIPTION] [-y]` — smart toggle. Looks up the running entry and prompts `[Y/n]` to stop, or prompts to start one if idle. Empty input or `y`/`yes` confirms; anything else cancels with exit 0. `-y`/`--yes` skips the prompt and toggles immediately — used by the Hammerspoon menu and any other non-interactive caller (`hs.task` has no stdin).
- `clockify status [--json] [--refresh | --no-refresh]` — print current state. Reads/writes a cache at `~/.cache/clockify/status.json` and auto-refreshes from the API when older than `CACHE_TTL` seconds (default 60). Designed to be polled by a menu bar widget. `start`/`stop`/`punch` write the cache on success so the bar updates immediately after CLI toggles.
- `clockify day [--json]` / `clockify week [--json]` — pretty-printed today / current-week readouts off the same cache.

## Hammerspoon menu bar widget

Lives at `../hammerspoon/tracker/init.lua`. Polls `clockify status --json` every 60s, shows today's total in the menu bar, and exposes Punch / Refresh / Open / Generate timesheet actions.

Two parsing gotchas baked into the lua, worth preserving in any new module:

- `hs.execute(cmd, true)` sources interactive `~/.zshrc`, which can prepend banners or iTerm shell-integration escapes to stdout — slice from the first `{` to the last `}` to recover the JSON.
- Lua's `os.time`/`os.date` mishandle DST when round-tripping UTC, so `parseISO8601` shells out to BSD `date -j -u -f` instead.

User-triggered actions in the menu (Punch, Refresh now) run async via `hs.task.new("/bin/zsh", cb, { "-l", "-i", "-c", cmd })` and show a Braille spinner in the menu title until the callback fires. `hs.execute` is sync and blocks the event loop, so the spinner wouldn't even paint without going async. Punch uses `clockify punch -y` because `hs.task` has no stdin to answer the `[Y/n]` prompt.

## Downstream consumer

`log-work` (`../log-work/log-work`) shells out to `clockify log --json -m MM -y YYYY` to bake daily hour totals into its HTML report. **Keep `--json` output stable**: a single-line object keyed by ISO date (`{"2026-04-15": 5.75}`), days with `hours > 0` only. Breaking that contract silently breaks `log-work`.

## Config

- `CLOCKIFY_API_KEY` (optional) — set to use the API backend. Generate at https://app.clockify.me/user/settings → API. Unset = local-only mode.
- `CLOCKIFY_BACKEND` (optional) — force `local` or `api` regardless of the key being set. Useful for peers who have Clockify at work but want this for personal time.
- `CLOCKIFY_PROJECT` (optional) — default project name. Falls back to the `PROJECT_NAME` constant near the top of `clockify`.
- `CLOCKIFY_WEEKLY_LIMIT` / `CLOCKIFY_HOURLY_RATE` (optional) — used by the `week` / paycheck readouts.
- Workspace ID is auto-discovered from the API key's user (`GET /user` returns `defaultWorkspace`) when using the API backend.

## Conventions

- **Ruby stdlib only.** No Gemfile, no bundler. `net/http`, `json`, `date`, `time`, `optparse`, `uri`. Don't add gems — the value of this tool is that it just runs against any system Ruby.
- **Single file.** Keep all logic in `clockify`. If it grows enough to warrant splitting, that's a signal to switch to a real gem layout.
- **Each subcommand owns its own `OptionParser`.** Top-level routing happens in `main` based on `ARGV.first`. Each `cmd_*` method parses its own flags so `-d` can mean different things between subcommands.
- **Time handling:** the API takes UTC ISO 8601 with `Z` suffix — always go through `iso8601_z(time)`. For grouping into local-day buckets, use `Time.parse(...).getlocal.to_date` so entries near midnight don't drift into the wrong day.
- **Errors:** raise `ClockifyError` for API failures; `main` rescues and exits non-zero with a stderr message. Network errors caught separately. Exit codes: `0` ok, `1` runtime/API error, `2` config/usage error.

## Clockify API endpoints used

- `GET  /user` — current user + default workspace
- `GET  /workspaces/{ws}/projects?name=NAME` — find project (Clockify does a case-insensitive substring match server-side; we filter exact case-insensitively in Ruby)
- `GET  /workspaces/{ws}/user/{uid}/time-entries?in-progress=true` — find running entry
- `GET  /workspaces/{ws}/user/{uid}/time-entries?project=...&start=...&end=...&page=N` — list entries (paginated, page-size 200; we buffer the date range by ±1 day to cover TZ-shifted entries near month boundaries)
- `POST /workspaces/{ws}/time-entries` — create entry (clock in). Omit `end` to leave it running.
- `PATCH /workspaces/{ws}/user/{uid}/time-entries` — stop the running entry. Body: `{"end": "<UTC ISO>"}`.

Documented rate limit is ~50 req/sec per workspace. The status cache + 60s poll keeps usage at ~60 req/hour.
