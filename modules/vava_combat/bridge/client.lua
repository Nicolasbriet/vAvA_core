--[[
    vava_combat/bridge/client.lua
    Rôle : SEUL point de contact, côté client, entre les armes et les autres modules : notification (vava_hud, sinon
           celle du jeu), objet tenu par le personnage local (champ `owner` vava_inventory:hands, lu dans le
           personnage courant du core), nom du statebag de la main de l'inventaire (lu sur les peds des porteurs de
           bouclier). Chaque appel à une autre ressource est isolé.
    Dépendances : shared/constants.lua, config.lua, client/core.lua
]]

local type, pcall, tostring = type, pcall, tostring
local GetResourceState = GetResourceState
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaCombat.core
if not core then return end

local HUD = 'vava_hud'
local HANDS_FIELD = VavaCombat.INVENTORY_HANDS_FIELD
-- natures de notification comprises par vava_hud
local NATURES = { info = 'info', warning = 'warning', danger = 'danger' }

local Bridge = {}
VavaCombat.bridge = Bridge

local function hudNotify(message, kind)
    return exports[HUD]:notify(message, kind)
end

--- Message au joueur : notification de vava_hud, sinon celle du jeu.
---@param message string
---@param kind? string  info | warning | danger
function Bridge.Notify(message, kind)
    if GetResourceState(HUD) == 'started' then
        local called, ok = pcall(hudNotify, message, NATURES[kind] or 'info')
        if called and ok then return end
        if not called then VavaCombat.log.warn('%s.notify en erreur : %s', HUD, tostring(ok)) end
    end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

--- Objet tenu en main par le personnage local (champ de l'inventaire, `owner`), ou nil.
---@return string|nil
function Bridge.HandItem()
    local character = core.characters.current()
    local fields = character and character.fields
    local hands = type(fields) == 'table' and fields[HANDS_FIELD] or nil
    if type(hands) ~= 'table' or type(hands.item) ~= 'string' then return nil end
    return hands.item
end

Bridge.HELD_STATE = VavaCombat.INVENTORY_HELD_STATE
