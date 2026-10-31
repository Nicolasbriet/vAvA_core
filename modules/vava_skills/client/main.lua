--[[
    vava_skills/client/main.lua
    Rôle : le livre des compétences côté joueur : ouverture par une touche (RegisterKeyMapping : réglable par le
           joueur, aucune boucle), fiche demandée au serveur à chaque ouverture, évènements du serveur relayés à
           l'interface quand elle est ouverte, gestes de l'interface relayés au serveur (RPC à schéma strict),
           notifications par vava_hud (sinon celles du jeu). Le client n'a aucune donnée propre : tout vient du
           serveur, qui décide de tout.
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua, client/nui.lua
]]

local type, tostring, pcall = type, tostring, pcall
local pack, unpack = table.pack, table.unpack
local CreateThread, RegisterNetEvent, RegisterCommand, RegisterKeyMapping = CreateThread, RegisterNetEvent, RegisterCommand, RegisterKeyMapping
local IsPauseMenuActive, GetResourceState = IsPauseMenuActive, GetResourceState
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaSkills.core
if not core then return end

local cfg = VavaSkills.config
local RPC = VavaSkills.RPC
local EVENTS = VavaSkills.EVENTS
local nui = VavaSkills.nui

local OPEN_COMMAND = 'vava_skills'
local FEED_TEXT = 'STRING'
local HUD = 'vava_hud'
-- joueurs à portée pour un mentorat (ajouté au protocole après les autres RPC : repli sur le nom convenu)
local RPC_NEARBY = RPC.NEARBY or 'vava_skills:nearby'

local open = false

local function hudNotify(message, kind)
    return exports[HUD]:notify(message, kind)
end

--- Message hors de l'interface : notification de vava_hud, sinon celle du jeu.
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

local function close()
    if not open then return end
    open = false
    nui.send('close')
    nui.setFocus(false)
end

--- Ouvre le livre : la fiche est demandée au serveur, puis affichée. Rien n'est ouvert si la fiche manque.
local function openBook()
    if open or not core.characters.current() or IsPauseMenuActive() then return end
    CreateThread(function()
        local ok, success, sheet = core.rpc.call(RPC.SHEET)
        if not ok or not success or type(sheet) ~= 'table' then
            core.log.warn('fiche des compétences indisponible : %s', tostring(ok and sheet or success))
            feed(cfg.messages.unavailable, 'warning')
            return
        end
        -- le joueur a pu changer d'avis ou de personnage pendant l'attente
        if open or not core.characters.current() or IsPauseMenuActive() then return end
        sheet.closeKey = cfg.keys.open
        open = true
        nui.send('open', sheet)
        nui.setFocus(true)
    end)
end

local function toggle()
    if open then close() else openBook() end
end

--- Relaie un geste de l'interface au serveur ; `shape(réponse, …valeurs)` range les valeurs renvoyées par le
--- serveur dans la réponse homogène { ok, error? } attendue par l'interface.
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

-- Évènements du serveur : relayés au livre ouvert ; une notification arrive déjà rédigée par le serveur ---------------

local function relay(event, action)
    RegisterNetEvent(event, function(payload)
        if open and type(payload) == 'table' then nui.send(action, payload) end
    end)
end

relay(EVENTS.SKILL, 'skill')
relay(EVENTS.PROPOSAL, 'proposal')
relay(EVENTS.MENTORSHIP, 'mentorship')
relay(EVENTS.RECIPE, 'recipe')
relay(EVENTS.LESSON, 'lesson')

RegisterNetEvent(EVENTS.NOTIFY, function(message, kind)
    if type(message) ~= 'string' then return end
    if open then nui.send('notify', { message = message, kind = kind }) else feed(message, kind) end
end)

-- Gestes de l'interface -----------------------------------------------------------------------------------------------

nui.on('setMode', function(d)
    return forward(RPC.MODE, function(r, skill, budget) r.skill, r.budget = skill, budget end, d.skill, d.mode)
end)
nui.on('nearby', function()
    return forward(RPC_NEARBY, function(r, players) r.players = players end)
end)
nui.on('propose', function(d) return forward(RPC.PROPOSE, nil, d.serverId, d.skill) end)
nui.on('answer', function(d) return forward(RPC.ANSWER, nil, d.id, d.accept == true) end)
nui.on('break', function(d) return forward(RPC.BREAK, nil, d.mentorshipId) end)
nui.on('lineage', function(d)
    return forward(RPC.LINEAGE, function(r, lineage) r.lineage = lineage end, d.recipe)
end)
nui.on('shortages', function()
    return forward(RPC.SHORTAGES, function(r, list) r.shortages = list end)
end)
nui.on('refresh', function()
    return forward(RPC.SHEET, function(r, sheet)
        if type(sheet) == 'table' then sheet.closeKey = cfg.keys.open end
        r.sheet = sheet
    end)
end)
nui.on('close', function()
    close()
    return { ok = true }
end)

RegisterCommand(OPEN_COMMAND, toggle, false)
RegisterKeyMapping(OPEN_COMMAND, cfg.labels.open, 'keyboard', cfg.keys.open)

core.hooks.after('core:character:unloaded', close)
