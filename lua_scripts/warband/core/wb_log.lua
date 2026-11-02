-- wb_log.lua
-- Writes important events to the warband_log table (and the worldserver console), so a bug
-- can be traced from the log instead of from memory.
--   Log.Event(companyGuid, "mission_start", "deadmines_short")
--
-- Use from other files:  local Log = require("wb_log")

local Log = {}

local function Escape(text)
    return (tostring(text or ""):gsub("\\", "\\\\"):gsub("'", "\\'"))
end

function Log.Event(company, event, detail)
    detail = tostring(detail or "")
    print(string.format("[Warband] %s company=%d %s", event, company or 0, detail))
    CharDBExecute(string.format("INSERT INTO `warband_log` (`company`, `event`, `detail`) VALUES (%d, '%s', '%s')",
        company or 0, Escape(event), Escape(detail:sub(1, 255))))
end

-- Wraps a hook handler so a Lua error is written to warband_log (event "lua_error") instead of
-- only scrolling past in the server console. The handler's return values pass through.
--   RegisterPlayerEvent(3, Log.Safe("login", function(event, player) ... end))
function Log.Safe(name, fn)
    return function(...)
        local result = { xpcall(fn, debug.traceback, ...) }
        if not result[1] then
            Log.Event(0, "lua_error", name .. ": " .. tostring(result[2]))
            return nil
        end
        return (table.unpack or unpack)(result, 2) -- the server's Lua 5.2 only has table.unpack
    end
end

return Log
