-- This can be the core of tailscale noctlia service
-- Use states to communicate the state of tailscale to the bar widget
-- This could handle the IPC events maybe
--
noctalia.setUpdateInterval(250)

local initialized   = false
local lastState     = nil
local lastIp        = nil
local lastHostname  = nil
local lastPeerCount = nil
local lastExitNode  = nil
local queryPending  = false


--------------------------------------------------------------------------------
-- Helpers
--------------------------------------------------------------------------------

local function cfg(key)
    return noctalia.getConfig(key)
end


local function copy_ip_clipboard()
    local copied = false

    if lastState == nil then return end

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


local function tailscale_up(cb)
    if queryPending then return end
    queryPending = true
    local tailscaleBin = cfg("tailscale_bin")
    noctalia.runAsync(`{tailscaleBin} up 2>&1`, function (result)
        queryPending = false
        if not result or result.exitCode ~= 0 then
            noctalia.notifyError("Tailscale", `up failed: {result and result.stdout or "error"}`)
            return
        end
        cb({ state = "connected" })
    end)
end

local function tailscale_down(cb)
    if queryPending then return end
    queryPending = true
    local tailscaleBin = cfg("tailscale_bin")
    noctalia.runAsync(`{tailscaleBin} down 2>&1`, function (result)
        queryPending = false
        if not result or result.exitCode ~= 0 then
            noctalia.notifyError("Tailscale", `down failed: {result and result.stdout or "error"}`)
            return
        end
        cb({ state = "disconnected" })
    end)
end

local function tailscale_toggle(cb)
    if lastState == "Running" then tailscale_down(cb) else tailscale_up(cb) end
end


--------------------------------------------------------------------------------
---
--------------------------------------------------------------------------------
local function publishStatus()
    noctalia.state.set('status', {
        state = lastState,
        ip = lastIp,
        hostname = lastHostname,
        peerCount = lastPeerCount,
        exitNode = lastExitNode
    })
end

--------------------------------------------------------------------------------
-- Async status fetch
--------------------------------------------------------------------------------

local function fetchStatus(cb)
    if queryPending then return end
    queryPending = true
    local tailscaleBin = cfg("tailscale_bin")

    noctalia.runAsync(`{tailscaleBin} status --json 2>/dev/null`, function(result)
        queryPending = false
        if not result or result.exitCode ~= 0 or result.timedOut then
            lastState, lastIp, lastHostname, lastPeerCount, lastExitNode = nil, nil, nil, nil, nil
        else
            lastState, lastIp, lastHostname, lastPeerCount, lastExitNode = parseStatus(result.stdout)
        end
        if cb then cb() end
        publishStatus()
    end)
end



--------------------------------------------------------------------------------
---
--------------------------------------------------------------------------------
function update()
    if not initialized then
        noctalia.setUpdateInterval(cfg("poll_interval"))
        lastState = "Initialize"
        initialized = true
        publishStatus()
    end
    fetchStatus()
end

--------------------------------------------------------------------------------
-- onIpc(event, payload) — programmatic control
--------------------------------------------------------------------------------
function onIpc(event, payload)
    if queryPending then return end
    local tailscaleBin = cfg("tailscale_bin")

    if event == "toggle" then
        tailscale_toggle(function (res)
            noctalia.notify("Tailscale", noctalia.tr(`toast.{res.state}`))
        end)
    elseif event == "connect" then
        if lastState ~= "Running" then
            tailscale_up(function (res)
                noctalia.notify("Tailscale", noctalia.tr(`toast.{res.state}`))
            end)
        end
    elseif event == "disconnect" then
        if lastState == "Running" then
            tailscale_down(function (res)
                noctalia.notify("Tailscale", noctalia.tr(`toast.{res.state}`))
            end)
        end
    elseif event == "status" then
        copy_ip_clipboard()
    else
        noctalia.log("tailscale: unknown IPC event '" .. tostring(event) .. "'")
    end
end


-- The widget and shortcut drive the recorder by publishing to this channel.
noctalia.state.watch("command", function(cmd)
    local action = if type(cmd) == "table" and cmd.action ~= nil then cmd.action else cmd
    if type(action) == "string" then
        onIpc(action, if type(cmd) == "table" then cmd else nil)
    end
end)
