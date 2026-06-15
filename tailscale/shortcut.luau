local function applyStatus(cmd)
    local hasStatus = type(status) == "table"


end

--------------------------------------------------------------------------------
-- Sync Everything
--------------------------------------------------------------------------------
applyStatus(noctalia.state.get("status"))
noctalia.state.watch("status", applyStatus)
