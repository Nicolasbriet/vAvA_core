--[[
    vava_magic/client/numbers.lua
    Rôle : chiffres des sorts du lanceur (T-155) : vava_magic:dealt → vava_hud:hitText, qui relit chaque valeur.
    Dépendances : shared/constants.lua, bridge/client.lua
]]

local type, ipairs = type, ipairs
local RegisterNetEvent = RegisterNetEvent

local bridge = VavaMagic.bridge
local MAX_ENTRIES = VavaMagic.NUMBERS.MAX_ENTRIES

RegisterNetEvent(VavaMagic.EVENTS.DEALT, function(list)
    if type(list) ~= 'table' or #list > MAX_ENTRIES then return end
    for _, entry in ipairs(list) do
        if type(entry) == 'table' then bridge.HitText('dealt', entry[1], entry[2], entry[3]) end
    end
end)
