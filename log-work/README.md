# log-work

CLI that builds a month-shaped HTML timesheet from `git log` + Clockify hours.
Designed to be invoked by an LLM (or by a Hammerspoon menu) so the human (or
model) skips data-gathering plumbing and goes straight to the prose summary.

## Install

```bash
chmod +x ~/dev/cli/log-work/log-work
ln -sf ~/dev/cli/log-work/log-work ~/.local/bin/log-work
```

(Adjust the source path for wherever you cloned this. `~/.local/bin` should be on `$PATH`.)

Edits to the script are picked up immediately — the symlink resolves to the live file.

## Requirements

- Ruby 2.7+ (stdlib only — no Gemfile)
- `git` on `$PATH`, run from inside a git repo (or pass `--repo`)
- `clockify` CLI (sibling tool) for hours; gracefully degrades to "no hours" if unavailable

## Config

```bash
# optional — if unset, falls back to `git config user.name` in the target repo,
# and if that's also empty, runs with no author filter and prints a warning
export LOG_WORK_AUTHOR="Your Name"          # must match your git author name

# optional
export LOG_WORK_SHEET_URL="https://docs.google.com/spreadsheets/d/..."
export LOG_WORK_CHROME_PROFILE="you@work.com"   # used by --open via ../open-profile/open
export LOG_WORK_HOURLY_RATE="0"                # USD/hour, used by paycheck readout (0 = no $ figures)
export LOG_WORK_WEEKLY_CAP="30"                # used by weekly-status calendar
export LOG_WORK_WEEKLY_WARN="25"               # warn threshold below cap
export LOG_WORK_DEFAULT_BULLET="Filler"        # day-31 baseline if no real data
export LOG_WORK_DEFAULT_HOURS="0"              # 0 = no day-31 backfill
export LOG_WORK_OPEN_PROFILE="/path/to/open-profile/open"  # if not using sibling location
```

## Usage

```bash
log-work                                  # current month, current dir
log-work 2026-04                          # specific month (positional)
log-work --month 2026-03                  # specific month (flag)
log-work --repo ~/dev/some-repo
log-work --open                           # also open the HTML in browser
log-work --json                           # emit summary JSON on stdout
```

## Output

Always writes `/tmp/log-work-YYYY-MM.html` — a 31-row editable table with
per-row Copy buttons that paste cleanly into a Google Sheet or similar.

Without `--json`: human summary on stderr, file path on stdout.

```
Wrote /tmp/log-work-2026-04.html
  19 days with activity, 12 empty
  47 commits, 63.50 hours
  Clockify: ok
/tmp/log-work-2026-04.html
```

With `--json`: structured JSON on stdout containing per-day commits, hours, and
totals — designed for LLM consumption.

## How it works

1. `git fetch origin --quiet` (best-effort — non-fatal)
2. `git log --author --since --until --no-merges origin/main` for the month
3. `clockify log --json -m MM -y YYYY` for hours
4. Round each day's hours down to the nearest 0.1
5. Strip `(#1234)` PR-number suffixes; format bullets as `- [TICKET] subject`
6. Render 31 rows (one per day, including out-of-month placeholders)
7. Optionally fill day 31 with a baseline bullet/hours when there's no real data
   (controlled by `LOG_WORK_DEFAULT_BULLET` / `LOG_WORK_DEFAULT_HOURS`).
8. Render a weekly hours calendar (Sun–Sat) with status indicators against
   `LOG_WORK_WEEKLY_CAP`: ✅ under warn, ⚠️ between warn and cap, ❌ over.
9. Render an estimated-paycheck footer for the 1st–15th and 16th–end-of-month
   periods using the same rounded-down per-day hours that go into the CSV.

## Used by

- LLM workflows — shell out to `log-work --json` and write the prose summary.
- Hammerspoon menu bar — `../hammerspoon/tracker/logwork.lua` runs this with
  `--open` and shows a notification on completion. Set `LOG_WORK_REPO` (read by
  the lua) to the repo to summarise.
