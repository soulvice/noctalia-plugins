-- Noctalia v5 scripted widget — Tailscale status
--
-- Click mapping:
--   Left click  — toggle up / down (or trigger login flow)
--   Right click — notification with current state + IP
--
-- IPC events:
--   "toggle"     — same as left-click
--   "connect"    — bring Tailscale up (no-op if already running)
--   "disconnect" — bring Tailscale down (no-op if already stopped)
--   "status"     — same as right-click (fires a status notification)

--------------------------------------------------------------------------------
-- Module-level state
--------------------------------------------------------------------------------

local initialized   = false
local queryPending  = false
local icon_size     = 14
local hideWhenOff   = false
local showType      = "none"

-- States
local lastState     = nil
local lastIp        = nil
local lastHostname  = nil
local lastPeerCount = nil
local lastExitNode  = nil

--------------------------------------------------------------------------------
-- State → display config table
-- text = nil means "use bar_label()" (only valid for Running)
--------------------------------------------------------------------------------

local STATE_CONFIG = {
  Initialize       = { visible = true,  glyph = "shield-off", glyphColor = "on_surface_variant",  text = "",      color = "on_surface_variant" },
  Running          = { visible = true,  image = true,                                             text = nil,     color = "on_surface"         },
  Starting         = { visible = true,  glyph = "shield",     glyphColor = "secondary",           text = "…",     color = "on_surface_variant" },
  NeedsMachineAuth = { visible = true,  glyph = "shield",     glyphColor = "secondary",           text = "…",     color = "on_surface_variant" },
  NeedsLogin       = { visible = true,  glyph = "shield-x",   glyphColor = "error",               text = noctalia.tr("bar.login"), color = "error"              },
}

--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function cfg(key, default)
  return barWidget.getConfig(key, default)
end

local function bar_label()
  if showType == "ipaddr"   then return lastIp       or "" end
  if showType == "hostname" then return lastHostname or "" end
  return ""
end

local function parseStatus(stdout)
  local state    = stdout:match('"BackendState"%s*:%s*"([^"]+)"')
  local ip       = stdout:match('"TailscaleIPs"%s*:%s*%[%s*"([^"]+)"')
  local hostname = stdout:match('"Self"%s*:%s*{[^}]-"HostName"%s*:%s*"([^"]+)"')

  -- Each peer has exactly one "nodekey:…" PublicKey; Self is also counted, so subtract 1.
  local peerCount = 0
  for _ in stdout:gmatch('"PublicKey"%s*:%s*"nodekey:[^"]+"') do
    peerCount = peerCount + 1
  end
  peerCount = math.max(0, peerCount - 1)

  -- Find the peer block that has "ExitNode": true and grab its HostName.
  local exitNode = nil
  for block in stdout:gmatch('"nodekey:[^"]+"%s*:%s*(%b{})') do
    if block:match('"ExitNode"%s*:%s*true') then
      exitNode = block:match('"HostName"%s*:%s*"([^"]+)"')
      break
    end
  end

  return state, ip, hostname, peerCount, exitNode
end

--------------------------------------------------------------------------------
-- updateDisplay() — drives all visual state from STATE_CONFIG
--------------------------------------------------------------------------------

function updateDisplay()
  local s = lastState
  local c = STATE_CONFIG[s]

  if not c then
    -- Unknown / Stopped / NoState
    barWidget.setVisible(not hideWhenOff)
    if not hideWhenOff then
      barWidget.setGlyph("shield-off")
      barWidget.setGlyphColor("on_surface_variant")
      barWidget.setText("")
      barWidget.setColor("on_surface_variant")
    end
    return
  end

  barWidget.setVisible(c.visible)

  if c.image then
    barWidget.setImage("~/.config/noctalia/plugins/tailscale/icon.svg", true, icon_size)
  else
    barWidget.setGlyph(c.glyph)
    barWidget.setGlyphColor(c.glyphColor)
  end

  barWidget.setText(c.text ~= nil and c.text or bar_label())
  barWidget.setColor(c.color)
end



--------------------------------------------------------------------------------
-- update() — called every <poll_interval> ms by Noctalia
--------------------------------------------------------------------------------

function update()
  if not initialized then
    initialized = true
    hideWhenOff = cfg("hide_when_disconnected", false)
    showType    = cfg("show_type", "none")
    barWidget.setUpdateInterval(cfg("poll_interval", 5000))
    lastState = "Initialize"
    updateDisplay()
  end
  fetchStatus()
end

--------------------------------------------------------------------------------
-- onClick() — toggle using cached state
--------------------------------------------------------------------------------

function onClick()
  if lastState == "Running" then
    noctalia.runAsync("${tailscaleBin} down")
    noctalia.notify("Tailscale", noctalia.tr("toast.disconnect"))
  elseif lastState == "Stopped" or lastState == "NoState" then
    noctalia.runAsync("${tailscaleBin} up")
    noctalia.notify("Tailscale", noctalia.tr("toast.connect"))
  elseif lastState == "NeedsLogin" then
    noctalia.runAsync("${tailscaleBin} up")
    noctalia.notify("Tailscale", noctalia.tr("toast.need_login"))
  end
end

--------------------------------------------------------------------------------
-- onRightClick() — status notification + copy IP to clipboard
--------------------------------------------------------------------------------

function onRightClick()
  if lastState == nil then return end

  local copied = false
  if lastIp then
    copied = noctalia.copyToClipboard(lastIp, "text/plain")
  end
  local suffix = copied and `\n{noctalia.tr("toast.ip_cb")}` or ""

  if lastIp and lastHostname then
    noctalia.notify("Tailscale · " .. lastState, lastHostname .. "  " .. lastIp .. suffix)
  elseif lastIp then
    noctalia.notify("Tailscale · " .. lastState, lastIp .. suffix)
  else
    noctalia.notify("Tailscale", lastState)
  end
end

--------------------------------------------------------------------------------
-- onHover(isHovering) — tooltip
--------------------------------------------------------------------------------

function onHover(isHovering)
  if not isHovering then
    barWidget.setTooltip("")
    return
  end

  if lastState == nil then
    barWidget.setTooltip(noctalia.tr("tooltip.state_unknown"))
    return
  end

  barWidget.setTooltip({
    { key = "Tailscale",                     value = lastState               },
    { key = noctalia.tr("toast.ipaddr"),     value = lastIp        or "—"    },
    { key = noctalia.tr("toast.hostname"),   value = lastHostname  or "—"    },
    { key = noctalia.tr("toast.exit_node"),  value = lastExitNode  or "Off"  },
    { key = noctalia.tr("toast.peer_count"), value = lastPeerCount or "0"    },
  })
end



local function applyStatus(cmd)
    local hasStatus = type(status) == "table"

    -- Update Current variable states
    updateStates();
end

--------------------------------------------------------------------------------
-- Sync Everything
--------------------------------------------------------------------------------
applyStatus(noctalia.state.get("status"))
noctalia.state.watch("status", applyStatus)
