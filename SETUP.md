# Setup

A walkthrough for getting these tools running on a fresh macOS machine. If
you're using Claude Code, point it at this file and `CLAUDE.md` and ask it
to set things up — the structure is designed for that.

The steps assume you cloned this repo to `~/dev/cli`. Adjust paths if not.

## 0. Prerequisites

- macOS, with system Ruby (`ruby -v` ≥ 2.7) and `git` on `$PATH`.
- `~/.local/bin` on `$PATH`. If not, add this to `~/.zshrc`:
  ```sh
  export PATH="$HOME/.local/bin:$PATH"
  ```
- [Hammerspoon](https://www.hammerspoon.org/) (only if you want the menu
  bar widgets): `brew install --cask hammerspoon` and grant Accessibility
  permissions on first launch.
- [Finicky](https://github.com/johnste/finicky) (only if you want
  per-profile URL routing): `brew install --cask finicky`.

## 1. clockify CLI

```bash
mkdir -p ~/.local/bin
chmod +x ~/dev/cli/clockify/clockify
ln -sf ~/dev/cli/clockify/clockify ~/.local/bin/clockify
```

You have two options for the backend:

**Option A — Clockify API** (syncs with the Clockify web/mobile apps; needed
if your company invoices off Clockify):

```sh
# in ~/.zshrc:
export CLOCKIFY_API_KEY="..."          # generate at https://app.clockify.me/user/settings → API
export CLOCKIFY_PROJECT="my-project"   # default project; -p overrides per call
```

**Option B — local only** (zero setup, no auth, entries stored at
`~/.local/share/clockify/entries.jsonl`):

```sh
# in ~/.zshrc:
export CLOCKIFY_PROJECT="my-project"   # whatever you want to call your default bucket
# don't set CLOCKIFY_API_KEY
```

Either way, `source ~/.zshrc` and verify:

```bash
clockify --help        # bottom line shows which backend is active
clockify status        # should print "■ idle"
```

## 2. log-work CLI

```bash
chmod +x ~/dev/cli/log-work/log-work
ln -sf ~/dev/cli/log-work/log-work ~/.local/bin/log-work
```

Add to `~/.zshrc`:

```sh
export LOG_WORK_AUTHOR="Your Name"     # required — must match your git author name
# Optional:
# export LOG_WORK_SHEET_URL="https://docs.google.com/spreadsheets/d/..."
# export LOG_WORK_HOURLY_RATE="0"        # set if you want $ figures in the paycheck readout
# export LOG_WORK_WEEKLY_CAP="40"
```

`source ~/.zshrc`, then from inside any git repo you commit to:

```bash
log-work             # writes /tmp/log-work-YYYY-MM.html
log-work --open      # also opens it in the default browser
```

## 3. open-profile (optional but used by `log-work --open`)

If you want `log-work --open` to land the HTML in a specific Chrome profile:

```bash
chmod +x ~/dev/cli/open-profile/open
ln -sf ~/dev/cli/open-profile/open ~/.local/bin/open
```

(Or symlink as `open-profile` if you'd rather not shadow the system
`open`.) Then add to `~/.zshrc`:

```sh
export LOG_WORK_CHROME_PROFILE="you@work.com"   # email/display name of the target profile
```

To list your profiles see [`open-profile/README.md`](./open-profile/README.md#listing-profiles).

## 4. Hammerspoon widgets

```bash
mkdir -p ~/.hammerspoon
ln -sf ~/dev/cli/hammerspoon/init.lua  ~/.hammerspoon/init.lua
ln -sf ~/dev/cli/hammerspoon/apps.lua  ~/.hammerspoon/apps.lua
ln -sf ~/dev/cli/hammerspoon/tracker   ~/.hammerspoon/tracker
```

Then:
- Edit `~/dev/cli/hammerspoon/apps.lua` — customise the `APPS` table.
- Edit `~/dev/cli/hammerspoon/tracker/init.lua` — set `TITLE_PREFIX` to
  whatever short label you want in the menubar.
- Add to `~/.zshrc` (or edit `tracker/logwork.lua` directly):
  ```sh
  export LOG_WORK_REPO="$HOME/dev/your-repo"
  ```

Reload Hammerspoon (menu icon → Reload Config). You should see the `▾`
dropdown and the tracker widget in the menubar.

Hotkeys (defined in `init.lua`):
- **⌘⌃E** — reload Hammerspoon
- **⌘⌃P** — punch in/out (`clockify punch -y`)

## 5. Finicky

```bash
ln -sf ~/dev/cli/finicky/finicky.js ~/.finicky.js
```

Then:
1. Open Finicky.app, set it as your default browser (it'll prompt).
2. Edit `~/dev/cli/finicky/finicky.js`:
   - Replace `PROFILE_PERSONAL` / `PROFILE_WORK` / `PROFILE_OTHER` with
     your actual Chrome profile display names (open Chrome → click your
     avatar; the names there are what you want).
   - Fill in `WORK_HOSTS` etc. with the domains you want routed to each
     profile.

No reload needed — edits apply on the next URL open.

## Smoke tests

```bash
# 1. Clockify auth works
clockify status --refresh

# 2. log-work runs end-to-end (run inside a git repo)
cd ~/dev/your-repo
log-work --json | head -20

# 3. Hammerspoon widgets appear (menubar should show `▾` and your tracker)

# 4. Finicky routes (open a URL from a known WORK_HOSTS domain — should land
#    in the work profile)
```

## Troubleshooting

- **API mode: "CLOCKIFY_API_KEY not set"** — you set it in `~/.zshrc` but
  Hammerspoon doesn't see it. The widget shells out via `zsh -l -i -c`,
  which sources `~/.zshrc`, so confirm the export is in there (not
  `~/.bash_profile` or similar) and that there are no syntax errors above
  it. If you'd rather not use the API at all, just unset the key —
  `clockify` will fall back to local mode automatically.
- **Tracker widget shows `⚠`** — `clockify status --json` is failing.
  Run it manually to see the error. Most often: API key missing or wrong
  `CLOCKIFY_PROJECT`.
- **`log-work` says "no commits found"** — `LOG_WORK_AUTHOR` doesn't match
  your git author name. Run `git log --pretty=format:'%an' | head` in the
  repo to see the exact string git records, and use that.
- **Finicky logs "Found profile using profile path"** — you passed a
  directory like `"Profile 1"` instead of a display name. Use the name
  from Chrome's avatar menu.
