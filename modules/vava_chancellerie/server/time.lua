--[[
    vava_chancellerie/server/time.lua
    Rôle : ciel et heure du royaume depuis la Chancellerie (vava_time) : lire l'état (droit `view` du Registre), régler
           l'heure ou le ciel (droit `tools`). Le droit du compte du panneau est vérifié auprès du Registre (webCan) ;
           vava_time revalide chaque valeur et rend le libellé et les détails que le Registre inscrit à son journal
           (webLog), au nom de « Chancellerie : <compte> ». Une décision qui ne change rien n'est pas inscrite.
    Dépendances : shared/constants.lua, server/core.lua, server/routes.lua
]]

local type, tostring = type, tostring

local call = VavaBridge.call
local requests = VavaBridge.routes.requests
local ADMIN = VavaBridge.ADMIN
local TIME = 'vava_time'
-- droits du Registre pour lire et pour régler le ciel et l'heure (ceux des zones de voix)
local READ, WRITE = 'view', 'tools'

local function failure(code)
    return { ok = false, error = tostring(code) }
end

--- Le rang de ce compte du panneau a-t-il ce droit ?
local function can(actor, permission)
    local called, allowed = call(ADMIN, 'webCan', actor, permission)
    return called and allowed == true
end

--- Décision transmise à vava_time, puis inscrite au journal du Registre si elle a changé quelque chose.
---@param actor table
---@param fn string webClock | webWeather
---@return table
local function decide(actor, fn, ...)
    if not can(actor, WRITE) then return failure('forbidden') end
    local called, ok, view, label, details = call(TIME, fn, ...)
    if not called then return failure('time_unavailable') end
    if not ok then return failure(view) end
    if type(label) == 'string' then call(ADMIN, 'webLog', actor, label, type(details) == 'table' and details or {}) end
    return { ok = true, result = view }
end

requests.time = function(actor)
    if not can(actor, READ) then return failure('forbidden') end
    local called, ok, view = call(TIME, 'webState')
    if not called then return failure('time_unavailable') end
    if not ok then return failure(view) end
    return { ok = true, result = view }
end

-- args : { action, minutes }
requests.timeClock = function(actor, args)
    return decide(actor, 'webClock', args[1], args[2])
end

-- args : { action, ciel?, figer? }
requests.timeWeather = function(actor, args)
    return decide(actor, 'webWeather', args[1], args[2], args[3])
end
