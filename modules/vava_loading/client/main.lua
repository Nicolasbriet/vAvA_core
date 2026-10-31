--[[
    vava_loading/client/main.lua
    Rôle : cycle de l'écran de chargement, une seule fois par vie du script :
      loading → waiting (hook core:character:selection) → handoff (écran de sélection affiché) → closed
    Trois messages locaux à la page (SendLoadingScreenMessage) : resources, waiting, handoff { ms } ; à la fin de
    l'éclair, ShutdownLoadingScreenNui. Filets : passage forcé selectionFallbackMs après la mise en attente, fermeture
    immédiate au chargement d'un personnage ou à l'arrêt de la ressource ; sans API du core, fermeture à l'arrivée de
    la session. Aucune boucle permanente : des SetTimeout, et un seul fil borné dans le cas « sans core ».
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua
]]

local CreateThread, Wait, SetTimeout, AddEventHandler = CreateThread, Wait, SetTimeout, AddEventHandler
local PlayerId, NetworkIsPlayerActive = PlayerId, NetworkIsPlayerActive
local SendLoadingScreenMessage, ShutdownLoadingScreenNui = SendLoadingScreenMessage, ShutdownLoadingScreenNui
local encode = json.encode

local loading = VavaLoading
local cfg = VavaLoading.config
local core = loading.core
local MESSAGES, HOOKS = loading.MESSAGES, loading.HOOKS

local HANDOFF_MS = loading.clamp(cfg.handoffMs, loading.HANDOFF_MIN_MS, loading.HANDOFF_MAX_MS, 1800)

---@alias LoadingState 'loading'|'waiting'|'handoff'|'closed'
---@type LoadingState
local state = 'loading'

---@param message table
local function send(message)
    SendLoadingScreenMessage(encode(message))
end

local function close()
    if state == 'closed' then return end
    state = 'closed'
    ShutdownLoadingScreenNui()
end

--- Sélection affichée (ou filet) : la page joue l'éclair, l'écran se ferme à sa fin.
local function handoff()
    if state ~= 'loading' and state ~= 'waiting' then return end
    state = 'handoff'
    send({ eventName = MESSAGES.HANDOFF, ms = HANDOFF_MS })
    SetTimeout(HANDOFF_MS, close)
end

--- Session ouverte, sélection en préparation : dernier feu ; passage forcé si la sélection ne se signale jamais.
local function waiting()
    if state ~= 'loading' then return end
    state = 'waiting'
    send({ eventName = MESSAGES.WAITING })
    SetTimeout(cfg.selectionFallbackMs, handoff)
end

-- Arrêt de la ressource pendant le chargement : l'écran ne doit pas lui survivre.
AddEventHandler('onClientResourceStop', function(resource)
    if resource ~= loading.resource or state == 'closed' then return end
    state = 'closed'
    ShutdownLoadingScreenNui()
end)

if not core then
    -- sans core, personne ne prépare de sélection : on ferme dès que la session est là (attente bornée par elle)
    CreateThread(function()
        while state ~= 'closed' and not NetworkIsPlayerActive(PlayerId()) do Wait(cfg.noCorePollMs) end
        close()
    end)
    return
end

-- ressource redémarrée en jeu : l'écran de chargement n'est plus là, rien à faire (retour à la sélection compris)
if core.characters.current() then
    state = 'closed'
    return
end

send({ eventName = MESSAGES.RESOURCES })

core.hooks.after(HOOKS.SELECTION, waiting)
core.hooks.after(HOOKS.LOADED, close)
core.hooks.after(cfg.selection.shownHook, handoff)

-- script démarré après la mise en attente (hook déjà passé) : on rattrape, puis l'export dit si la sélection est déjà
-- à l'écran
if core.characters.awaitingSelection() then
    waiting()
    if loading.selectionShown() then handoff() end
end
