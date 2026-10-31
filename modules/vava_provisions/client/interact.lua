--[[
    vava_provisions/client/interact.lua
    Rôle : le point d'eau côté joueur. Invite pour le point le plus proche à portée d'usage (cachée à terre, pendant une
           demande ou un geste, sans personnage). Appui sur la touche : le point désigné est envoyé au serveur (RPC
           vava_provisions:draw), qui décide tout ; puis geste local (puiser ou boire, durée de la config, aucune boucle
           par image) et notification du résultat, ou du refus, formée d'après la config (shared/rules.lua). Le client ne
           décide de rien.
    Dépendances : shared/constants.lua, config_client.lua, shared/rules.lua, client/core.lua, client/nui.lua, client/points.lua
]]

local type, tostring, pcall = type, tostring, pcall
local CreateThread, Wait, GetGameTimer, AddEventHandler = CreateThread, Wait, GetGameTimer, AddEventHandler
local PlayerPedId, GetResourceState = PlayerPedId, GetResourceState
local TaskStartScenarioInPlace, TaskPlayAnim, ClearPedTasks = TaskStartScenarioInPlace, TaskPlayAnim, ClearPedTasks
local RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict = RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict

local core = VavaProvisions.core
if not core then return end

local cfg = VavaProvisions.config
local rules = VavaProvisions.rules
local nui = VavaProvisions.nui
local points = VavaProvisions.points
local RPC = VavaProvisions.RPC
local messages = cfg.messages

local HEALTH = 'vava_health'
local ANIM_LOAD_MS = 5000
local ANIM_POLL_MS = 50
local ANIM_BLEND = 8.0

local interact = {}
VavaProvisions.interact = interact

-- une demande au serveur en cours, ou un geste joué : ni invite ni nouvel appui
local pending, acting = false, false
---@type fun(message: string, kind?: string)|nil
local notify = nil

local function healthState()
    return exports[HEALTH]:get()
end

--- Le joueur local est-il à terre ? (export client de vava_health, lu à l'appui et à l'invite, donc au rythme de la
--- boucle des points et seulement près d'un point d'eau) Module absent ou en erreur : pas à terre. Le serveur refuse
--- de toute façon.
---@return boolean
local function isDowned()
    if GetResourceState(HEALTH) ~= 'started' then return false end
    local called, health = pcall(healthState)
    return called and type(health) == 'table' and health.downed == true
end

--- Invite pour le point le plus proche (ou rien) ; envoyée à la page seulement si elle change (client/nui.lua).
---@param pointId string|nil
function interact.refreshPrompt(pointId)
    local point = pointId and points.point(pointId) or nil
    if not point or pending or acting or not core.characters.current() or isDowned() then
        nui.hidePrompt()
        return
    end
    nui.showPrompt(cfg.keys.interact, rules.promptVerb(cfg.kinds[point.kind], messages.prompt), point.label)
end

--- Joue le geste de l'action (scénario, ou animation du haut du corps) pendant sa durée, puis l'arrête. Bloque le
--- thread appelant (son propre thread).
---@param action string
local function gesture(action)
    local anim = cfg.anims[action]
    if not anim then return end
    local ped = PlayerPedId()
    local dict = nil
    if anim.scenario then
        TaskStartScenarioInPlace(ped, anim.scenario, 0, true)
    elseif anim.dict then
        if not HasAnimDictLoaded(anim.dict) then
            RequestAnimDict(anim.dict)
            local deadline = GetGameTimer() + ANIM_LOAD_MS
            while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < deadline do Wait(ANIM_POLL_MS) end
        end
        if HasAnimDictLoaded(anim.dict) then
            dict = anim.dict
            TaskPlayAnim(ped, anim.dict, anim.clip, ANIM_BLEND, -ANIM_BLEND, -1, anim.flag or 49, 0.0, false, false, false)
        end
    end
    Wait(anim.durationMs or 2500)
    ClearPedTasks(PlayerPedId())
    if dict then RemoveAnimDict(dict) end
end

--- Demande au serveur, puis geste et notification. Dans son propre thread.
---@param pointId string
local function request(pointId)
    local point = points.point(pointId)
    local kind = point and cfg.kinds[point.kind] or nil
    local ok, success, result, extra = core.rpc.call(RPC.DRAW, pointId)
    pending = false
    if not ok then
        -- erreur de transport (débit, délai, serveur) : le joueur réessaiera
        if notify then notify(messages.unavailable, 'warning') end
        interact.refreshPrompt(points.nearest())
        return
    end
    if not success then
        local text = rules.refusalText(result, extra, kind, messages)
        if text and notify then notify(text, 'warning') end
        interact.refreshPrompt(points.nearest())
        return
    end
    local text = rules.successText(result, messages)
    if type(result) == 'table' and (result.action == 'fill' or result.action == 'drink') and core.characters.current() then
        acting = true
        interact.refreshPrompt(nil)
        if text and notify then notify(text, 'info') end
        gesture(result.action)
        acting = false
    elseif text and notify then
        notify(text, 'info')
    end
    interact.refreshPrompt(points.nearest())
end

--- Appui sur la touche : rien sans personnage, à terre, pendant une demande ou un geste, ou sans point à portée.
function interact.press()
    if pending or acting or not core.characters.current() or isDowned() then return end
    local pointId = points.nearest()
    if not pointId or not points.point(pointId) then return end
    pending = true
    interact.refreshPrompt(nil)
    CreateThread(function()
        local called, err = pcall(request, pointId)
        if not called then
            pending, acting = false, false
            core.log.error('puisage en erreur : %s', tostring(err))
        end
    end)
end

--- Fonction d'affichage des messages (vava_hud, sinon le jeu), fournie par client/main.lua.
---@param fn fun(message: string, kind?: string)
function interact.setNotify(fn)
    notify = fn
end

--- Tout fermer (déchargement, sélection) : l'invite disparaît.
function interact.reset()
    nui.hidePrompt()
end

-- arrêt du module pendant un geste : le ped ne reste pas figé dans le scénario ou l'animation
AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaProvisions.resource or not acting then return end
    acting = false
    ClearPedTasks(PlayerPedId())
end)

points.onNearest(interact.refreshPrompt)
