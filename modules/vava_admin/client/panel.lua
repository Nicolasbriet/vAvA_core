--[[
    vava_admin/client/panel.lua
    Rôle : le Registre du Conseil. Ouverture accordée par le serveur (rang, droits) ; chaque demande de l'interface
           est relayée telle quelle au serveur, qui revérifie tout (liste fermée de noms : l'interface ne peut appeler
           aucune autre RPC). Suites locales : outils appliqués après accord, observation (sa fin est annoncée au
           serveur), inventaire ouvert, outil d'un autre module ouvert (hook client vava_admin:toolOpened).
    Dépendances : shared/constants.lua, config.lua, client/core.lua, client/nui.lua, client/notify.lua, client/tools.lua
]]

local type, tostring, unpack = type, tostring, table.unpack

local core = VavaAdmin.core
local nui, notify, tools = VavaAdmin.nui, VavaAdmin.notify, VavaAdmin.tools
local PREFIX = VavaAdmin.PREFIX
local MAX_ARGS = 4

-- demandes de l'interface autorisées (le serveur vérifie le droit de chacune)
local ALLOWED = {
    players = true, player = true, reports = true, reportClaim = true, reportClose = true, bans = true, unban = true,
    logs = true, staff = true, staffSet = true, announce = true, reach = true, bring = true, sendBack = true,
    freeze = true, heal = true, feed = true, message = true, warn = true, kick = true, ban = true, inventory = true,
    give = true, spectate = true, tool = true, moduleTool = true,
}
-- après ces demandes, le panneau se ferme (le jeu prend la suite)
local CLOSES = { inventory = true, spectate = true, reach = true, moduleTool = true }

local panel = {}
VavaAdmin.panel = panel

local open = false

function panel.isOpen()
    return open
end

function panel.close()
    if not open then return end
    open = false
    nui.send('close')
    nui.setFocus(false)
end

--- Demande l'ouverture au serveur (rien ne se passe pour qui ne siège pas au Conseil).
function panel.open()
    if open or not nui.isReady() then return end
    local ok, success, data = core.rpc.call(PREFIX .. 'open')
    if not ok or not success or type(data) ~= 'table' then return end
    data.tools = tools.state()
    data.noclipKey = VavaAdmin.config.keys.noclip
    open = true
    nui.send('open', data)
    nui.setFocus(true)
end

---@param name string
---@param result any
local function after(name, args, result)
    if name == 'tool' then
        if args[1] == 'waypoint' then
            if not tools.waypoint() then return { ok = false, error = 'no_waypoint' } end
        else
            tools.set(args[1], args[2] == true)
        end
        return { ok = true, result = tools.state() }
    end
    if name == 'spectate' and type(result) == 'table' then
        tools.spectate(result, function()
            nui.send('spectate', { active = false })
            -- revenu à sa place : le serveur n'a plus à garder celle d'avant l'observation (server/spectate.lua)
            core.rpc.emit(PREFIX .. 'spectateEnd')
        end)
        nui.send('spectate', { active = true, label = result.label, key = VavaAdmin.config.keys.open })
    end
    if CLOSES[name] then panel.close() end
    -- outil d'un module : le module prend la main (il revérifie chaque action côté serveur)
    if name == 'moduleTool' then core.hooks.runAfter(VavaAdmin.HOOKS.TOOL_OPENED, { key = args[1] }) end
    return { ok = true, result = result }
end

nui.on('request', function(data)
    local name, args = data.name, data.args
    if type(name) ~= 'string' or not ALLOWED[name] then return { ok = false, error = 'invalid_request' } end
    if type(args) ~= 'table' then args = {} end
    if #args > MAX_ARGS then return { ok = false, error = 'invalid_request' } end
    local ok, success, result = core.rpc.call(PREFIX .. name, unpack(args, 1, #args))
    if not ok then return { ok = false, error = tostring(success) } end
    if not success then return { ok = false, error = tostring(result) } end
    return after(name, args, result)
end)

nui.on('close', function()
    panel.close()
    return { ok = true }
end)

nui.on('stopSpectate', function()
    tools.stopSpectate()
    return { ok = true }
end)

--- Message à l'écran depuis l'interface (copie des coordonnées…).
nui.on('notify', function(data)
    if type(data.text) == 'string' then notify.show(data.text, 'info') end
    return { ok = true }
end)
