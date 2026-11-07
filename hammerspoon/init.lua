-- hs.ipc lets the brew `hs` cli reach the running app, e.g. `hs -c "hs.reload()"`.
require("hs.ipc")

-- Cmd-G corrects the selected text in place, in any application, with
-- ~/.local/bin/spellcheck (Haiku through the Messages API).

local spellcheck = os.getenv("HOME") .. "/.local/bin/spellcheck"
local timeout = 30

-- Deliberate: a terminal pastes into whatever runs in it, and the slack screen
-- has its own correction (Ctrl-G), so Cmd-G keeps its usual meaning there.
local passthrough = {
  ["com.github.wez.wezterm"] = true,
  ["com.mitchellh.ghostty"] = true,
  ["com.apple.Terminal"] = true,
}

local busy = false

local function finish(saved, alert)
  if alert then hs.alert.closeSpecific(alert) end
  -- Deliberate: the paste reads the clipboard asynchronously, so it is put
  -- back once the target had time to read it.
  hs.timer.doAfter(0.3, function() hs.pasteboard.writeAllData(saved) end)
  busy = false
end

local function correct()
  if busy then return end
  busy = true
  local app = hs.application.frontmostApplication()
  local window = hs.window.focusedWindow()
  local saved = hs.pasteboard.readAllData()
  local before = hs.pasteboard.changeCount()
  local deadline = hs.timer.secondsSinceEpoch() + 0.5

  hs.eventtap.keyStroke({ "cmd" }, "c", 0)
  hs.timer.waitUntil(function()
    return hs.pasteboard.changeCount() ~= before or hs.timer.secondsSinceEpoch() > deadline
  end, function()
    local text = hs.pasteboard.changeCount() ~= before and hs.pasteboard.getContents()
    if not text or text == "" then
      hs.alert.show("Nothing selected")
      return finish(saved)
    end

    local alert = hs.alert.show("Correcting…", "indefinite")
    local task
    local timer = hs.timer.doAfter(timeout, function() task:terminate() end)
    task = hs.task.new(spellcheck, function(code, out, err)
      timer:stop()
      local fixed = out:gsub("\n$", "")
      if code ~= 0 or fixed == "" then
        hs.alert.show("Correction failed: " .. (err ~= "" and err or "exit " .. code))
        return finish(saved, alert)
      end
      if fixed == text then
        hs.alert.show("Nothing to correct")
        return finish(saved, alert)
      end
      -- The focus moved while the model answered: pasting would land in
      -- another window, so the correction is left on the clipboard instead.
      if hs.application.frontmostApplication() ~= app or hs.window.focusedWindow() ~= window then
        hs.alert.closeSpecific(alert)
        hs.pasteboard.setContents(fixed)
        hs.alert.show("Focus moved: correction copied to the clipboard")
        busy = false
        return
      end
      hs.pasteboard.setContents(fixed)
      hs.eventtap.keyStroke({ "cmd" }, "v", 0)
      finish(saved, alert)
    end, { text })
    task:start()
  end, 0.02)
end

-- Deliberate: this takes Cmd-G (Find Next) from every other app; Enter in a find
-- field does the same. Bound on release, so G is up when Cmd-C is sent.
local hotkey = hs.hotkey.new({ "cmd" }, "g", nil, correct)

-- Vim-feel tab keys in the browsers: Cmd-J/K select the next/previous tab,
-- Cmd-X closes it. They become the browsers' own shortcuts, which Chrome and
-- Firefox handle before the page sees them, so they still work on a hung
-- page, on chrome:// or about: pages, and from the address bar.
local browsers = {
  ["com.google.Chrome"] = true,
  ["org.mozilla.firefox"] = true,
}

-- Deliberate: arrows rather than Cmd-Shift-], so the key exists on any layout.
local function stroke(mods, key)
  return function() hs.eventtap.keyStroke(mods, key, 0) end
end

local textRoles = { AXTextField = true, AXTextArea = true, AXSearchField = true, AXComboBox = true }
local closeTab, follow

-- Deliberate: the app watcher can miss an activation and leave these keys on
-- in another app (Cmd-K is Slack's switcher), so a press outside a browser
-- turns them off and hands the stroke back to the app.
local function browserOnly(mods, key, action)
  return function()
    local app = hs.application.frontmostApplication()
    local id = app and app:bundleID()
    if browsers[id] then return action() end
    hs.printf("browser keys were on in %s, turned off", id)
    follow(id)
    hs.eventtap.keyStroke(mods, key, 0)
  end
end

-- Deliberate: Cmd-X stays Cut while a text field has focus. The hotkey is
-- paused around the real Cmd-X so it does not catch its own keystroke.
local function closeTabOrCut()
  local focused = hs.axuielement.systemWideElement():attributeValue("AXFocusedUIElement")
  local role = focused and focused:attributeValue("AXRole")
  if role and textRoles[role] then
    closeTab:disable()
    hs.eventtap.keyStroke({ "cmd" }, "x", 0)
    closeTab:enable()
  else
    hs.eventtap.keyStroke({ "cmd" }, "w", 0)
  end
end
closeTab = hs.hotkey.new({ "cmd" }, "x", browserOnly({ "cmd" }, "x", closeTabOrCut))

local nextTab = browserOnly({ "cmd" }, "j", stroke({ "cmd", "alt" }, "right"))
local prevTab = browserOnly({ "cmd" }, "k", stroke({ "cmd", "alt" }, "left"))
local browserKeys = {
  hs.hotkey.new({ "cmd" }, "j", nextTab, nil, nextTab),
  hs.hotkey.new({ "cmd" }, "k", prevTab, nil, prevTab),
  closeTab,
}

function follow(bundleID)
  if passthrough[bundleID] then hotkey:disable() else hotkey:enable() end
  for _, key in ipairs(browserKeys) do
    if browsers[bundleID] then key:enable() else key:disable() end
  end
end

-- Deliberate global: a local watcher is garbage collected and stops firing.
appWatcher = hs.application.watcher.new(function(_, event, app)
  if event == hs.application.watcher.activated and app then follow(app:bundleID()) end
end)
appWatcher:start()
follow(hs.application.frontmostApplication():bundleID())

-- Cmd-Alt-S swaps the focused window with the front window of the other
-- display: the task that only needs a glance (Claude Code waiting for an
-- answer) goes to the side screen while the other one comes back, and the
-- next press reverses it. Alone on its side, the focused window just moves.

local function frontWindowOn(screen)
  for _, window in ipairs(hs.window.orderedWindows()) do
    if window:screen() == screen and window:isStandard() then return window end
  end
end

local function swapDisplays()
  local focused = hs.window.focusedWindow()
  if not focused then return hs.alert.show("No window to swap") end
  if focused:isFullScreen() then return hs.alert.show("Leave full screen first") end
  local here = focused:screen()
  local there = here:next()
  if there == here then return hs.alert.show("Only one display") end
  local other = frontWindowOn(there)
  focused:moveToScreen(there, false, true, 0)
  if other then
    other:moveToScreen(here, false, true, 0)
    -- Deliberate: focus follows the window that arrives where you were, so
    -- the swap also switches what you work on.
    other:focus()
  end
end

hs.hotkey.bind({ "cmd", "alt" }, "s", swapDisplays)

-- Cmd-Alt-C opens the Claude agents menu of SwiftBar, Cmd-Alt-N the dev status
-- one (~/.config/swiftbar). Deliberate: the items are told apart by position,
-- agents on the right, because they expose no identifier and their titles reach
-- accessibility as blanks and digits only. Cmd-dragging them swaps the keys.
-- Deliberate: a mouse click, not AXPress, which SwiftBar acknowledges without
-- opening the menu; the pointer goes back where it was.

local function openSwiftBarMenu(side)
  local app = hs.application.get("com.ameba.SwiftBar")
  if not app then return hs.alert.show("SwiftBar is not running") end
  local axapp = hs.axuielement.applicationElement(app)
  axapp:setTimeout(1)
  local bar = axapp:attributeValue("AXExtrasMenuBar")
  local items = bar and bar:attributeValue("AXChildren") or {}
  if #items < 2 then return hs.alert.show("Expected two SwiftBar items, found " .. #items) end
  table.sort(items, function(a, b) return a:attributeValue("AXPosition").x < b:attributeValue("AXPosition").x end)
  local item = items[side == "left" and 1 or #items]
  local pos, size = item:attributeValue("AXPosition"), item:attributeValue("AXSize")
  local pointer = hs.mouse.absolutePosition()
  hs.eventtap.leftClick({ x = pos.x + size.w / 2, y = pos.y + size.h / 2 })
  hs.mouse.absolutePosition(pointer)
end

hs.hotkey.bind({ "cmd", "alt" }, "c", function() openSwiftBarMenu("right") end)
hs.hotkey.bind({ "cmd", "alt" }, "n", function() openSwiftBarMenu("left") end)
