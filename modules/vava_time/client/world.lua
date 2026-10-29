--[[
    vava_time/client/world.lua
    Rôle : l'heure et le ciel du royaume appliqués au jeu de ce joueur, sans boucle par image.
      - Heure du serveur (secondes UTC) demandée à l'arrivée puis toutes les 30 min ; entre deux, le minuteur du jeu.
      - Horloge : une minute du jeu dure une minute réelle (le jeu fait avancer l'heure seul) ; recalée à l'arrivée, à
        chaque décision du Conseil et par le recalage lent de client/main.lua ; mise en pause si l'heure est figée.
      - Ciel : transition douce vers le ciel visé dans le temps qui reste (un joueur qui arrive pendant une transition
        part du ciel d'avant), puis ciel posé une fois la transition finie (un seul thread qui attend).
      - Arrêt de la ressource : horloge et météo rendues au jeu.
    Dépendances : shared/, config.lua, client/core.lua
]]

local type, floor, min = type, math.floor, math.min
local GetGameTimer, CreateThread, Wait, GlobalState = GetGameTimer, CreateThread, Wait, GlobalState
local NetworkOverrideClockMillisecondsPerGameMinute, NetworkOverrideClockTime, NetworkClearClockTimeOverride, PauseClock =
    NetworkOverrideClockMillisecondsPerGameMinute, NetworkOverrideClockTime, NetworkClearClockTimeOverride, PauseClock
local ClearOverrideWeather, ClearWeatherTypePersist, SetWeatherTypePersist, SetWeatherTypeNow, SetWeatherTypeNowPersist =
    ClearOverrideWeather, ClearWeatherTypePersist, SetWeatherTypePersist, SetWeatherTypeNow, SetWeatherTypeNowPersist
local SetWeatherTypeOvertimePersist, SetForceVehicleTrails, SetForcePedFootstepsTracks =
    SetWeatherTypeOvertimePersist, SetForceVehicleTrails, SetForcePedFootstepsTracks
-- absente des anciennes versions du jeu : appelée seulement si elle existe
local SetWeatherOwnedByNetwork = SetWeatherOwnedByNetwork

local core = VavaTime.core
local calendar = VavaTime.calendar
local rules = VavaTime.weatherRules
local cfg = VavaTime.config
local STATE = VavaTime.STATE
local RPC = VavaTime.RPC
local MS_PER_MINUTE = cfg.clock.msPerGameMinute
-- valeur du jeu sans réglage : une minute du jeu toutes les 2 s
local GAME_MS_PER_MINUTE = 2000
-- marge avant de poser le ciel à la fin d'une transition
local SETTLE_MARGIN_MS = 500

local world = {}
VavaTime.world = world

-- heure UTC du serveur et minuteur du jeu au moment où elle est arrivée
local epoch, epochAt = nil, nil
local syncing = false
-- ciel posé ou visé chez ce joueur ; numéro de la dernière application (une transition dépassée ne pose rien)
local applied = nil
local weatherToken = 0

--- Heure UTC du serveur estimée (secondes, décimale), ou nil avant la première réponse.
---@return number|nil
function world.now()
    if not epoch then return nil end
    return epoch + (GetGameTimer() - epochAt) / 1000
end

--- Demande l'heure du serveur. Bloque le thread courant.
---@return boolean
function world.sync()
    local ok, success, now = core.rpc.call(RPC.SYNC)
    if ok and success and type(now) == 'number' and now == now then
        epoch, epochAt = now, GetGameTimer()
        return true
    end
    return false
end

--- Recale l'horloge du jeu sur l'heure du royaume. Sans état ou sans heure du serveur : rien.
---@param state? table GlobalState vava_time:clock
---@return boolean applied
function world.applyClock(state)
    if state == nil then state = GlobalState[STATE.CLOCK] end
    local now = world.now()
    if type(state) ~= 'table' or not now then return false end
    local hour, minute, second = calendar.hms(calendar.clock(now, state))
    NetworkOverrideClockMillisecondsPerGameMinute(MS_PER_MINUTE)
    NetworkOverrideClockTime(hour, minute, second)
    PauseClock(state.frozen and true or false)
    return true
end

--- Pose un ciel tout de suite et le garde ; traces dans la neige au sol.
---@param def table
local function settle(def)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    SetWeatherTypePersist(def.gta)
    SetWeatherTypeNow(def.gta)
    SetWeatherTypeNowPersist(def.gta)
    local tracks = def.tracks == true
    SetForceVehicleTrails(tracks)
    SetForcePedFootstepsTracks(tracks)
    applied = def.id
end

--- Applique le ciel publié : posé s'il n'y a plus de transition, sinon transition dans le temps qui reste.
---@param state? table GlobalState vava_time:weather
function world.applyWeather(state)
    if state == nil then state = GlobalState[STATE.WEATHER] end
    if type(state) ~= 'table' then return end
    local target = rules.get(state.id)
    if not target then return end
    weatherToken = weatherToken + 1
    local token = weatherToken
    if SetWeatherOwnedByNetwork then SetWeatherOwnedByNetwork(false) end
    local now = world.now()
    local fade = type(state.fade) == 'number' and state.fade or 0
    local progress = (now and type(state.at) == 'number') and rules.progress(state.at, fade, now) or 1
    if progress >= 1 then
        settle(target)
        return
    end
    -- arrivé pendant la transition, ou ciel d'avant jamais posé ici : on part du ciel d'avant
    local from = rules.get(state.from)
    if from and applied ~= from.id and applied ~= target.id then
        ClearOverrideWeather()
        ClearWeatherTypePersist()
        SetWeatherTypeNowPersist(from.gta)
    end
    applied = target.id
    local remaining = fade * (1 - progress)
    SetWeatherTypeOvertimePersist(target.gta, remaining + 0.0)
    CreateThread(function()
        Wait(floor(remaining * 1000) + SETTLE_MARGIN_MS)
        if token == weatherToken then settle(target) end
    end)
end

--- Première application : heure du serveur demandée, ciel posé aussitôt (transition en cours reprise si l'heure est
--- connue, sinon ciel visé sans transition), horloge recalée dès que l'heure arrive (essais espacés tant que le module
--- serveur n'est pas prêt).
function world.start()
    if syncing then return end
    syncing = true
    CreateThread(function()
        local synced = world.sync()
        world.applyWeather()
        local delays = cfg.client.retryMs
        local attempt = 0
        while not synced do
            attempt = attempt + 1
            Wait(delays[min(attempt, #delays)])
            synced = world.sync()
        end
        syncing = false
        world.applyClock()
    end)
end

--- Heure du serveur redemandée quand la dernière réponse est trop ancienne (appelé par le recalage lent).
function world.maybeResync()
    if syncing or not epochAt or GetGameTimer() - epochAt < cfg.client.epochResyncMs then return end
    syncing = true
    CreateThread(function()
        world.sync()
        syncing = false
    end)
end

--- Horloge et météo rendues au jeu (arrêt de la ressource).
function world.restore()
    weatherToken = weatherToken + 1
    NetworkClearClockTimeOverride()
    PauseClock(false)
    NetworkOverrideClockMillisecondsPerGameMinute(GAME_MS_PER_MINUTE)
    ClearOverrideWeather()
    ClearWeatherTypePersist()
    if SetWeatherOwnedByNetwork then SetWeatherOwnedByNetwork(true) end
    SetForceVehicleTrails(false)
    SetForcePedFootstepsTracks(false)
end
