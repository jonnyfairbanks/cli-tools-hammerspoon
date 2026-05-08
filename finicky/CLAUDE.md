# CLAUDE.md — finicky

[Finicky](https://github.com/johnste/finicky) v4 config. Set Finicky as your
default browser via the app's UI, then symlink this file:

```bash
ln -sf ~/dev/cli/finicky/finicky.js ~/.finicky.js
```

Edits apply on the next URL open — no reload.

## v4 gotchas

- **Match functions receive a context object, not the URL.** Signature is `match: ({ url, urlString, opener }) => …`. Writing `match: (url) => url.host === …` looks like it works but `url` is the whole context — `url.host` is `undefined` and the handler silently never matches. Always destructure `({ url })`.
- **`browser`/`profile` must be the Chrome profile *name*, not the directory path.** Passing `"Default"` or `"Profile 1"` works but logs a deprecation warning on every open: `Found profile using profile path … Please use the profile name instead`. Use the display name from Chrome's Local State (`~/Library/Application Support/Google/Chrome/Local State` → `profile.info_cache.<dir>.name`). The header comment in `finicky.js` shows how to derive it.
- **`url.host` does not include the port.** For `http://localhost:3000/...`, `url.host === "localhost"` and the port is in `url.port` (check via `Number(url.port) === 3000` — it may be a string). Putting `"localhost:3000"` in a host-array string pattern won't match.
- **String patterns match the full URL, so include a path wildcard.** The `hostPatterns` helper expands `"foo.com"` to `["foo.com/*", "*.foo.com/*"]` to cover exact host + subdomains.

## Editing

Add hosts to the appropriate `*_HOSTS` array. For path/port/query-discriminated routing, add an object to `handlers` — order matters, first match wins, so place specific rules before broader ones.
