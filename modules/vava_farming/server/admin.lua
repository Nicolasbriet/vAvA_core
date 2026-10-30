--[[
    vava_farming/server/admin.lua
    Rôle : commande du Conseil `/agriculture` (droit `metiers`) : état des parcelles, d'une parcelle (emplacements),
           fertilité fixée, emplacement mûri, parcelle arrosée. Inscrit au journal du module et au Registre.
    Dépendances : config.lua, server/core.lua, bridge/server.lua, server/journal.lua, server/catalog.lua,
                  server/slots.lua
]]

local ipairs, tonumber = ipairs, tonumber
local tointeger, floor = math.tointeger, math.floor
local format = string.format
local RegisterCommand, CreateThread = RegisterCommand, CreateThread

local bridge = VavaFarming.bridge
local journal = VavaFarming.journal
local catalog = VavaFarming.catalog
local slots = VavaFarming.slots
local cfg = VavaFarming.config.admin

local admin = {}
VavaFarming.admin = admin

---@param source integer
---@param parcel vAvA.ParcelDefinition
local function describe(source, parcel)
    local planted = 0
    for index = 1, parcel.count do
        if slots.get(parcel, index).crop then planted = planted + 1 end
    end
    bridge.Chat(source, format('%s (%s) — %d emplacement(s), %d planté(s)%s%s', parcel.label, parcel.id, parcel.count, planted,
        parcel.owner and format(', privée (%s n° %d)', parcel.owner.kind, parcel.owner.id) or ', communale', parcel.granary and ', grenier' or ''))
end

local function usage(source)
    bridge.Chat(source, format('usage : /%s parcelles | parcelle <id> | fertilite <id> <n> <0-100> | pousser <id> <n> | arroser <id>', cfg.command))
end

---@param source integer
---@param args string[]
local function command(source, args)
    if not bridge.IsAllowed(source, cfg.permission) then return end
    local action = args[1]
    CreateThread(function()
        local accountId = bridge.GetAccountId(source)
        if action == 'parcelles' then
            for _, parcel in ipairs(catalog.parcels()) do describe(source, parcel) end
        elseif action == 'parcelle' then
            local parcel = catalog.parcel(args[2])
            if not parcel then return usage(source) end
            describe(source, parcel)
            for index = 1, parcel.count do
                local view = slots.view(parcel, index)
                bridge.Chat(source, format('  %d : %s%s, humidité %d %%, fertilité %d %%%s', index, view.cropLabel or 'libre',
                    view.state and (' (' .. view.state .. ', ' .. floor(view.progress * 100 + 0.5) .. ' %)') or '', view.moisture, view.fertility,
                    view.covered and ', couverte' or (view.frostHardy and ', résiste au gel' or '')))
            end
        elseif action == 'fertilite' then
            local parcel = catalog.parcel(args[2])
            local index = tointeger(tonumber(args[3]))
            local value = tonumber(args[4])
            if not parcel or not index or index < 1 or index > parcel.count or not value or value < 0 or value > 100 then return usage(source) end
            slots.setFertility(slots.get(parcel, index), value)
            slots.publish(parcel)
            journal.write('admin_set', { parcel = parcel.id, slot = index, accountId = accountId, details = { fertility = value } })
            bridge.AdminLog(source, 'Fertilité fixée', { parcelle = parcel.id, emplacement = index, fertilite = value })
            bridge.Chat(source, format('%s n° %d : fertilité %g %%.', parcel.label, index, value))
        elseif action == 'pousser' then
            local parcel = catalog.parcel(args[2])
            local index = tointeger(tonumber(args[3]))
            if not parcel or not index or index < 1 or index > parcel.count then return usage(source) end
            local slot = slots.get(parcel, index)
            local crop = slot.crop and catalog.crop(slot.crop)
            if not crop then return bridge.Chat(source, 'rien ne pousse ici.') end
            slots.ripen(slot, crop)
            slots.publish(parcel)
            journal.write('admin_set', { parcel = parcel.id, slot = index, accountId = accountId, details = { ripened = crop.id } })
            bridge.AdminLog(source, 'Culture mûrie', { parcelle = parcel.id, emplacement = index, culture = crop.id })
            bridge.Chat(source, format('%s n° %d : %s mûr.', parcel.label, index, crop.label))
        elseif action == 'arroser' then
            local parcel = catalog.parcel(args[2])
            if not parcel then return usage(source) end
            for index = 1, parcel.count do
                local slot = slots.get(parcel, index)
                if slot.crop then slots.water(slot) end
            end
            slots.publish(parcel)
            journal.write('admin_set', { parcel = parcel.id, accountId = accountId, details = { watered = true } })
            bridge.AdminLog(source, 'Parcelle arrosée', { parcelle = parcel.id })
            bridge.Chat(source, format('%s arrosée.', parcel.label))
        else
            usage(source)
        end
    end)
end

function admin.start()
    RegisterCommand(cfg.command, command, false)
end
