-- Time-tracker menu bar widget.
-- Single dropdown that combines Clockify status/actions and the Log Work
-- timesheet runner. The general apps launcher lives in its own dropdown — see
-- `hammerspoon/apps.lua`.
--
-- Title:
--   * "<prefix> ● 2.5h"      (red)   when clocked out — today's total
--   * "<prefix> ▶ 15m/2.5h"  (green) when clocked in — session/today's total
--
-- Polls `clockify status --json` every 60s. The CLI's own 60s cache TTL gates
-- the actual API call, so most polls just read its local cache (fast, free).

local M = {}

-- ── EDIT ME ────────────────────────────────────────────────────────────────
-- Short prefix shown in the menubar before the status icon. Two characters
-- works well (e.g. company initials). Set to "" to drop it entirely.
local TITLE_PREFIX = "TT"
-- ───────────────────────────────────────────────────────────────────────────

local green = { hex = "#22c55e" }
local red = { hex = "#ef4444" }
local CLI = os.getenv("HOME") .. "/.local/bin/clockify"
local POLL_SECONDS = 60
local CLOCKIFY_URL = "https://app.clockify.me/tracker"

local PREFIX_TEXT = TITLE_PREFIX == "" and "" or (TITLE_PREFIX .. " ")

-- Idle title: "<prefix> ●" (with optional today-total suffix) with a small red dot.
local function idleTitle(dayHours)
  local t = hs.styledtext.new(PREFIX_TEXT) ..
    hs.styledtext.new("●", { font = { size = 14 }, color = red })
  if dayHours and dayHours > 0 then
    t = t .. hs.styledtext.new(string.format(" %.1fh", dayHours))
  end
  return t
end

M.menu = hs.menubar.new(true, "tracker")

-- Spinner shown during user-triggered shell-outs (Punch, Refresh, Log Work).
-- hs.execute blocks the event loop, so those run via hs.task.new (async)
-- and cycle a Braille spinner in the title until the callback fires.
local SPINNER_FRAMES = { "⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏" }
local spinnerTimer

local function startSpinner()
  local i = 1
  M.menu:setTitle(SPINNER_FRAMES[i])
  spinnerTimer = hs.timer.doEvery(0.1, function()
    i = i % #SPINNER_FRAMES + 1
    M.menu:setTitle(SPINNER_FRAMES[i])
  end)
end

local function stopSpinner()
  if spinnerTimer then spinnerTimer:stop(); spinnerTimer = nil end
end

-- Mirror `hs.execute(cmd, true)` (login+interactive zsh, sources ~/.zshrc for
-- CLOCKIFY_API_KEY) but async via hs.task.
local function runAsync(cmd, onDone)
  local task = hs.task.new("/bin/zsh", function(exitCode, stdOut, stdErr)
    if onDone then onDone(exitCode == 0, stdOut, stdErr) end
  end, { "-l", "-i", "-c", cmd })
  task:start()
end

local function humanize(seconds)
  local h = math.floor(seconds / 3600)
  local m = math.floor((seconds % 3600) / 60)
  if h > 0 then return string.format("%dh %dm", h, m) end
  return string.format("%dm", m)
end

local function parseISO8601(s)
  -- "2026-04-29T16:44:38Z" → epoch. Lua's os.time/os.date dance gets DST
  -- wrong, so just shell out to BSD `date` which handles it correctly.
  local out, ok = hs.execute("/bin/date -j -u -f '%Y-%m-%dT%H:%M:%SZ' '" .. s .. "' +%s 2>/dev/null")
  if not ok or not out then return nil end
  return tonumber(out:match("%d+"))
end

local function extractJSON(s)
  -- hs.execute with with_user_env=true sources interactive shell rc files,
  -- which can prepend banners, NVM init, or iTerm shell-integration escape
  -- sequences (no newline) to stdout. Slice from the first `{` to the last `}`.
  local first = s:find("{", 1, true)
  local last = s:find("}[^}]*$")
  if first and last then return s:sub(first, last) end
  return nil
end

local function refresh()
  if spinnerTimer then return end  -- a user action is mid-flight; don't clobber the spinner
  local out, ok = hs.execute(CLI .. " status --json", true)
  if not ok or not out then
    M.menu:setTitle(PREFIX_TEXT .. "⚠")
    return
  end
  local json = extractJSON(out)
  local data = json and hs.json.decode(json) or nil
  if not data then
    print("[tracker] no JSON in clockify status output:\n" .. tostring(out))
    M.menu:setTitle(PREFIX_TEXT .. "⚠")
    return
  end

  local dayHours = data.day and data.day.hours or 0
  if data.running then
    local elapsed = os.time() - (parseISO8601(data.started_at) or os.time())
    if elapsed < 0 then elapsed = 0 end
    -- day.hours was computed at fetched_at and already includes the running
    -- session up to that point. Add the time since to keep the total live.
    local since = data.fetched_at and (os.time() - (parseISO8601(data.fetched_at) or os.time())) or 0
    if since < 0 then since = 0 end
    local liveDay = dayHours + since / 3600
    M.menu:setTitle(hs.styledtext.new(PREFIX_TEXT) ..
      hs.styledtext.new(string.format("▶ %s/%.1fh", humanize(elapsed), liveDay), { color = green }))
  else
    M.menu:setTitle(idleTitle(dayHours))
  end
end

local function punch()
  if spinnerTimer then return end
  startSpinner()
  runAsync(CLI .. " punch -y", function()
    stopSpinner()
    refresh()
  end)
end

M.punch = punch

-- Strip the leading "YYYY-" so menu labels stay short (e.g. "Apr 1–Apr 15").
local function shortDate(iso)
  if not iso then return "?" end
  local mo, dd = iso:match("^%d%d%d%d%-(%d%d)%-(%d%d)$")
  if not mo then return iso end
  local months = {"Jan","Feb","Mar","Apr","May","Jun","Jul","Aug","Sep","Oct","Nov","Dec"}
  return months[tonumber(mo)] .. " " .. tonumber(dd)
end

-- Read the status cache directly — no shell-out, no API call. The status
-- poller refreshes this every POLL_SECONDS, so the menu is always near-fresh.
local function readSummary()
  local path = os.getenv("HOME") .. "/.cache/clockify/status.json"
  local f = io.open(path, "r")
  if not f then return nil end
  local body = f:read("*a")
  f:close()
  return hs.json.decode(body)
end

M.menu:setMenu(function()
  local d = readSummary() or {}
  local items = {}

  -- Clockify section
  table.insert(items, { title = hs.styledtext.new("Clockify", { color = green }), disabled = true })
  table.insert(items, { title = "Punch (start/stop)", fn = punch })
  table.insert(items, { title = "Refresh now", fn = function()
    if spinnerTimer then return end
    startSpinner()
    runAsync(CLI .. " status --refresh", function()
      stopSpinner()
      refresh()
    end)
  end })
  table.insert(items, { title = "Open Clockify in Chrome", fn = function()
    -- Default browser handles routing (e.g. via Finicky to a specific profile).
    hs.execute("/usr/bin/open '" .. CLOCKIFY_URL .. "'")
  end })

  if d.day then
    local hrs = d.day.hours or 0
    local label = string.format("Today: %.2fh", hrs)
    local color = nil
    if hrs > 8 then
      color = red -- red: over 8h
    elseif hrs >= 6 then
      color = green -- green: 6h+
    end
    if color then
      table.insert(items, { title = hs.styledtext.new(label, { color = color }), disabled = true })
    else
      table.insert(items, { title = label, disabled = true })
    end
  else
    table.insert(items, { title = "Today: …", disabled = true })
  end

  if d.week then
    table.insert(items, { title = string.format("This week: %.2fh", d.week.hours), disabled = true })
    table.insert(items, { title = string.format("  %.2fh left",
      d.week.remaining), disabled = true })
  else
    table.insert(items, { title = "This week: …", disabled = true })
  end

  if d.paycheck then
    local h1, h2 = d.paycheck.first_half, d.paycheck.second_half
    table.insert(items, { title = string.format("%s–%s: $%.2f",
      shortDate(h1.start), shortDate(h1["end"]), h1.dollars), disabled = true })
    table.insert(items, { title = string.format("%s–%s: $%.2f",
      shortDate(h2.start), shortDate(h2["end"]), h2.dollars), disabled = true })
  end

  -- Log Work section
  table.insert(items, { title = "-" })
  table.insert(items, { title = hs.styledtext.new("Log Work", { color = green }), disabled = true })
  table.insert(items, {
    title = "Generate timesheet",
    fn = function()
      if spinnerTimer then return end
      startSpinner()
      require("tracker.logwork").run(function()
        stopSpinner()
        refresh()
      end)
    end,
  })

  return items
end)

M.timer = hs.timer.doEvery(POLL_SECONDS, refresh)
refresh()

return M
