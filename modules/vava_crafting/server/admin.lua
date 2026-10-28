--[[
    vava_crafting/server/admin.lua
    Rôle : commande du Conseil `/artisanat` (droit `metiers`) : état des stations, d'une station (combustible,
           occupant, recettes), combustible fixé. Inscrit au journal du module et au Registre du Conseil.
    Dépendances : config.lua, server/core.lua, bridge/server.lua, server/journal.lua, server/catalog.lua,
                  server/stations.lua
]]

local ipairs, tonumber = ipairs, tonumber
local tointeger = math.tointeger
local format = string.format
local RegisterCommand, CreateThread = RegisterCommand, CreateThread

local bridge = VavaCrafting.bridge
local journal = VavaCrafting.journal
local catalog = VavaCrafting.catalog
local stations = VavaCrafting.stations
local cfg = VavaCrafting.config.admin

local admin = {}
VavaCrafting.admin = admin

---@param source integer
---@param def vAvA.StationDefinition
local function describe(source, def)
    local view = stations.view(def)
    local fuel = view.fuel and format(', combustible %d / %d', view.fuel.stock, view.fuel.capacity) or ''
    local owner = view.owner and format(', privée (%s n° %d)', view.owner.kind, view.owner.id) or ', publique'
    bridge.Chat(source, format('%s (%s, %s) — qualité %d%s%s%s', view.label, view.id, view.typeLabel, view.quality, fuel, owner, view.busy and ', occupée' or ''))
end

local function usage(source)
    bridge.Chat(source, format('usage : /%s stations | station <id> | carburant <id> <n>', cfg.command))
end

---@param source integer
---@param args string[]
local function command(source, args)
    if not bridge.IsAllowed(source, cfg.permission) then return end
    local action = args[1]
    CreateThread(function()
        if action == 'stations' then
            for _, def in ipairs(catalog.stations()) do describe(source, def) end
        elseif action == 'station' then
            local def = catalog.station(args[2])
            if not def then return usage(source) end
            describe(source, def)
            for _, recipe in ipairs(catalog.recipesOf(def.type.id)) do
                bridge.Chat(source, format('  %s : %s niveau %d%s%s', recipe.id, recipe.label, recipe.level,
                    recipe.transmission and ', transmise' or '', recipe.signed and ', signée' or ''))
            end
        elseif action == 'carburant' then
            local def = catalog.station(args[2])
            local amount = tointeger(tonumber(args[3]))
            if not def or not amount or amount < 0 then return usage(source) end
            if not def.type.fuel then return bridge.Chat(source, 'cette station ne brûle rien.') end
            stations.setFuel(def, amount)
            journal.write('admin_fuel', { station = def.id, accountId = bridge.GetAccountId(source), details = { fuel = stations.fuel(def) } })
            bridge.AdminLog(source, 'Combustible fixé', { station = def.id, combustible = stations.fuel(def) })
            bridge.Chat(source, format('%s : combustible %d / %d.', def.label, stations.fuel(def), def.type.fuel.capacity))
        else
            usage(source)
        end
    end)
end

--- Enregistre la commande. Appelé pendant le setup du module.
function admin.start()
    RegisterCommand(cfg.command, command, false)
end
