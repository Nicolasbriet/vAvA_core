--[[
    vava_magic/server/numbers.lua
    Rôle : chiffres des sorts pour le lanceur (T-155) : les touchés d'un même tour du serveur (éclats d'une Boule de
           feu, victimes d'une Nova ou d'une Secousse, une passe d'un mur de flammes, une morsure de brûlure) sont
           réunis et partent en UN message `vava_magic:dealt` au seul lanceur, à la fin du tour (SetTimeout(0) posé au
           premier touché ; bridge.SendTo, compté par core.net), s'il joue encore un personnage. Au plus
           `numbers.maxPerMessage` touchés par message (au-delà : ignorés). Mémoire vidée à chaque fin de tour, oubliée
           au départ du joueur. Ne cède jamais la main.
    Dépendances : shared/constants.lua, config.lua, bridge/server.lua, server/spells.lua
]]

local pairs = pairs
local SetTimeout = SetTimeout

local bridge = VavaMagic.bridge
local cfg = VavaMagic.config.numbers
local EVENTS = VavaMagic.EVENTS

local numbers = {}
VavaMagic.numbers = numbers

---@type table<integer, table[]>  lanceur → { { cible, issue[, dixièmes] }, … } du tour en cours
local pending = {}
local scheduled = false

--- Fin du tour : un message par lanceur encore en jeu, puis tout est oublié.
function numbers.flush()
    scheduled = false
    local batch = pending
    pending = {}
    for caster, list in pairs(batch) do
        if bridge.GetCharacterId(caster) then bridge.SendTo(caster, EVENTS.DEALT, list) end
    end
end

--- Un touché du lanceur dans ce tour (le serveur vient de le juger par la chaîne).
---@param caster integer
---@param target integer
---@param issue string        harm.NUMBER_ISSUES
---@param tenths integer|nil
function numbers.add(caster, target, issue, tenths)
    local list = pending[caster]
    if not list then
        list = {}
        pending[caster] = list
    end
    if #list >= cfg.maxPerMessage then return end
    list[#list + 1] = tenths and { target, issue, tenths } or { target, issue }
    if not scheduled then
        scheduled = true
        SetTimeout(0, numbers.flush)
    end
end

VavaMagic.spells.onLeave(function(src)
    pending[src] = nil
end)
