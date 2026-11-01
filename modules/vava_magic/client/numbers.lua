--[[
    vava_magic/client/numbers.lua
    Rôle : chiffres des sorts du lanceur (T-155) : vava_magic:dealt, ses touchés d'un tour, relus et bornés, montrés par
           vava_hud. Aucune boucle.
    Dépendances : shared/constants.lua, bridge/client.lua
]]

local type, ipairs, pairs, mathType = type, ipairs, pairs, math.type
local RegisterNetEvent = RegisterNetEvent

local bridge = VavaMagic.bridge
local ISSUES = {}
for _, issue in ipairs(VavaMagic.NUMBER_ISSUES) do ISSUES[issue] = true end
local MAX_ENTRIES, MAX_PLAYER, MAX_TENTHS = 32, 65535, 2000

--- Nombre de clés si `list` est une liste pure de 1 à `max` valeurs, sinon nil.
---@return integer|nil
local function pureCount(list, max)
    if type(list) ~= 'table' then return nil end
    local count = 0
    for _ in pairs(list) do
        count = count + 1
        if count > max then return nil end
    end
    if count == 0 or count ~= #list then return nil end
    return count
end

RegisterNetEvent(VavaMagic.EVENTS.DEALT, function(list)
    if not pureCount(list, MAX_ENTRIES) then return end
    for _, entry in ipairs(list) do
        local count = pureCount(entry, 3)
        if count and count >= 2 then
            local target, issue, tenths = entry[1], entry[2], entry[3]
            if mathType(target) == 'integer' and target >= 1 and target <= MAX_PLAYER and ISSUES[issue]
                and (tenths == nil or (mathType(tenths) == 'integer' and tenths >= 0 and tenths <= MAX_TENTHS)) then
                bridge.HitText('dealt', target, issue, tenths)
            end
        end
    end
end)
