-- Apps launcher menu bar widget.
-- Single dropdown (▾) that runs `hs.application.launchOrFocus(...)` on click.
-- Pairs with Hidden Bar / Bartender — hide each app's own menu bar icon and
-- reach it from this dropdown when needed.
--
-- ── EDIT ME ────────────────────────────────────────────────────────────────
-- Customise the APPS list. `label` is what shows in the dropdown; `app` is
-- the value passed to hs.application.launchOrFocus — usually the application
-- name as it appears in /Applications (without the .app suffix). Some apps
-- launch under a slightly different name (e.g. "Alfred 5", "Passwords") —
-- check `ps -Ao comm` while the app is running if launchOrFocus can't find it.

local M = {}

local APPS = {
  { label = "Notion",          app = "Notion" },
  { label = "1Password",       app = "1Password" },
  { label = "Apple Passwords", app = "Passwords" },
  { label = "Alfred",          app = "Alfred 5" },
  { label = "Rectangle",       app = "Rectangle" },
  { label = "Claude",          app = "Claude" },
  { label = "Granola",         app = "Granola" },
  { label = "Loom",            app = "Loom" },
  { label = "Wispr Flow",      app = "Wispr Flow" },
  { label = "Hammerspoon",     app = "Hammerspoon" },
  { label = "Finicky",         app = "Finicky" },
}

M.menu = hs.menubar.new(true, "apps")
M.menu:setTitle(hs.styledtext.new("▾", { font = { size = 22 } }))

M.menu:setMenu(function()
  local items = {}
  for _, entry in ipairs(APPS) do
    table.insert(items, {
      title = entry.label,
      fn = function() hs.application.launchOrFocus(entry.app) end,
    })
  end
  table.insert(items, { title = "-" })
  table.insert(items, { title = "Reload Hammerspoon", fn = function() hs.reload() end })
  return items
end)

return M
