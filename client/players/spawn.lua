--[[
    client/players/spawn.lua
    Rôle : exécution des ordres d'apparition reçus du serveur (modèle, position) puis confirmation, et mise en
           attente (écran noir, joueur figé) tant qu'aucun personnage n'est chargé. Remplace spawnmanager.
    Écran de chargement (0.13.0) : à la première mise en attente, laissé à la ressource spawn.loadingScreen si elle
    tourne (elle le ferme quand la sélection est affichée, sans écran noir), fermé par le core au plus tard après
    maxHoldMs ; toujours fermé à l'apparition.
    Aucune boucle permanente : les seules attentes sont bornées et ne durent que le temps d'une apparition.
    Dépendances : shared/init.lua, config/shared.lua, shared/core/logger.lua, shared/core/hooks.lua, client/core/rpc.lua
]]

local type, tostring = type, tostring
local HUGE = math.huge
local CreateThread, Wait, GetGameTimer, RegisterNetEvent = CreateThread, Wait, GetGameTimer, RegisterNetEvent
local SetTimeout, GetResourceState = SetTimeout, GetResourceState
local PlayerId, PlayerPedId, NetworkIsPlayerActive = PlayerId, PlayerPedId, NetworkIsPlayerActive
local SetPlayerControl, SetEntityVisible, SetEntityCollision = SetPlayerControl, SetEntityVisible, SetEntityCollision
local FreezeEntityPosition, SetPlayerInvincible = FreezeEntityPosition, SetPlayerInvincible
local DoScreenFadeOut, DoScreenFadeIn, IsScreenFadedOut = DoScreenFadeOut, DoScreenFadeIn, IsScreenFadedOut
local ShutdownLoadingScreen, ShutdownLoadingScreenNui = ShutdownLoadingScreen, ShutdownLoadingScreenNui
local GetHashKey, IsModelInCdimage, IsModelValid, RequestModel, HasModelLoaded = GetHashKey, IsModelInCdimage, IsModelValid, RequestModel, HasModelLoaded
local SetPlayerModel, SetModelAsNoLongerNeeded, SetPedDefaultComponentVariation = SetPlayerModel, SetModelAsNoLongerNeeded, SetPedDefaultComponentVariation
local RequestCollisionAtCoord, SetEntityCoordsNoOffset, NetworkResurrectLocalPlayer = RequestCollisionAtCoord, SetEntityCoordsNoOffset, NetworkResurrectLocalPlayer
local SetEntityHeading, ClearPedTasksImmediately, HasCollisionLoadedAroundEntity = SetEntityHeading, ClearPedTasksImmediately, HasCollisionLoadedAroundEntity

local EVENTS = vAvA.EVENTS
local hooks = vAvA.hooks
local rpc = vAvA.rpc
local cfg = vAvA.config.shared.spawn
local log = vAvA.logger.create('spawn')

local CORE = vAvA.CORE_OWNER
local RPC_SPAWNED = vAvA.CHARACTER_RPC.SPAWNED
local HOOK_SELECTION = 'core:character:selection'
local HOOK_SPAWNING = 'core:character:spawning'

local spawn = {}
vAvA.spawn = spawn

-- Chaque ordre (apparition ou mise en attente) prend un nouveau jeton : un ordre plus récent annule le précédent.
local token = 0
-- vrai pendant l'attente de sélection (aucun personnage chargé, aucune apparition en cours)
local holding = false
-- vrai dès la première mise en attente : l'écran de chargement n'est laissé à sa ressource qu'à ce moment-là
local loadingScreenReleased = false

--- Vrai si le joueur attend de choisir un personnage (une interface démarrée en retard peut s'ouvrir).
---@return boolean
function spawn.isHolding()
    return holding
end

--- Fige le ped (immobile, invisible, invincible). Les contrôles ne sont coupés que pendant une apparition :
--- en attente de sélection, ils restent actifs pour le chat et l'interface de sélection.
---@param frozen boolean
---@param lockControls boolean
local function setFrozen(frozen, lockControls)
    local player, ped = PlayerId(), PlayerPedId()
    SetPlayerControl(player, not (frozen and lockControls), 0)
    SetEntityVisible(ped, not frozen, false)
    SetEntityCollision(ped, not frozen, true)
    FreezeEntityPosition(ped, frozen)
    SetPlayerInvincible(player, frozen)
end

--- Attente bornée d'une condition.
---@param predicate fun(): boolean
---@param timeoutMs number
---@return boolean reached
local function waitUntil(predicate, timeoutMs)
    local deadline = GetGameTimer() + timeoutMs
    while not predicate() do
        if GetGameTimer() > deadline then return false end
        Wait(cfg.pollMs)
    end
    return true
end

local function isSessionActive()
    return NetworkIsPlayerActive(PlayerId())
end

---@param model string
---@return integer|nil hash
local function loadModel(model)
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) or not IsModelValid(hash) then return nil end
    RequestModel(hash)
    if not waitUntil(function() return HasModelLoaded(hash) end, cfg.modelTimeoutMs) then return nil end
    return hash
end

--- Écran de chargement (NUI) à la mise en attente. La première fois, si la ressource de spawn.loadingScreen tourne,
--- elle le ferme elle-même quand la sélection est affichée (le fondu au noir se fait sous l'écran : aucun noir vu) ;
--- le core le ferme au plus tard maxHoldMs plus tard (sans effet s'il est déjà fermé). Sinon, fermé aussitôt.
local function releaseLoadingScreen()
    local first = not loadingScreenReleased
    loadingScreenReleased = true
    local screen = cfg.loadingScreen
    local resource, maxHoldMs = screen and screen.resource, screen and screen.maxHoldMs
    if first and type(resource) == 'string' and resource ~= '' and type(maxHoldMs) == 'number' and maxHoldMs > 0 then
        local state = GetResourceState(resource)
        if state == 'started' or state == 'starting' then
            SetTimeout(maxHoldMs, function() ShutdownLoadingScreenNui() end)
            return
        end
    end
    ShutdownLoadingScreenNui()
end

--- Écran noir et joueur figé : état de l'écran de sélection (aucun personnage chargé).
--- Le hook core:character:selection permet à une interface de prendre la main (caméra, écran de sélection).
local function hold()
    token = token + 1
    holding = true
    DoScreenFadeOut(cfg.fadeMs)
    setFrozen(true, false)
    ShutdownLoadingScreen()
    releaseLoadingScreen()
    hooks.runAfter(HOOK_SELECTION, {})
end

---@class vAvA.SpawnOrder
---@field model? string
---@field x number
---@field y number
---@field z number
---@field heading number

---@param order vAvA.SpawnOrder
local function perform(order)
    token = token + 1
    holding = false
    local myToken = token
    waitUntil(isSessionActive, HUGE)

    DoScreenFadeOut(cfg.fadeMs)
    waitUntil(IsScreenFadedOut, cfg.fadeMs * 4)
    setFrozen(true, true)

    if order.model then
        local hash = loadModel(order.model)
        if hash then
            SetPlayerModel(PlayerId(), hash)
            SetModelAsNoLongerNeeded(hash)
            SetPedDefaultComponentVariation(PlayerPedId())
        else
            log.error("modèle '%s' introuvable ou trop long à charger : modèle actuel conservé", tostring(order.model))
        end
    end
    if myToken ~= token then return end

    RequestCollisionAtCoord(order.x, order.y, order.z)
    SetEntityCoordsNoOffset(PlayerPedId(), order.x, order.y, order.z, false, false, false)
    NetworkResurrectLocalPlayer(order.x, order.y, order.z, order.heading, true, true, false)
    -- la résurrection peut changer le ped : on le relit
    local ped = PlayerPedId()
    SetEntityHeading(ped, order.heading)
    ClearPedTasksImmediately(ped)
    -- écran encore noir : les modules appliquent l'apparence avant que le joueur ne soit visible
    hooks.runAfter(HOOK_SPAWNING, { modelChanged = order.model ~= nil })
    waitUntil(function() return HasCollisionLoadedAroundEntity(ped) end, cfg.collisionTimeoutMs)
    if myToken ~= token then return end

    ShutdownLoadingScreen()
    ShutdownLoadingScreenNui()
    loadingScreenReleased = true
    setFrozen(false, false)
    DoScreenFadeIn(cfg.fadeMs)
    rpc.emit(RPC_SPAWNED)
end

---@param value any
---@return boolean
local function isNumber(value)
    return type(value) == 'number' and value == value
end

--- Branche les ordres du serveur et met le joueur en attente dès que sa session réseau est active.
--- Appelé par client/init.lua.
function spawn.start()
    RegisterNetEvent(EVENTS.SPAWN, function(order)
        if type(order) ~= 'table' or not (isNumber(order.x) and isNumber(order.y) and isNumber(order.z) and isNumber(order.heading)) then
            return
        end
        if order.model ~= nil and type(order.model) ~= 'string' then return end
        CreateThread(function() perform(order) end)
    end)

    hooks.subscribe(CORE, 'after', 'core:character:unloaded', hold)

    CreateThread(function()
        local startToken = token
        -- attente de démarrage, bornée par l'arrivée de la session : intervalle lent, pas de Wait(0)
        while not isSessionActive() do Wait(cfg.sessionPollMs) end
        -- une apparition reçue entre-temps a priorité
        if token == startToken then hold() end
    end)
end
