-- wb_hello.lua
-- Phase 1 check: proves the server loads Warband's Lua scripts.
--   * Prints a line in the worldserver console when the scripts load.
--   * Greets every player in chat when they log in.
-- Safe to delete once real systems exist.

local PLAYER_EVENT_ON_LOGIN = 3

print("[Warband] Lua scripts loaded.")

RegisterPlayerEvent(PLAYER_EVENT_ON_LOGIN, function(event, player)
    player:SendBroadcastMessage("|cffffd100[Warband]|r Scripts are running. Welcome, " .. player:GetName() .. ".")
end)
