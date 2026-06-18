-- States
local lastState     = nil
local lastIp        = nil
local lastHostname  = nil
local lastPeerCount = nil
local lastExitNode  = nil

local function applyStatus(status)
    local hasStatus = type(status) == "table"

    lastState = status.state
    lastIp = status.ip
    lastHostname = status.hostname
    lastPeerCount = status.peerCount
    lastExitNode = status.exitNode

    shortcut.setIcon("shield", "shield-off")
    shortcut.setActive( status.state == "Running" )
    shortcut.setEnabled( true )
    shortcut.setLabel(
        if status.state == "Running" then
            "Tailscale\n" .. lastIp  .. ( lastExitNode or "")
        else
            "Tailscale Down"
    )
end

--------------------------------------------------------------------------------
-- Sync Everything
--------------------------------------------------------------------------------
applyStatus(noctalia.state.get("status"))
noctalia.state.watch("status", applyStatus)


function onClick()
    noctalia.state.set("command", { action = "toggle" })
end

function onRightClick()
    noctalia.state.set("command", { action = "status" })
end
