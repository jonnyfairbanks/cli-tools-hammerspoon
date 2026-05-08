-- log-work runner for the tracker menu.
-- cd's into the configured repo and runs the log-work CLI with --open so the
-- generated HTML report pops up in the default browser. Runs async via
-- hs.task.new so the calling menu can show a spinner while it works.
--
-- ── EDIT ME ────────────────────────────────────────────────────────────────
-- Either set $LOG_WORK_REPO in your shell rc, or hard-code the repo path below.
local REPO = os.getenv("LOG_WORK_REPO") or (os.getenv("HOME") .. "/dev/your-repo")
local CLI  = os.getenv("HOME") .. "/.local/bin/log-work"
-- ───────────────────────────────────────────────────────────────────────────

local M = {}

-- onComplete(ok) is invoked when the report finishes (success or failure).
function M.run(onComplete)
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
