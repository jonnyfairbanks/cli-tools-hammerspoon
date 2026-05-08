// Finicky config — routes URLs to specific Chrome profiles.
//
// Set Finicky as your default browser, symlink this file to ~/.finicky.js,
// then edit the profile names + host arrays below.
//
// Find your Chrome profile *names* (not directory paths) like this:
//   python3 -c 'import json; d=json.load(open("/Users/$USER/Library/Application Support/Google/Chrome/Local State".replace("$USER","")));
//                [print(k, "->", v.get("user_name"), "|", v.get("name")) for k,v in d["profile"]["info_cache"].items()]'
//
// or just open Chrome → click your avatar → each profile's display name is
// what you want here. Pass the *display name*, not "Profile 1" / "Default".

const chrome = (profile) => ({ name: "Google Chrome", profile });

// ── EDIT ME ────────────────────────────────────────────────────────────────
// Replace these with your own Chrome profile display names.
const PROFILE_PERSONAL = "Personal";
const PROFILE_WORK     = "Work";
const PROFILE_OTHER    = "Other";

// Hosts that should always go to Personal even if a later rule would match.
const HOME_HOSTS = [
  "amazon.com",
];

// Hosts routed to your work profile.
const WORK_HOSTS = [
  "clockify.me",
  "linear.app",
  "notion.so",
  // add your work tools here
];

// Hosts routed to a third profile (delete this whole block if you only have two).
const OTHER_HOSTS = [
  // e.g. "side-project.com",
];
// ───────────────────────────────────────────────────────────────────────────

// Build a host matcher that covers exact host + all subdomains.
// Finicky v4 string patterns match the full URL, so include a path wildcard.
const hostPatterns = (hosts) =>
  hosts.flatMap((h) => [`${h}/*`, `*.${h}/*`]);

export default {
  defaultBrowser: chrome(PROFILE_PERSONAL),
  handlers: [
    { match: hostPatterns(HOME_HOSTS),  browser: chrome(PROFILE_PERSONAL) },
    { match: hostPatterns(WORK_HOSTS),  browser: chrome(PROFILE_WORK) },
    { match: hostPatterns(OTHER_HOSTS), browser: chrome(PROFILE_OTHER) },

    // Example: route a localhost dev server to a specific profile.
    // {
    //   match: ({ url }) => url.host === "localhost" && Number(url.port) === 3000,
    //   browser: chrome(PROFILE_WORK),
    // },

    // Example: Google Docs/Drive/Mail/Calendar — disambiguate by /u/N/.
    // /u/0 = first signed-in account, /u/1 = second, etc.
    // {
    //   match: ({ url }) =>
    //     /(^|\.)google\.com$/.test(url.host) && /\/u\/1\//.test(url.pathname),
    //   browser: chrome(PROFILE_WORK),
    // },

    // Example: Google Meet — disambiguate by ?authuser=<email>.
    // {
    //   match: ({ url }) =>
    //     url.host === "meet.google.com" && /[?&]authuser=you(%40|@)work\.com/.test(url.search || ""),
    //   browser: chrome(PROFILE_WORK),
    // },

    // Example: route a specific GitHub org to your work profile.
    // {
    //   match: ({ url }) =>
    //     url.host === "github.com" && /^\/YourOrg(\/|$)/i.test(url.pathname),
    //   browser: chrome(PROFILE_WORK),
    // },
  ],
};
