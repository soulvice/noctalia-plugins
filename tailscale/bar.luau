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
local icon_size     = 14

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

local function cfg(key)
    return barWidget.getConfig(key)
end

local function bar_label()
    local show_label = cfg("show_label")
    local label_content = cfg("label_content")

    if not show_label then
        return ""
    else
        if label_content == "ipaddr"   then return lastIp       or "" end
        if label_content == "hostname" then return lastHostname or "" end
    end
    return ""
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
        barWidget.setImage("icons/tailscale.svg", true, icon_size)
    else
        barWidget.setGlyph(c.glyph)
        barWidget.setGlyphColor(c.glyphColor)
    end

    barWidget.setText(c.text ~= nil and c.text or bar_label())
    barWidget.setColor(c.color)

    -- Tooltip
    if lastState == nil then
        barWidget.setTooltip(noctalia.tr("tooltip.state_unknown"))
        return
    end

    barWidget.setTooltip({
        { key = "Tailscale",                       value = lastState               },
        { key = noctalia.tr("tooltip.ip_address"), value = lastIp        or "—"    },
        { key = noctalia.tr("tooltip.hostname"),   value = lastHostname  or "—"    },
        { key = noctalia.tr("tooltip.exit_node"),  value = lastExitNode  or "Off"  },
        { key = noctalia.tr("tooltip.peer_count"), value = lastPeerCount or "0"    },
    })
end



--------------------------------------------------------------------------------
-- update() — called every <poll_interval> ms by Noctalia
--------------------------------------------------------------------------------

function update()
    updateDisplay()
end

--------------------------------------------------------------------------------
-- onClick() — toggle using cached state
--------------------------------------------------------------------------------

function onClick()
    if lastState == "Running" then
        noctalia.state.set("command", { action = "disconnect" })
    elseif lastState == "Stopped" or lastState == "NoState" then
        noctalia.state.set("command", { action = "connect" })
    elseif lastState == "NeedsLogin" then
        noctalia.state.set("command", { action = "connect" })
    end
end

--------------------------------------------------------------------------------
-- onRightClick() — status notification + copy IP to clipboard
--------------------------------------------------------------------------------

function onRightClick()
    noctalia.state.set("command", { action = "status" })
end




local function applyStatus(status)
    local hasStatus = type(status) == "table"

    lastState = if hasStatus and status.state ~= nil then status.state else ""
    lastIp = if hasStatus and status.ip ~= nil then status.ip else ""
    lastHostname = if hasStatus and status.hostname ~= nil then status.hostname else ""
    lastPeerCount = if hasStatus and status.peerCount ~= nil then status.peerCount else ""
    lastExitNode = if hasStatus and status.exit ~= nil then status.exitNode else ""

    -- Update Current variable states
    update()
end

--------------------------------------------------------------------------------
-- Sync Everything
--------------------------------------------------------------------------------
applyStatus(noctalia.state.get("status"))
noctalia.state.watch("status", applyStatus)
