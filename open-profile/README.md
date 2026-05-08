# open-profile

`open` — drop-in wrapper around macOS `open(1)` that adds a `-p PROFILE` flag
for forcing a specific Chrome profile. Used by `log-work --open` to launch
the generated HTML timesheet in a specific profile (Finicky only routes
http/https URLs, so it can't help with local files).

For routing real URLs to specific profiles, use [Finicky](../finicky/).

## Install

```bash
chmod +x ~/dev/cli/open-profile/open
ln -sf ~/dev/cli/open-profile/open ~/.local/bin/open
```

(Adjust the source path. With this symlink, calls to `open` from your shell
go through this wrapper; without `-p` it passes through to `/usr/bin/open`.)

If you'd rather not shadow the system `open`, symlink it under a different
name (e.g. `open-profile`) and call it explicitly.

## Usage

```bash
open https://example.com                      # passthrough to /usr/bin/open
open -p you@work.com https://...              # force profile by email
open -p "Profile 1" https://...               # by directory name
open -p "Work" https://...                    # by display name
open -p you@work.com /tmp/foo.html            # local file, in profile
```

`-p` matches (case-insensitively) against the profile directory, signed-in
account email, or display name; the resolver reads
`~/Library/Application Support/Google/Chrome/Local State` so it survives
Chrome reshuffling profile numbers.

## Listing profiles

```bash
python3 -c 'import json,os; d=json.load(open(os.path.expanduser("~/Library/Application Support/Google/Chrome/Local State"))); [print(k,"->",v.get("user_name"),"|",v.get("name")) for k,v in d["profile"]["info_cache"].items()]'
```

## Exit codes

- `0` — passthrough succeeded, or Chrome was launched
- `1` — Local State unreadable, or no profile matched
- `2` — `-p` given without a value
