--[[
    vava_arrival/client/main.lua
    Rôle : l'accueil côté joueur. Aucune boucle permanente : à la réception de l'accueil (envoyé par le serveur au seul
           nouveau venu), UN thread borné attend que l'écran soit calme (fondu fini, ni menu pause, ni interface qui a
           le focus ; essais espacés, 30 s au plus), montre le mot d'accueil et la ligne de la dotation en
           notifications du HUD, ouvre le Codex au chapitre de la config (ou rappelle sa touche), puis accuse lecture.
           Un nouvel accueil ou le retour à la sélection annule l'attente en cours. Le client ne décide de rien : il
           affiche, et l'accusé ne fait que retirer son propre accueil.
    Dépendances : shared/constants.lua, config.lua, shared/rules.lua, client/core.lua
]]

local type, pcall, tostring = type, pcall, tostring
local CreateThread, Wait, RegisterNetEvent, GetInvokingResource = CreateThread, Wait, RegisterNetEvent, GetInvokingResource
local GetGameTimer, GetResourceState = GetGameTimer, GetResourceState
local IsPauseMenuActive, IsNuiFocused, IsScreenFadedIn = IsPauseMenuActive, IsNuiFocused, IsScreenFadedIn
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaArrival.core
if not core then return end

local cfg = VavaArrival.config
local rules = VavaArrival.rules
local EVENTS = VavaArrival.EVENTS
local RPC = VavaArrival.RPC
local MAX_REPLY = VavaArrival.MAX_REPLY
local messages = cfg.messages

local FEED_TEXT = 'STRING'
local HUD, CODEX = 'vava_hud', 'vava_codex'

-- jeton de l'accueil en attente : un nouvel accueil ou le retour à la sélection l'invalide
local token = 0

local function hudNotify(message)
    return exports[HUD]:notify(message, 'info')
end

--- Notification de vava_hud, sinon celle du jeu (texte brut).
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

local function codexOpenAt(chapter)
    return exports[CODEX]:openAt(chapter)
end

--- Ouvre le Codex au chapitre de la config ; faux si le Codex est absent, occupé ou en erreur.
---@return boolean
local function openCodex()
    if GetResourceState(CODEX) ~= 'started' then return false end
    local called, ok, code = pcall(codexOpenAt, cfg.codex.chapter)
    if not called then
        core.log.warn('%s.openAt en erreur : %s', CODEX, tostring(ok))
        return false
    end
    if ok ~= true then core.log.debug('Codex non ouvert : %s', tostring(code)) end
    return ok == true
end

---@return boolean
local function screenReady()
    return rules.welcomeReady({ paused = IsPauseMenuActive(), nuiFocused = IsNuiFocused(), fadedIn = IsScreenFadedIn() })
end

--- Vrai tant que l'accueil `mine` est toujours le dernier reçu et que le personnage n'a pas changé.
---@param mine integer
---@param characterId integer
---@return boolean
local function stillMine(mine, characterId)
    if token ~= mine then return false end
    local current = core.characters.current()
    return current ~= nil and current.id == characterId
end

--- Attente bornée de l'écran, puis l'accueil et l'accusé. Thread unique par accueil reçu.
---@param mine integer
---@param characterId integer
---@param kitGiven boolean
local function show(mine, characterId, kitGiven)
    Wait(cfg.welcome.delayMs)
    local deadline = GetGameTimer() + cfg.welcome.maxWaitMs
    local ready = false
    while true do
        if not stillMine(mine, characterId) then return end
        if screenReady() then
            ready = true
            break
        end
        if GetGameTimer() >= deadline then break end
        Wait(cfg.welcome.retryMs)
    end
    feed(messages.welcome)
    if kitGiven then feed(messages.kit) end
    if not (ready and openCodex()) then feed(messages.codexHint) end
    core.rpc.call(RPC.WELCOMED)
end

RegisterNetEvent(EVENTS.WELCOME, function(kitGiven)
    -- déclenché localement par une ressource : ignoré (seul le serveur l'envoie)
    if GetInvokingResource() ~= nil or type(kitGiven) ~= 'boolean' then return end
    local character = core.characters.current()
    if not character then return end
    token = token + 1
    local mine, characterId = token, character.id
    CreateThread(function() show(mine, characterId, kitGiven) end)
end)

-- réponse de /accueil quand vava_chat manque (envoyée au seul membre du Conseil qui l'a tapée)
RegisterNetEvent(EVENTS.NOTIFY, function(message)
    if GetInvokingResource() ~= nil or type(message) ~= 'string' or #message == 0 or #message > MAX_REPLY then return end
    feed(message)
end)

core.hooks.after('core:character:unloaded', function()
    token = token + 1
end)
