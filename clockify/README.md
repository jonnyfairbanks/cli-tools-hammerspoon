# clockify

CLI for the Clockify time-tracking REST API. Pure Ruby, stdlib only — no Gemfile, no bundler, no install step beyond a symlink.

## Install

```bash
chmod +x ~/dev/cli/clockify/clockify
ln -sf ~/dev/cli/clockify/clockify ~/.local/bin/clockify
```

(Adjust the source path if you cloned somewhere else. `~/.local/bin` should be on `$PATH`.)

Verify:

```bash
which clockify              # ~/.local/bin/clockify
ls -la $(which clockify)    # symlink → wherever you cloned it
```

Edits to the script are picked up immediately — the symlink resolves to the live file.

## Config

```bash
# Choose your backend:
export CLOCKIFY_API_KEY="..."           # set → use Clockify REST API (syncs with web/mobile)
                                        # unset → fall back to local-only mode
export CLOCKIFY_PROJECT="my-project"    # default project for log/start/punch (both backends)
```

Backends:

- **api** (default when `CLOCKIFY_API_KEY` is set) — talks to the Clockify
  REST API. Workspace ID is auto-discovered from the API key's owner. Generate
  a key at https://app.clockify.me/user/settings → **API**.
- **local** (default when `CLOCKIFY_API_KEY` is empty) — appends entries to
  `~/.local/share/clockify/entries.jsonl`. No network, no auth, no web UI.
  Same JSON output shape, so `log-work` and the Hammerspoon widget work
  identically.

Force a backend explicitly:
```bash
export CLOCKIFY_BACKEND=local           # ignore any API key
export CLOCKIFY_BACKEND=api             # error out if no key, instead of falling back
```

Optional knobs (or edit the constants at the top of `clockify`):

```bash
export CLOCKIFY_WEEKLY_LIMIT="40"       # hours/week — used by the `week` readout
export CLOCKIFY_HOURLY_RATE="0"         # USD/hour — used by the paycheck readout (0 = no $ figures)
```

## Usage

Run `clockify` with no args (or `clockify --help`) for the top-level command list.

### Report hours

```bash
clockify log                        # current month, all days
clockify log -m 04                  # April current year
clockify log -m 04 -y 2026          # April 2026
clockify log -m 04 -y 2026 -d 03    # April 3, 2026 only
clockify log -p other-project       # different project
clockify log --json                 # machine-readable output
```

`--json` emits a single-line object keyed by ISO date, days with `hours > 0` only:
```json
{"2026-04-15":5.75,"2026-04-22":8.50}
```

### Clock in / out

```bash
clockify start                              # default project, empty description
clockify start -d "ticket ABC-1500"         # custom description
clockify start -p "other-project" -d "..."  # different project

clockify stop                               # stop currently running entry
```

`start` errors out (exit 1) if an entry is already running. `stop` warns (exit 1) if nothing is running.

### Punch (smart toggle)

```bash
clockify punch                          # prompts to start or stop based on current state
clockify punch -d "fixing nav bug"      # description used only if it ends up starting
clockify punch -y                       # auto-confirm — toggle without prompting
```

`-y` is the flag the Hammerspoon menu bar uses since `hs.task` has no stdin to answer the prompt.

### Status (cached, for menu bar polling)

```bash
clockify status                  # human: "▶ tickets — 8m" or "■ idle"
clockify status --json           # machine: single-line JSON object
clockify status --refresh        # force API call, ignore cache TTL
clockify status --no-refresh     # cache-only, never hit the API
```

Reads/writes `~/.cache/clockify/status.json`. The cache TTL is 60s — `status` auto-refreshes when stale and serves the cache otherwise. `start`/`stop`/`punch` write the cache on success so menu bar widgets update instantly after CLI toggles.

JSON shape (running):
```json
{"running":true,"description":"tickets","project":"my-project","started_at":"2026-04-29T16:52:13Z","fetched_at":"2026-04-29T16:52:19Z"}
```

Idle:
```json
{"running":false,"fetched_at":"2026-04-29T16:55:00Z"}
```

## Local mode notes

- **Storage:** `~/.local/share/clockify/entries.jsonl`. One line per entry, in the
  same shape Clockify's API returns. Human-readable — `vim` it to edit past
  entries.
- **No web UI.** `clockify open` prints the store path instead of launching the
  browser.
- **No mobile app, no cross-device sync.** Each machine has its own log.
- **Project list comes from the JSONL itself.** First `start` for a new project
  just works — no "project doesn't exist" error.

## Editing past entries (local mode)

Forgot to clock out? Wrong description? Just edit the JSONL:

```bash
vim ~/.local/share/clockify/entries.jsonl
```

Each line is independent. Fix the `start` / `end` / `description` / `project`
field and save. Re-run `clockify status --refresh` to refresh the cache.

## Hammerspoon menu bar widget

The companion widget lives at `../hammerspoon/tracker/`. It polls `clockify status --json` every 60s, shows today's total in the menu bar, and exposes Punch / Refresh / Open / Generate timesheet actions in the dropdown. See `../hammerspoon/README.md` for wiring.

## Conventions for editing

- **Stdlib only.** `net/http`, `json`, `date`, `time`, `optparse`, `uri`. No gems.
- **Single file.** If it grows enough to need splitting, switch to a real gem layout — don't bolt on a `lib/` directory.
- **Each subcommand owns its own `OptionParser`** so flags can mean different things per command (e.g. `-d` is `--day` for `log`, `--description` for `start`).
- **Time:** API takes UTC ISO 8601 with `Z` suffix — always go through `iso8601_z(time)`. Group entries into local-day buckets via `Time.parse(...).getlocal.to_date` so midnight-adjacent entries don't drift.
- **Exit codes:** `0` ok, `1` runtime/API error, `2` config/usage error.
