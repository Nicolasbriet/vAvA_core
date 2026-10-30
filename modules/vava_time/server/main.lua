--[[
    vava_time/server/main.lua
    Rôle : déclaration du module auprès du core : état relu en base, date, heure et ciel publiés, intentions du client
           en RPC à schéma strict et à débit limité (heure du serveur pour tous ; vue et décisions de l'outil « Ciel et
           heure », droit du Conseil revérifié et journal), outil ajouté au Registre, boucle lente (fin d'un ciel,
           changement de jour ou de saison, nuits de gel). À l'arrêt, l'état partagé est retiré.
    Dépendances : tous les fichiers server/ du module
]]

local ipairs, pairs, tostring = ipairs, pairs, tostring
local time = os.time
local AddEventHandler, CreateThread, Wait, GlobalState = AddEventHandler, CreateThread, Wait, GlobalState

local core = VavaTime.core
if not core then return end

local bridge = VavaTime.bridge
local store = VavaTime.store
local clock = VavaTime.clock
local seasons = VavaTime.seasons
local sky = VavaTime.sky
local frost = VavaTime.frost
local council = VavaTime.council
local rules = VavaTime.weatherRules
local cfg = VavaTime.config
local limits = cfg.rateLimits
local RPC = VavaTime.RPC
local STATE = VavaTime.STATE
local DAY_MINUTES = VavaTime.DAY_MINUTES

local CLOCK_ACTION = { type = 'string', max = 16, enum = VavaTime.CLOCK_ACTIONS }
local CLOCK_VALUE = { type = 'integer', min = -DAY_MINUTES, max = DAY_MINUTES }
local WEATHER_ACTION = { type = 'string', max = 16, enum = VavaTime.WEATHER_ACTIONS }
local WEATHER_ID = { type = 'string', max = 24, enum = rules.ids(), optional = true }
local HOLD = { type = 'boolean', optional = true }

--- Handler réservé au droit du Conseil : refus 'forbidden' sinon.
---@param handler function
---@return function
local function guarded(handler)
    return function(src, ...)
        if not bridge.IsAllowed(src, cfg.council.permission) then return false, 'forbidden' end
        return handler(src, ...)
    end
end

--- Décision du Conseil depuis le jeu : inscrite au journal du Registre si elle a changé quelque chose.
---@param src integer
---@return boolean ok
---@return table|string view
local function decided(src, ok, view, label, details)
    if not ok then return false, view end
    if label then bridge.AdminLog(src, label, details) end
    return true, view
end

local function setup()
    local declared, declareErr = VavaTime.commands.declare()
    if not declared then return false, 'commandes : ' .. tostring(declareErr) end
    local row, err = store.load()
    if not row then return false, 'état : ' .. tostring(err) end
    local now = time()
    clock.load(row)
    seasons.refresh(now)
    sky.load(row, now, seasons.current().season)

    for _, def in ipairs({
        { RPC.SYNC, {}, limits.sync, function() return true, time() end },
        { RPC.OPEN, {}, limits.open, guarded(function() return true, council.view() end) },
        { RPC.CLOCK, { CLOCK_ACTION, CLOCK_VALUE }, limits.clock, guarded(function(src, action, value)
            return decided(src, council.clock(action, value, 'council'))
        end) },
        { RPC.WEATHER, { WEATHER_ACTION, WEATHER_ID, HOLD }, limits.weather, guarded(function(src, action, weather, hold)
            return decided(src, council.weather(action, weather, hold, 'council'))
        end) },
    }) do
        local ok, rpcErr = core.rpc.register(def[1], { args = def[2], rateLimit = def[3] }, def[4])
        if not ok then return false, def[1] .. ' : ' .. tostring(rpcErr) end
    end
    local adminOk, adminErr = bridge.StartAdmin()
    if not adminOk then return false, adminErr end

    VavaTime.ready = true
    -- nuit de gel du jour tirée tout de suite (ce qui est déjà passé aujourd'hui ne se rejoue pas), avant la première
    -- publication de la date qui dit si elle est annoncée
    frost.tick(seasons.current(), clock.seconds(now))
    clock.publish()
    seasons.publish()
    sky.publish()
    -- état écrit tel que repris (premier démarrage : la ligne est créée)
    store.save()
    CreateThread(function()
        while true do
            Wait(cfg.server.tickMs)
            local tick = time()
            seasons.refresh(tick)
            local date = seasons.current()
            sky.tick(tick, date.season)
            frost.tick(date, clock.seconds(tick))
            -- une seule écriture de la date pour le changement de jour et la nuit de gel du même passage
            seasons.flush()
        end
    end)
    return true
end

-- arrêt du module : plus d'état partagé (les clients rendent l'heure et le ciel au jeu)
AddEventHandler('onResourceStop', function(resource)
    if resource ~= VavaTime.resource or not VavaTime.ready then return end
    VavaTime.ready = false
    for _, key in pairs(STATE) do GlobalState[key] = nil end -- audit: ok (trois clés effacées à l'arrêt)
end)

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(VavaTime.resource, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    core.log.error('déclaration refusée : %s', tostring(registerErr))
end
