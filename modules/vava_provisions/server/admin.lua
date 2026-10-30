--[[
    vava_provisions/server/admin.lua
    Rôle : commande du Conseil `/eau` (droit `metiers` de vava_admin, repli ACE ; console permise) : état des points
           d'eau et de leurs réserves (lecture seule, lignes regroupées en messages courts), réserve d'un puits ou d'une
           source fixée (journal du Registre, ancienne et nouvelle réserve).
           Sans droit : rien, aucune réponse. Délai entre deux commandes d'un même membre (console exceptée). La
           réponse va au seul membre qui a tapé la commande (ou à la console).
    Dépendances : shared/constants.lua, config.lua, shared/rules.lua, server/core.lua, bridge/server.lua,
                  server/points.lua
]]

local ipairs = ipairs
local format = string.format
local RegisterCommand = RegisterCommand

local bridge = VavaProvisions.bridge
local rules = VavaProvisions.rules
local points = VavaProvisions.points
local cfg = VavaProvisions.config
local settings = cfg.admin
local messages = cfg.messages.admin
local labels = cfg.messages.journal
local CONSOLE = bridge.CONSOLE

local admin = {}
VavaProvisions.admin = admin

-- membre du Conseil → horloge de sa dernière commande (GetGameTimer)
local lastUse = {}

--- /eau points : une ligne par point, dans l'ordre de la config, regroupées en messages de `replyBytes` octets au plus
--- (`listMax` points au plus, puis « … et N autres »).
---@param source integer
local function list(source)
    local now = bridge.Now()
    local lines = {}
    for _, point in ipairs(points.list()) do
        lines[#lines + 1] = rules.describePoint(point, points.reserve(point, now), messages)
    end
    for _, text in ipairs(rules.packLines(lines, settings.replyBytes, settings.listMax, messages.more)) do
        bridge.Chat(source, text)
    end
end

--- /eau reserve <point> <nombre> : réserve fixée, journal du Registre.
---@param source integer
---@param id string
---@param amount integer
local function setReserve(source, id, amount)
    local point = points.get(id)
    if not point then return bridge.Chat(source, format(messages.unknown, id)) end
    local capacity = cfg.kinds[point.kind].reserve.capacity
    if capacity == 0 then return bridge.Chat(source, format(messages.noReserve, point.label)) end
    if amount < 0 or amount > capacity then return bridge.Chat(source, format(messages.range, point.label, capacity)) end
    local now = bridge.Now()
    local previous = points.reserve(point, now).level
    points.setReserve(point, amount, now)
    bridge.AdminLog(source, labels.reserve, { point = point.id, reserve = amount, before = previous })
    bridge.Chat(source, format(messages.set, point.label, amount, capacity))
end

--- Commande /eau (jeu ou console). Sans droit : rien, aucune réponse.
---@param source integer
---@param args string[]
function admin.command(source, args)
    if not bridge.IsAllowed(source, settings.permission) then return end
    if source ~= CONSOLE then
        local now = bridge.Timer()
        local last = lastUse[source]
        if last and now - last < settings.cooldownMs then return bridge.Chat(source, messages.wait) end
        lastUse[source] = now
    end
    local action, id, amount = rules.parseCommand(args)
    if action == 'points' then return list(source) end
    if action == 'reserve' then return setReserve(source, id, amount) end
    bridge.Chat(source, format(messages.usage, settings.command))
end

--- Joueur parti : son délai est oublié.
---@param source integer
function admin.forget(source)
    lastUse[source] = nil
end

--- Enregistre la commande. Appelé pendant le setup du module.
function admin.start()
    RegisterCommand(settings.command, admin.command, false)
end
