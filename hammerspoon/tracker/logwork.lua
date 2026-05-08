-- log-work runner for the tracker menu.
-- cd's into the configured repo and runs the log-work CLI with --open so the
-- generated HTML report pops up in the default browser. Runs async via
-- hs.task.new so the calling menu can show a spinner while it works.
--
-- Set $LOG_WORK_REPO in your shell rc to point at the git repo to summarise.
-- If unset, the runner shows a notification telling you to set it instead of
-- failing silently.

local REPO = os.getenv("LOG_WORK_REPO")
local CLI  = os.getenv("HOME") .. "/.local/bin/log-work"

local M = {}

-- Treat the repo as configured only if it's set AND points at a real
-- directory. Catches both unset env and the placeholder default that some
-- people forget to swap out.
local function repoOk()
  if not REPO or REPO == "" then return false end
  return hs.fs.attributes(REPO) ~= nil
end

-- onComplete(ok) is invoked when the report finishes (success or failure).
function M.run(onComplete)
  if not repoOk() then
    local msg = REPO and ("LOG_WORK_REPO points at " .. REPO .. " — not a directory")
                       or "set $LOG_WORK_REPO in ~/.zshrc and reload Hammerspoon"
    print("[log-work] skipping: " .. msg)
    hs.notify.new({ title = "log-work — not configured", informativeText = msg }):send()
    if onComplete then onComplete(false) end
    return
  end

  -- Hammerspoon's shell doesn't inherit LANG/LC_ALL, and Ruby chokes on
  -- non-ASCII git output without them — set explicitly here.
  local cmd = string.format("export LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 && cd %q && %q --open 2>&1", REPO, CLI)
  print("[log-work] running: " .. cmd)
  local task = hs.task.new("/bin/zsh", function(exitCode, stdOut, stdErr)
    print("[log-work] exit=" .. tostring(exitCode) .. "\n" .. tostring(stdOut) .. tostring(stdErr or ""))
    if exitCode == 0 then
      hs.notify.new({ title = "log-work", informativeText = "Report opened" }):send()
    else
      hs.notify.new({ title = "log-work", informativeText = "Failed — see Hammerspoon console" }):send()
    end
    if onComplete then onComplete(exitCode == 0) end
  end, { "-l", "-i", "-c", cmd })
  task:start()
end

return M
