--[[
    vava_magic/client/main.lua
    Rôle : assemblage côté client : à l'apparition du personnage, vue de la fiche demandée au serveur (et mana) ;
           hors du jeu (sélection), tout est oublié, le mode magie endormi, la roue et les fenêtres fermées, les états
           et les zones effacés ; ordres du serveur (fiche changée, mana, recharges effacées, messages, lignes du
           chat) ; suggestions des commandes du Conseil pour qui y a droit ; redémarrages du chat et du module.
    Dépendances : shared/, config_client.lua, tous les fichiers client/ du module
]]

local type, ipairs = type, ipairs
local CreateThread, RegisterNetEvent, AddEventHandler, SetNuiFocus, SetNuiFocusKeepInput =
    CreateThread, RegisterNetEvent, AddEventHandler, SetNuiFocus, SetNuiFocusKeepInput

local core = VavaMagic.core
if not core then return end

local bridge = VavaMagic.bridge
local nui = VavaMagic.nui
local state = VavaMagic.state
local hud = VavaMagic.hud
local fx = VavaMagic.fx
local casting = VavaMagic.casting
local controls = VavaMagic.controls
local wheel = VavaMagic.wheel
local ambient = VavaMagic.ambient
local conditions = VavaMagic.conditions
local zoneRender = VavaMagic.zoneRender
local projectiles = VavaMagic.projectiles
local targeting = VavaMagic.targeting
local keys = VavaMagic.keys
local cfg = VavaMagic.config
local RPC = VavaMagic.RPC
local EVENTS = VavaMagic.EVENTS
local LINKS = VavaMagic.LINKS

local playing = false

--- Vue de la fiche demandée au serveur (la mana suit par son propre envoi).
local function fetch()
    CreateThread(function()
        local transport, success, result = core.rpc.call(RPC.SHEET)
        if not transport or not success or type(result) ~= 'table' then return end
        state.set(result.view, result.catalog)
        state.setAdmin(result.admin)
        if result.admin then keys.suggest(cfg.commands.admin, cfg.texts.suggestions.admin) end
    end)
end

local function start()
    if playing then return end
    playing = true
    fetch()
end

local function stop()
    if not playing then return end
    playing = false
    casting.reset()
    controls.sleep()
    wheel.close()
    targeting.release()
    conditions.reset()
    zoneRender.clear()
    nui.close()
    state.clear()
end

core.hooks.after('core:character:spawning', start)
core.hooks.after('core:character:selection', stop)
core.hooks.after('core:character:unloaded', stop)

RegisterNetEvent(EVENTS.NOTIFY, function(message, kind)
    if type(message) == 'string' then bridge.Notify(message, kind) end
end)

RegisterNetEvent(EVENTS.SHEET, function(view)
    if playing then state.set(view) end
end)

RegisterNetEvent(EVENTS.MANA, function(value, max, points, period, elapsed)
    for _, number in ipairs({ value, max, points, period, elapsed }) do
        if type(number) ~= 'number' then return end
    end
    state.setMana(value, max, points, period, elapsed)
    hud.mana(value, max, points, period, elapsed)
end)

RegisterNetEvent(EVENTS.COOLDOWNS, function()
    state.resetCooldowns()
end)

RegisterNetEvent(EVENTS.CHAT, function(lines)
    if type(lines) ~= 'table' then return end
    local clean = {}
    for _, line in ipairs(lines) do
        if type(line) == 'string' then clean[#clean + 1] = line end
    end
    bridge.ChatLines(clean)
end)

AddEventHandler('onClientResourceStart', function(resource)
    if resource == LINKS.CHAT then keys.resuggest() end
end)

AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaMagic.resource then return end
    casting.reset()
    controls.sleep()
    projectiles.stop()
    conditions.reset()
    zoneRender.clear()
    ambient.stop()
    fx.stop()
    SetNuiFocusKeepInput(false)
    SetNuiFocus(false, false)
end)

-- module redémarré en cours de partie
if core.characters.current() and not core.characters.awaitingSelection() then start() end
