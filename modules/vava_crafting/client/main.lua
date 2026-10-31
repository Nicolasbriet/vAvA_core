--[[
    vava_crafting/client/main.lua
    Rôle : assemblage côté joueur : touche d'interaction (réglable par le joueur, aucune boucle), évènements du serveur
           (résultat d'une pièce, notifications par vava_hud sinon celles du jeu ; les stations arrivent par les zones
           du core, client/props.lua), retours de l'interface relayés au serveur (RPC à schéma strict), fermeture au
           déchargement du personnage.
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua, client/nui.lua, client/props.lua,
                  client/interact.lua
]]

local type, tostring, pcall = type, tostring, pcall
local pack, unpack = table.pack, table.unpack
local RegisterNetEvent, RegisterCommand, RegisterKeyMapping = RegisterNetEvent, RegisterCommand, RegisterKeyMapping
local IsPauseMenuActive, GetResourceState = IsPauseMenuActive, GetResourceState
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaCrafting.core
if not core then return end

local cfg = VavaCrafting.config
local RPC = VavaCrafting.RPC
local EVENTS = VavaCrafting.EVENTS
local nui, props, interact = VavaCrafting.nui, VavaCrafting.props, VavaCrafting.interact

local INTERACT_COMMAND = 'vava_crafting_interact'
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

RegisterNetEvent(EVENTS.CRAFTED, function(payload)
    interact.onCrafted(payload)
end)

-- Retours de l'interface --------------------------------------------------------------------------------------------

--- Une pièce ou une réparation acceptée par le serveur lance le geste ; sinon le menu reste ouvert avec l'erreur.
---@param kind 'craft'|'repair'
---@param stationId any
---@param response table
local function started(kind, stationId, response)
    if response.ok and type(response.result) == 'table' and type(stationId) == 'string' then
        interact.startWork(stationId, kind, response.result)
        response.result = nil
    end
    return response
end

nui.on('craft', function(d)
    local choices = type(d.choices) == 'table' and d.choices or {}
    return started('craft', d.stationId, forward(RPC.CRAFT, function(r, result) r.result = result end, d.stationId, d.recipeId, choices))
end)
nui.on('repair', function(d)
    return started('repair', d.stationId, forward(RPC.REPAIR, function(r, result) r.result = result end, d.stationId, d.instanceId))
end)
nui.on('fuel', function(d)
    return forward(RPC.FUEL, function(r, result)
        if type(result) == 'table' then r.stock, r.capacity = result.stock, result.capacity end
    end, d.stationId, d.quantity)
end)
nui.on('setMark', function(d) return forward(RPC.MARK, nil, d.glyph) end)
nui.on('name', function(d)
    local response = forward(RPC.NAME, nil, d.instanceId, d.name)
    if response.ok then interact.onNamingClosed() end
    return response
end)
nui.on('nameLater', function()
    interact.onNamingClosed()
    return { ok = true }
end)
nui.on('refresh', function() return interact.refreshMenu() end)
nui.on('close', function()
    interact.closeMenu()
    return { ok = true }
end)

core.hooks.after('core:character:unloaded', function() interact.reset() end)

props.start()
