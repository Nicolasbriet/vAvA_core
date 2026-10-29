--[[
    vava_gathering/server/admin.lua
    Rôle : commande du Conseil `/recolte` (droit `metiers`) : état des zones, d'une zone, d'un nœud ; vitalité fixée ;
           nœud rechargé. Chaque action est inscrite au journal du module et au Registre du Conseil.
    Dépendances : config.lua, server/core.lua, bridge/server.lua, server/journal.lua, server/catalog.lua,
                  server/zones.lua, server/nodes.lua
]]

local ipairs, tonumber = ipairs, tonumber
local format = string.format
local RegisterCommand, CreateThread = RegisterCommand, CreateThread

local bridge = VavaGathering.bridge
local journal = VavaGathering.journal
local catalog = VavaGathering.catalog
local zones = VavaGathering.zones
local nodes = VavaGathering.nodes
local cfg = VavaGathering.config.admin

local admin = {}
VavaGathering.admin = admin

---@param source integer
---@param view table
local function describeZone(source, view)
    bridge.Chat(source, format('%s (%s) — vitalité %d %%, %s%s, %d nœud(s)', view.label, view.id, view.vitality, view.band,
        view.scarred and ', cicatrice' or '', #catalog.nodesOf(view.id)))
end

local function usage(source)
    bridge.Chat(source, format('usage : /%s zones | zone <id> | noeud <id> | vitalite <zone> <0-100> | recharger <noeud>', cfg.command))
end

---@param source integer
---@param args string[]
local function command(source, args)
    if not bridge.IsAllowed(source, cfg.permission) then return end
    local action = args[1]
    CreateThread(function()
        if action == 'zones' then
            for _, def in ipairs(catalog.zones()) do describeZone(source, zones.view(def)) end
        elseif action == 'zone' then
            local def = catalog.zone(args[2])
            if not def then return usage(source) end
            describeZone(source, zones.view(def))
            for _, node in ipairs(catalog.nodesOf(def.id)) do
                local view = nodes.view(node)
                bridge.Chat(source, format('  %s : %s, %d / %d charge(s)', node.id, node.resource.label, view.charges, view.max))
            end
        elseif action == 'noeud' then
            local def = catalog.node(args[2])
            if not def then return usage(source) end
            local view = nodes.view(def)
            bridge.Chat(source, format('%s : %s (%s), %d / %d charge(s)', def.id, def.resource.label, def.zone.label, view.charges, view.max))
        elseif action == 'vitalite' then
            local def = catalog.zone(args[2])
            local value = tonumber(args[3])
            if not def or not value or value < 0 or value > 100 then return usage(source) end
            zones.setVitality(def, value, { source = source, accountId = bridge.GetAccountId(source) })
            bridge.AdminLog(source, 'Vitalité fixée', { zone = def.id, vitalite = value })
            bridge.Chat(source, format('%s : vitalité %g %%.', def.label, value))
        elseif action == 'recharger' then
            local def = catalog.node(args[2])
            if not def then return usage(source) end
            nodes.recharge(def)
            journal.write('admin_recharge', { zone = def.zone.id, node = def.id, accountId = bridge.GetAccountId(source) })
            bridge.AdminLog(source, 'Nœud rechargé', { noeud = def.id })
            bridge.Chat(source, format('%s rechargé (%d charges).', def.id, def.charges))
        else
            usage(source)
        end
    end)
end

--- Enregistre la commande. Appelé pendant le setup du module.
function admin.start()
    RegisterCommand(cfg.command, command, false)
end
