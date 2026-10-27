--[[
    vava_inventory/client/main.lua
    Rôle : ouverture de l'inventaire et raccourcis (RegisterKeyMapping : touches réglables par le joueur, aucune
           boucle), réception des états envoyés par le serveur, et relais des gestes de l'interface vers le serveur.
    Dépendances : shared/, config.lua, client/core.lua, client/drops.lua, client/nui.lua
]]

local type, tostring, pcall = type, tostring, pcall
local CreateThread, RegisterNetEvent, RegisterCommand, RegisterKeyMapping = CreateThread, RegisterNetEvent, RegisterCommand, RegisterKeyMapping
local IsPauseMenuActive, GetResourceState = IsPauseMenuActive, GetResourceState
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaInventory.core
if not core then return end

local cfg = VavaInventory.config
local RPC = VavaInventory.RPC
local EVENTS = VavaInventory.EVENTS
local HOTBAR_FIELD = VavaInventory.HOTBAR_FIELD
local nui, drops = VavaInventory.nui, VavaInventory.drops

local OPEN_COMMAND = 'vava_inventory'
local SLOT_COMMAND = 'vava_inventory_slot_'
local FEED_TEXT = 'STRING'
local HUD = 'vava_hud'

local open = false

local function hudNotify(message)
    return exports[HUD]:notify(message)
end

--- Message hors de l'interface : notification de vava_hud, sinon celle du jeu.
---@param message string
local function feed(message)
    if GetResourceState(HUD) == 'started' then
        local called, ok = pcall(hudNotify, message)
        if called and ok then return end
        if not called then core.log.warn('%s.notify en erreur : %s', HUD, tostring(ok)) end
    end
    BeginTextCommandThefeedPost(FEED_TEXT)
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function close()
    if not open then return end
    open = false
    nui.send('close')
    nui.setFocus(false)
end

local function openInventory()
    if open or not core.characters.current() or IsPauseMenuActive() then return end
    CreateThread(function()
        -- le serveur revérifie la distance du sac désigné
        core.rpc.call(RPC.OPEN, drops.nearest(cfg.drop.interactDistance))
    end)
end

--- Relaie un geste de l'interface ; réponse homogène pour elle.
---@return table
local function forward(name, ...)
    local ok, success, code = core.rpc.call(name, ...)
    if not ok then return { ok = false, error = tostring(success) } end
    if not success then return { ok = false, error = tostring(code) } end
    return { ok = true }
end

drops.start()

RegisterNetEvent(EVENTS.SNAPSHOT, function(snapshot)
    if type(snapshot) ~= 'table' or not core.characters.current() then return end
    snapshot.closeKey = cfg.keys.open
    nui.send('open', snapshot)
    if not open then
        open = true
        nui.setFocus(true)
    end
end)

RegisterNetEvent(EVENTS.DELTA, function(delta)
    if open and type(delta) == 'table' then nui.send('delta', delta) end
end)

RegisterNetEvent(EVENTS.CLOSED, function(containerId)
    if open then nui.send('containerClosed', { id = containerId }) end
end)

RegisterNetEvent(EVENTS.NOTIFY, function(message)
    if type(message) ~= 'string' then return end
    if open then nui.send('notify', { message = message }) else feed(message) end
end)

nui.on('move', function(d) return forward(RPC.MOVE, d.id, d.container, d.x, d.y, d.rotated == true) end)
nui.on('split', function(d) return forward(RPC.SPLIT, d.id, d.quantity, d.container, d.x, d.y, d.rotated == true) end)
nui.on('merge', function(d) return forward(RPC.MERGE, d.id, d.target, d.quantity) end)
nui.on('drop', function(d) return forward(RPC.DROP, d.id, d.quantity) end)
nui.on('use', function(d) return forward(RPC.USE, d.id) end)
nui.on('hotbarSet', function(d) return forward(RPC.HOTBAR_SET, d.slot, d.id) end)
nui.on('close', function()
    close()
    core.rpc.emit(RPC.CLOSE)
    return { ok = true }
end)

RegisterCommand(OPEN_COMMAND, openInventory, false)
RegisterKeyMapping(OPEN_COMMAND, cfg.labels.open, 'keyboard', cfg.keys.open)

for slot = 1, cfg.hotbarSize do
    local command = SLOT_COMMAND .. slot
    RegisterCommand(command, function()
        if not open and core.characters.current() then core.rpc.emit(RPC.HOTBAR_USE, slot) end
    end, false)
    RegisterKeyMapping(command, cfg.labels.slot:format(slot), 'keyboard', cfg.keys.hotbar[slot])
end

core.hooks.after('core:character:unloaded', close)
core.hooks.after('core:character:fieldChanged', function(change)
    if open and change.field == HOTBAR_FIELD then nui.send('hotbar', { hotbar = change.value }) end
end)
