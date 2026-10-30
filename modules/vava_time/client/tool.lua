--[[
    vava_time/client/tool.lua
    Rôle : l'outil « Ciel et heure » du Conseil, ouvert depuis le Registre ou par /ciel, et les sous-commandes de /ciel.
           Le serveur accorde l'ouverture puis revérifie chaque décision ; le client ne fait que montrer et demander.
           Outil ouvert, un changement de l'état partagé (autre membre du Conseil, cycle) fait redemander la vue, au
           plus une fois par intervalle, et jamais juste après sa propre décision (déjà reçue avec la réponse).
    Dépendances : shared/, config.lua, client/core.lua, client/nui.lua
]]

local type, tostring, tonumber = type, tostring, tonumber
local tointeger = math.tointeger
local format = string.format
local CreateThread, SetTimeout, GetGameTimer = CreateThread, SetTimeout, GetGameTimer

local core = VavaTime.core
local nui = VavaTime.nui
local calendar = VavaTime.calendar
local rules = VavaTime.weatherRules
local cfg = VavaTime.config
local messages = cfg.messages
local RPC = VavaTime.RPC
-- un changement de l'état partagé à moins d'une seconde d'une vue reçue est celui de cette vue
local OWN_DECISION_MS = 1000

local tool = {}
VavaTime.tool = tool

local open, opening, queued = false, false, false
-- minuteur du jeu quand la dernière vue est arrivée
local lastView = 0
---@type fun(message: string, kind?: string)
local notify = function() end

---@param fn fun(message: string, kind?: string)
function tool.setNotifier(fn)
    notify = fn
end

---@return boolean
function tool.isOpen()
    return open
end

--- Texte d'un refus pour le joueur.
---@param code any
---@return string
local function errorText(code)
    return messages.errors[tostring(code)] or tostring(code)
end

--- Réponse d'un RPC pour l'interface : { ok, result } ou { ok = false, error }.
---@return table
local function answer(ok, success, result)
    if not ok then return { ok = false, error = tostring(success) } end
    if not success then return { ok = false, error = tostring(result) } end
    if type(result) == 'table' then lastView = GetGameTimer() end
    return { ok = true, result = result }
end

--- « 22 h 05 » d'une seconde du jour.
---@param seconds number
---@return string
local function hourText(seconds)
    local hour, minute = calendar.hms(seconds)
    return format(messages.hour, hour, minute)
end

function tool.close()
    if not open then return end
    open = false
    nui.send('close')
    nui.setFocus(false)
end

--- Demande l'ouverture au serveur (rien ne s'ouvre sans le droit du Conseil). Bloque le thread courant.
function tool.open()
    if open or opening or not nui.isReady() then return end
    opening = true
    local result = answer(core.rpc.call(RPC.OPEN))
    opening = false
    if not result.ok then
        notify(errorText(result.error), 'warning')
        return
    end
    if open then return end
    open = true
    nui.send('open', { view = result.result })
    nui.setFocus(true)
end

--- Vue redemandée au serveur (état partagé changé).
local function refresh()
    if not open then return end
    local result = answer(core.rpc.call(RPC.OPEN))
    if open and result.ok then nui.send('state', { view = result.result }) end
end

--- L'état partagé a changé : vue redemandée après l'intervalle, sauf si une vue est arrivée depuis, ou juste avant
--- (sa propre décision : l'état partagé arrive autour de la réponse du serveur, qui portait déjà la vue).
function tool.changed()
    if not open or queued then return end
    queued = true
    local queuedAt = GetGameTimer()
    SetTimeout(cfg.client.refreshMs, function()
        queued = false
        if open and lastView < queuedAt - OWN_DECISION_MS then CreateThread(refresh) end
    end)
end

--- Décision sur l'heure. Bloque le thread courant.
---@param action string
---@param value integer minutes
---@return table answer
function tool.clock(action, value)
    return answer(core.rpc.call(RPC.CLOCK, action, value))
end

--- Décision sur le ciel. Bloque le thread courant.
---@param action string
---@param weather string|nil
---@param hold boolean|nil
---@return table answer
function tool.weather(action, weather, hold)
    if action == 'impose' then return answer(core.rpc.call(RPC.WEATHER, action, weather, hold == true)) end
    return answer(core.rpc.call(RPC.WEATHER, action))
end

-- Sous-commandes de /ciel -----------------------------------------------------------------------------------------

---@param value any
---@return integer|nil
local function integer(value)
    return tointeger(tonumber(value))
end

local CLOCK_DONE = {
    set = messages.clockSet, shift = messages.clockSet, freeze = messages.clockFrozen, resume = messages.clockResumed,
    real = messages.clockReal,
}

--- Résultat d'une décision tapée : message au joueur, interface à jour si elle est ouverte.
---@param result table
---@param text fun(view: table): string
local function report(result, text)
    if not result.ok then
        notify(errorText(result.error), 'warning')
        return
    end
    notify(text(result.result), 'info')
    if open then nui.send('state', { view = result.result }) end
end

--- Ligne d'usage de /ciel, avec les noms de la config.
---@return string
local function usage()
    local commands = cfg.commands
    local names = commands.actions
    return format(messages.usage, commands.council, names.set, names.shift, names.freeze, names.resume, names.real,
        names.impose, commands.holdWord, names.hold, names.release)
end

--- /ciel <sous-commande> [arguments] ; noms des sous-commandes dans config.commands. Bloque le thread courant.
---@param args string[]
function tool.command(args)
    local names = cfg.commands.actions
    local sub = args[1]
    local action, value
    if sub == names.set then
        local hour, minute = integer(args[2]), integer(args[3] or 0)
        if hour and minute then action, value = 'set', hour * 60 + minute end
    elseif sub == names.shift then
        local hours = integer(args[2])
        if hours then action, value = 'shift', hours * 60 end
    elseif sub == names.freeze then
        action, value = 'freeze', 0
    elseif sub == names.resume then
        action, value = 'resume', 0
    elseif sub == names.real then
        action, value = 'real', 0
    end
    if action then
        report(tool.clock(action, value), function(view) return format(CLOCK_DONE[action], hourText(view.clock.seconds)) end)
        return
    end
    if sub == names.impose and args[2] then
        report(tool.weather('impose', args[2], args[3] == cfg.commands.holdWord), function(view)
            return format(view.weather.frozen and messages.weatherFrozen or messages.weatherImposed, view.weather.label)
        end)
    elseif sub == names.hold then
        report(tool.weather('freeze'), function(view) return format(messages.weatherFrozen, view.weather.label) end)
    elseif sub == names.release then
        report(tool.weather('release'), function() return messages.weatherReleased end)
    else
        notify(usage(), 'info')
    end
end

-- Interface -------------------------------------------------------------------------------------------------------

nui.on('close', function()
    tool.close()
    return { ok = true }
end)

nui.on('clock', function(data)
    if not open then return { ok = false, error = 'closed' } end
    local value = integer(data.value)
    if type(data.action) ~= 'string' or not value then return { ok = false, error = 'invalid_value' } end
    return tool.clock(data.action, value)
end)

nui.on('weather', function(data)
    if not open then return { ok = false, error = 'closed' } end
    if type(data.action) ~= 'string' then return { ok = false, error = 'invalid_value' } end
    local weather = type(data.weather) == 'string' and rules.get(data.weather) and data.weather or nil
    if data.action == 'impose' and not weather then return { ok = false, error = 'unknown_weather' } end
    return tool.weather(data.action, weather, data.hold == true)
end)
