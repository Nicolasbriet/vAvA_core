--[[
    vava_provisions/server/containers.lua
    Rôle : le contenant qui revient. Abonné au hook vava_inventory:use (phase after) : une outre d'eau réellement bue
           (`consumed`, que l'inventaire ne met qu'après avoir retiré une unité) rend une outre vide, sauf une fois sur
           dix où elle se fend ; sans place dans la besace, elle est abandonnée. Le personnage est lu dans le hook,
           l'ajout se fait dans un thread (jamais d'appel à l'inventaire pendant son propre `use`) et seulement si le
           joueur a toujours le même personnage. Avis (`torn`, `lost`) au SEUL buveur.
    Dépendances : shared/constants.lua, config.lua, shared/rules.lua, server/core.lua, bridge/server.lua
]]

local type, tostring = type, tostring
local mathType, random = math.type, math.random
local CreateThread = CreateThread

local bridge = VavaProvisions.bridge
local rules = VavaProvisions.rules
local cfg = VavaProvisions.config
local EVENTS, NOTICES = VavaProvisions.EVENTS, VavaProvisions.NOTICES

local containers = {}
VavaProvisions.containers = containers

--- Après l'utilisation d'un objet de la besace.
---@param payload { source: integer, item: string, consumed: boolean }
function containers.onUse(payload)
    if type(payload) ~= 'table' or payload.consumed ~= true then return end
    local container = cfg.containers[payload.item]
    if not container then return end
    local source = payload.source
    if mathType(source) ~= 'integer' or source <= 0 then return end
    local characterId = bridge.ActiveCharacterId(source)
    if not characterId then return end
    CreateThread(function()
        if bridge.ActiveCharacterId(source) ~= characterId then return end
        if not rules.keepsContainer(random(), container.tearChance) then
            bridge.Send(source, EVENTS.NOTICE, NOTICES.TORN)
            return
        end
        local ok, code = bridge.Add(source, container.empty, 1)
        if not ok then
            VavaProvisions.log.debug("outre vide non rendue au joueur %d (personnage n° %d) : %s", source, characterId, tostring(code))
            bridge.Send(source, EVENTS.NOTICE, NOTICES.LOST)
        end
    end)
end
