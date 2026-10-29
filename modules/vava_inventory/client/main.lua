--[[
    vava_inventory/client/main.lua
    Rôle : ouverture de l'inventaire et raccourcis (RegisterKeyMapping : touches réglables par le joueur, aucune
           boucle ; la touche choisie pour ouvrir ferme aussi l'interface), réception des états envoyés par le serveur
           (dont l'objet en main), et relais des gestes de l'interface vers le serveur.
    Dépendances : shared/, config.lua, client/core.lua, client/drops.lua, client/hands.lua, client/nui.lua
]]

local type, tostring, tonumber, pcall = type, tostring, tonumber, pcall
local tointeger = math.tointeger
local match = string.match
local CreateThread, RegisterNetEvent, RegisterCommand, RegisterKeyMapping = CreateThread, RegisterNetEvent, RegisterCommand, RegisterKeyMapping
local IsPauseMenuActive, GetResourceState = IsPauseMenuActive, GetResourceState
local GetControlInstructionalButton, GetHashKey = GetControlInstructionalButton, GetHashKey
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaInventory.core
if not core then return end

local cfg = VavaInventory.config
local RPC = VavaInventory.RPC
local EVENTS = VavaInventory.EVENTS
local HOTBAR_FIELD = VavaInventory.HOTBAR_FIELD
local HANDS_FIELD = VavaInventory.HANDS_FIELD
local nui, drops, hands = VavaInventory.nui, VavaInventory.drops, VavaInventory.hands

local OPEN_COMMAND = 'vava_inventory'
local SLOT_COMMAND = 'vava_inventory_slot_'
local FEED_TEXT = 'STRING'
local HUD = 'vava_hud'
-- bit qui désigne, pour GTA, une commande liée par RegisterKeyMapping
local MAPPED_COMMAND = 0x80000000
local UINT32 = 0xFFFFFFFF
-- Touches que GTA montre par une icône (« b_… ») et non par leur texte (« t_I ») → nom lu par l'interface
-- (`KeyboardEvent.key`). Codes des boutons d'instruction de GTA, à confirmer en jeu (test 1-6) ; une touche absente
-- d'ici ne ferme pas l'inventaire (Échap le fait toujours). Les touches de modification n'y sont pas : Maj sert à
-- diviser une pile en glissant.
local ICON_KEYS = {
    b_1002 = 'Tab', b_1003 = 'Enter', b_1004 = 'Backspace', b_1012 = 'CapsLock', b_2000 = ' ',
    b_170 = 'F1', b_171 = 'F2', b_172 = 'F3', b_173 = 'F4', b_174 = 'F5', b_175 = 'F6',
    b_176 = 'F7', b_177 = 'F8', b_178 = 'F9', b_179 = 'F10', b_180 = 'F11', b_181 = 'F12',
}

local open = false

--- Touche que le joueur a choisie pour ouvrir l'inventaire (Paramètres > Raccourcis > FiveM), sous le nom que lit
--- l'interface : le texte que GTA en montre (« I »), ou le nom d'une touche à icône connue (« Tab ») ; '' si elle
--- n'est pas reconnue (alors seul Échap ferme, jamais une touche qui n'ouvre pas).
---@return string
local function closeKey()
    local button = GetControlInstructionalButton(0, (GetHashKey(OPEN_COMMAND) | MAPPED_COMMAND) & UINT32, true)
    if type(button) ~= 'string' then return '' end
    return match(button, '^t_(.+)$') or ICON_KEYS[button] or ''
end

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
hands.start()

RegisterNetEvent(EVENTS.SNAPSHOT, function(snapshot)
    if type(snapshot) ~= 'table' or not core.characters.current() then return end
    -- relue à chaque ouverture : un changement de touche s'applique sans redémarrage
    snapshot.closeKey = closeKey()
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

-- fermeture ordonnée par le serveur (export `close` : mise à terre…) : comme la touche de fermeture
RegisterNetEvent(EVENTS.DISMISS, close)

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
nui.on('hold', function(d) return forward(RPC.HOLD, d.id) end)
-- bandeau du catalogue de développement : le serveur revérifie le droit et renvoie la page garnie
nui.on('catalog', function(d)
    local category = type(d.category) == 'string' and d.category or ''
    local query = type(d.query) == 'string' and d.query:sub(1, 48) or ''
    return forward(RPC.CATALOG, category, tointeger(tonumber(d.page or 0)) or 1, query)
end)
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
    if not open then return end
    if change.field == HOTBAR_FIELD then
        nui.send('hotbar', { hotbar = change.value })
    elseif change.field == HANDS_FIELD then
        nui.send('hands', { id = type(change.value) == 'table' and change.value.id or 0 })
    end
end)
