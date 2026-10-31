--[[
    vava_combat/bridge/client.lua
    Rôle : SEUL point de contact, côté client, entre les armes et les autres modules : notification (vava_hud, sinon
           celle du jeu), objet tenu par le personnage local (champ `owner` vava_inventory:hands) gardé dans une variable
           locale et tenu par les hooks du core (personnage chargé, champ changé, personnage déchargé) : aucune lecture
           du personnage à chaque appel (rapport T-140, R-1) ; changement de main annoncé aux fichiers du module ; à
           terre (vava_health:get) ; nom du statebag de la main de l'inventaire (lu sur les peds des porteurs de
           bouclier). Chaque appel à une autre ressource est isolé.
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua
]]

local type, pcall, tostring, ipairs = type, pcall, tostring, ipairs
local GetResourceState = GetResourceState
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaCombat.core
if not core then return end

local HUD, HEALTH = 'vava_hud', 'vava_health'
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

-- Main du personnage local ---------------------------------------------------------------------------------------

-- objet tenu (nil : mains vides, ou aucun personnage)
local handItem = nil
---@type fun(old: string|nil, new: string|nil, reason: string)[]
local handListeners = {}

--- Objet tenu d'après la valeur du champ de la main (seul `item` est lu ; toute autre forme : mains vides).
---@param value any
---@return string|nil
local function itemOf(value)
    if type(value) == 'table' and type(value.item) == 'string' then return value.item end
    return nil
end

--- Objet tenu d'après un personnage `{ fields }` (chargé, ou courant).
---@param character any
---@return string|nil
local function itemOfCharacter(character)
    local fields = type(character) == 'table' and character.fields or nil
    return itemOf(type(fields) == 'table' and fields[HANDS_FIELD] or nil)
end

---@param item string|nil
---@param reason string  loaded | changed | unloaded
local function setHand(item, reason)
    if item == handItem and reason == 'changed' then return end
    local old = handItem
    handItem = item
    for _, listener in ipairs(handListeners) do
        local ok, err = pcall(listener, old, item, reason)
        if not ok then VavaCombat.log.warn('changement de main : %s', tostring(err)) end
    end
end

--- Objet tenu en main par le personnage local, ou nil : lecture d'une variable locale (aucun appel au core).
---@return string|nil
function Bridge.HandItem()
    return handItem
end

--- Prévient `handler(ancien, nouveau, raison)` quand la main change : `loaded` (personnage chargé, main restaurée,
--- sans geste), `changed` (prise en main ou dépôt), `unloaded` (retour à la sélection).
---@param handler fun(old: string|nil, new: string|nil, reason: string)
function Bridge.OnHandChanged(handler)
    handListeners[#handListeners + 1] = handler
end

core.hooks.after('core:character:loaded', function(character)
    setHand(itemOfCharacter(character), 'loaded')
end)
core.hooks.after('core:character:fieldChanged', function(payload)
    if type(payload) ~= 'table' or payload.field ~= HANDS_FIELD then return end
    setHand(itemOf(payload.value), 'changed')
end)
core.hooks.after('core:character:unloaded', function()
    setHand(nil, 'unloaded')
end)
-- ressource (re)démarrée en jeu : une seule lecture du personnage courant
handItem = itemOfCharacter(core.characters.current())

-- Santé ---------------------------------------------------------------------------------------------------------------

local function healthGet()
    return exports[HEALTH]:get()
end

--- Vrai si le joueur local est à terre (vava_health:get) ; module absent ou en erreur : faux. Lu au relevé des
--- conditions du mode combat (200 ms), jamais à chaque image.
---@return boolean
function Bridge.IsDowned()
    if GetResourceState(HEALTH) ~= 'started' then return false end
    local ok, state = pcall(healthGet)
    return ok and type(state) == 'table' and state.downed == true
end

Bridge.HELD_STATE = VavaCombat.INVENTORY_HELD_STATE
