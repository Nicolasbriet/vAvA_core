--[[
    vava_farming/server/frost.lua
    Rôle : le gel des nuits d'hiver (vava_time, facultatif). Objets qui couvrent une plante (config.frost.cover, contrôlés
           au démarrage). Au soir d'une nuit de gel : avertissement aux seuls cultivateurs concernés — le propriétaire en
           jeu d'une parcelle privée où une plante est exposée, les joueurs à portée d'une parcelle commune exposée —,
           position lue côté serveur, rien envoyé aux autres. À la tombée de la nuit : plantes exposées perdues (ni
           couvertes ni d'une culture qui résiste au froid), parcelles republiées, journal, mêmes destinataires prévenus.
           Le travail se fait hors du thread de vava_time qui émet le hook.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/journal.lua, server/catalog.lua,
                  server/slots.lua
]]

local type, ipairs = type, ipairs
local mathType = math.type
local format = string.format
local concat = table.concat
local CreateThread = CreateThread

local bridge = VavaFarming.bridge
local journal = VavaFarming.journal
local catalog = VavaFarming.catalog
local slots = VavaFarming.slots
local geometry = VavaFarming.geometry
local cfg = VavaFarming.config
local messages = cfg.messages

local frost = {}
VavaFarming.frost = frost

---@type { item: string, quantity: integer }[]
local covers = {}

--- Objets qui couvrent une plante, dans l'ordre de la config (contrôlés au démarrage).
---@return { item: string, quantity: integer }[]
function frost.covers()
    return covers
end

--- Libellés des objets qui couvrent, joints (« Compost ou Paille »), pour les messages.
---@return string
function frost.coverLabels()
    local labels = {}
    for i, option in ipairs(covers) do labels[i] = catalog.itemLabel(option.item) end
    return concat(labels, messages.coverOr)
end

--- Cultivateurs concernés par des parcelles exposées : le propriétaire (droit d'accès) d'une parcelle privée, où qu'il
--- soit en jeu ; les joueurs à `warnRadius` m d'une parcelle commune.
---@param list { parcel: vAvA.ParcelDefinition, count: integer }[]
---@return { source: integer, labels: string[], count: integer }[]
local function recipients(list)
    local radius = cfg.frost.warnRadius
    local players = bridge.ActivePlayers()
    local bySource, ordered = {}, {}
    for _, entry in ipairs(list) do
        local parcel = entry.parcel
        for _, player in ipairs(players) do
            local concerned
            if parcel.owner then
                concerned = slots.canAccess(parcel, player.characterId)
            else
                concerned = player.x ~= nil and geometry.within(player.x, player.y, player.z, parcel.x, parcel.y, parcel.z, radius)
            end
            if concerned then
                local target = bySource[player.source]
                if not target then
                    target = { source = player.source, labels = {}, count = 0 }
                    bySource[player.source] = target
                    ordered[#ordered + 1] = target
                end
                target.labels[#target.labels + 1] = parcel.label
                target.count = target.count + entry.count
            end
        end
    end
    return ordered
end

--- Au soir d'une nuit de gel : les cultivateurs dont des plantes sont exposées sont avertis.
local function warn()
    local exposed = slots.exposed()
    if #exposed == 0 then return end
    for _, target in ipairs(recipients(exposed)) do
        bridge.Notify(target.source, format(messages.frostWarning, concat(target.labels, messages.parcelSeparator)), 'warning')
    end
end

--- Le gel tombe : plantes exposées perdues, journal, cultivateurs concernés prévenus.
local function strike()
    local struck = slots.frost()
    if #struck == 0 then return end
    -- une seule ligne de journal pour la nuit : plantes perdues par parcelle
    local total, byParcel = 0, {}
    for _, entry in ipairs(struck) do
        total = total + entry.count
        byParcel[entry.parcel.id] = entry.count
    end
    journal.write('frost', { details = { parcelles = byParcel, plantes = total } })
    VavaFarming.log.info('le gel a pris %d plante(s) sur %d parcelle(s)', total, #struck)
    for _, target in ipairs(recipients(struck)) do
        bridge.Notify(target.source, format(messages.frostStruck, target.count, concat(target.labels, messages.parcelSeparator)), 'danger')
    end
end

--- Contrôle les objets qui couvrent et branche les hooks de vava_time. Appelé pendant le setup.
---@return boolean ok
---@return string|nil err
function frost.start()
    covers = {}
    local list = type(cfg.frost) == 'table' and cfg.frost.cover
    if type(list) ~= 'table' or #list == 0 then return false, 'frost.cover : liste { item, quantity } attendue' end
    for index, option in ipairs(list) do
        if type(option) ~= 'table' or type(option.item) ~= 'string' or option.item == ''
            or mathType(option.quantity) ~= 'integer' or option.quantity < 1 then
            return false, format('frost.cover #%d : { item, quantity ≥ 1 } attendu', index)
        end
        covers[index] = { item = option.item, quantity = option.quantity }
    end
    if type(cfg.frost.warnRadius) ~= 'number' or cfg.frost.warnRadius < 0 then return false, 'frost.warnRadius : nombre attendu' end
    return bridge.OnFrost(function()
        CreateThread(warn)
    end, function()
        CreateThread(strike)
    end)
end
