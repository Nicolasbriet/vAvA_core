--[[
    vava_farming/client/main.lua
    Rôle : assemblage côté joueur : touche d'interaction (réglable par le joueur, aucune boucle), évènements du serveur
           (emplacement mis à jour, notifications par vava_hud sinon celles du jeu), retours de l'interface relayés au
           serveur (RPC à schéma strict), fermeture au déchargement du personnage.
    Dépendances : shared/constants.lua, config.lua, client/core.lua, client/nui.lua, client/props.lua,
                  client/interact.lua
]]

local type, tostring, pcall = type, tostring, pcall
local pack, unpack = table.pack, table.unpack
local tointeger = math.tointeger
local RegisterNetEvent, RegisterCommand, RegisterKeyMapping = RegisterNetEvent, RegisterCommand, RegisterKeyMapping
local IsPauseMenuActive, GetResourceState = IsPauseMenuActive, GetResourceState
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaFarming.core
if not core then return end

local cfg = VavaFarming.config
local RPC = VavaFarming.RPC
local EVENTS = VavaFarming.EVENTS
local nui, props, interact = VavaFarming.nui, VavaFarming.props, VavaFarming.interact

local INTERACT_COMMAND = 'vava_farming_interact'
local FEED_TEXT = 'STRING'
local HUD = 'vava_hud'

local function hudNotify(message, kind)
    return exports[HUD]:notify(message, kind)
end

--- Message au joueur : notification de vava_hud, sinon celle du jeu.
---@param message string
---@param kind? string  info | warning | danger
local function feed(message, kind)
    if GetResourceState(HUD) == 'started' then
        local called, ok = pcall(hudNotify, message, kind)
        if called and ok then return end
        if not called then core.log.warn('%s.notify en erreur : %s', HUD, tostring(ok)) end
    end
    BeginTextCommandThefeedPost(FEED_TEXT)
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

--- Relaie un geste de l'interface au serveur ; `shape(réponse, …valeurs)` range les valeurs renvoyées dans la réponse
--- homogène { ok, error? } attendue par l'interface.
---@param name string
---@param shape? fun(response: table, ...: any)
---@return table
local function forward(name, shape, ...)
    local results = pack(core.rpc.call(name, ...))
    local ok, success = results[1], results[2]
    if not ok then return { ok = false, error = tostring(success) } end
    if not success then return { ok = false, error = tostring(results[3]) } end
    local response = { ok = true }
    if shape then shape(response, unpack(results, 3, results.n)) end
    return response
end

--- Entier venu de l'interface (le JSON transmet des flottants), ou `default`.
---@param value any
---@param default integer
---@return integer
local function integer(value, default)
    local number = tonumber(value)
    return number and tointeger(math.floor(number)) or default
end

-- Touche d'interaction -----------------------------------------------------------------------------------------------

RegisterCommand(INTERACT_COMMAND, function()
    if not core.characters.current() or IsPauseMenuActive() then return end
    interact.press()
end, false)
RegisterKeyMapping(INTERACT_COMMAND, cfg.labels.interact, 'keyboard', cfg.keys.interact)

-- Évènements du serveur ----------------------------------------------------------------------------------------------

RegisterNetEvent(EVENTS.NOTIFY, function(message, kind)
    if type(message) == 'string' then feed(message, kind) end
end)

RegisterNetEvent(EVENTS.SLOT, function(payload)
    interact.onSlot(payload)
end)

-- Retours de l'interface --------------------------------------------------------------------------------------------

--- Un geste accepté par le serveur commence ; sinon le menu reste ouvert avec l'erreur.
nui.on('begin', function(d)
    local parcelId, index, action = d.parcelId, integer(d.slot, 0), d.action
    if type(parcelId) ~= 'string' or type(action) ~= 'string' or index < 1 then return { ok = false, error = 'client_error' } end
    local crop = type(d.crop) == 'string' and d.crop or ''
    local tier = integer(d.tier, 0)
    local response = forward(RPC.BEGIN, function(r, result) r.result = result end, parcelId, index, action, crop, tier)
    if response.ok and type(response.result) == 'table' then
        interact.startWork(parcelId, index, action, response.result)
        response.result = nil
    end
    return response
end)
nui.on('refresh', function() return interact.refreshMenu() end)
nui.on('close', function()
    interact.closeMenu()
    return { ok = true }
end)

core.hooks.after('core:character:unloaded', function() interact.reset() end)

props.start()
