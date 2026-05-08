-- Hammerspoon entrypoint. Loads the menu bar widgets in this directory and
-- binds a couple of global hotkeys.
--
-- Wire-up:
--   ln -sf ~/dev/cli/hammerspoon/init.lua  ~/.hammerspoon/init.lua
--   ln -sf ~/dev/cli/hammerspoon/apps.lua  ~/.hammerspoon/apps.lua
--   ln -sf ~/dev/cli/hammerspoon/tracker   ~/.hammerspoon/tracker
-- (Adjust paths to wherever you cloned the repo.)

local tracker = require("tracker")
require("apps")

hs.hotkey.bind({"cmd", "ctrl"}, "E", function() hs.reload() end)
hs.hotkey.bind({"cmd", "ctrl"}, "P", function() tracker.punch() end)
