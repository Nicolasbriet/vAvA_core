--[[
    vava_voice/server/zones.lua
    Rôle : zones de voix, gardées en mémoire après une lecture au démarrage. Création, modification, suppression par
           le Conseil : nom compté en signes (shared/label.lua), valeurs ramenées aux bornes et au pas de la
           configuration, centre lu côté serveur (position du membre du Conseil, jamais envoyée par son client),
           écriture en base avant toute diffusion, journal.
           Chaque zone est une zone du core (abonnements de zone, 1.3.0) : envoyée aux seuls joueurs proches (rayon
           + subscribeMargin, positions lues par le serveur), et chaque changement aux seuls joueurs qui la suivent.
    Dépendances : shared/constants.lua, config.lua, shared/label.lua, server/core.lua (core.zones, vAvA_core 0.11.0),
                  server/store.lua, server/links.lua
]]

local pairs, ipairs, tostring, sort, floor = pairs, ipairs, tostring, table.sort, math.floor
local GetPlayerPed, GetEntityCoords = GetPlayerPed, GetEntityCoords

local store = VavaVoice.store
local links = VavaVoice.links
local names = VavaVoice.label
local cfg = VavaVoice.config.zones
local messages = VavaVoice.config.messages
local HOOK_CHANGED = VavaVoice.HOOKS.ZONES_CHANGED
-- coordonnées gardées au centimètre
local COORD_PRECISION = 100

local zones = {}
VavaVoice.zones = zones

---@type table<integer, vAvA.VoiceZone>
local list = {}
local count = 0
-- numéros des zones déclarées au core (une déclaration refusée est retentée au changement suivant)
---@type table<integer, true>
local declared = {}

---@param zone vAvA.VoiceZone
---@return vAvA.VoiceZone
local function copy(zone)
    return {
        id = zone.id, label = zone.label, x = zone.x, y = zone.y, z = zone.z,
        radius = zone.radius, height = zone.height, multiplier = zone.multiplier,
    }
end

---@param value number
---@param bounds { min: number, max: number, step: number }
---@return number
local function snap(value, bounds)
    local snapped = floor(value / bounds.step + 0.5) * bounds.step
    if snapped < bounds.min then return bounds.min end
    if snapped > bounds.max then return bounds.max end
    return snapped
end

local function round(value)
    return floor(value * COORD_PRECISION + 0.5) / COORD_PRECISION
end

--- Position du membre du Conseil, lue par le serveur.
---@param src integer
---@return table|nil
local function positionOf(src)
    local ped = GetPlayerPed(src)
    if not ped or ped == 0 then return nil end
    local coords = GetEntityCoords(ped)
    return { x = round(coords.x), y = round(coords.y), z = round(coords.z) }
end

--- Nom de la zone du core : « z<numéro> » (le core le préfixe par la ressource).
---@param id integer
---@return string
local function coreId(id)
    return 'z' .. id
end

--- Lieu de la zone du core : cercle au sol de la zone de voix, connu des joueurs à subscribeMargin de son bord.
---@param zone vAvA.VoiceZone
---@return table
local function areaOf(zone)
    return { x = zone.x, y = zone.y, z = zone.z, radius = zone.radius, margin = cfg.subscribeMargin }
end

--- Déclare (ou met à jour) la zone au core : les joueurs proches la reçoivent, eux seuls.
---@param zone vAvA.VoiceZone
---@return boolean ok
local function share(zone)
    local core = VavaVoice.core
    local id, name = zone.id, coreId(zone.id)
    local ok, err
    if declared[id] then
        ok, err = core.zones.move(name, areaOf(zone))
        if ok then ok, err = core.zones.set(name, { zone = copy(zone) }) end
    else
        ok, err = core.zones.define(name, areaOf(zone), { zone = copy(zone) })
        if ok then declared[id] = true end
    end
    if not ok then VavaVoice.log.error('zone #%d non partagée avec les joueurs proches : %s', id, tostring(err)) end
    return ok == true
end

---@param action string
---@param zone vAvA.VoiceZone|nil
---@param id integer
---@param src integer
local function publish(action, zone, id, src)
    if zone then
        share(zone)
    elseif declared[id] then
        local ok, err = VavaVoice.core.zones.remove(coreId(id))
        if not ok then VavaVoice.log.error('zone #%d non retirée du core : %s', id, tostring(err)) end
        declared[id] = nil
    end
    VavaVoice.core.hooks.runAfter(HOOK_CHANGED, { action = action, id = id, zone = zone and copy(zone) or nil, source = src })
end

---@param zone vAvA.VoiceZone
---@return table
local function describe(zone)
    return { zone = zone.label, rayon = zone.radius, hauteur = zone.height, effet = zone.multiplier }
end

--- Lit les zones en base. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function zones.load()
    local rows, err = store.load()
    if not rows then return false, err end
    list, count = {}, 0
    for _, zone in ipairs(rows) do
        list[zone.id] = zone
        count = count + 1
    end
    return true
end

--- Déclare toutes les zones lues au core. Appelé pendant le setup, après zones.load() : une zone refusée est écrite en
--- console et n'empêche pas les autres.
---@return integer shared  zones déclarées
function zones.declareAll()
    declared = {}
    local ids = {}
    for id in pairs(list) do ids[#ids + 1] = id end
    sort(ids)
    local shared = 0
    for _, id in ipairs(ids) do
        if share(list[id]) then shared = shared + 1 end
    end
    return shared
end

--- Toutes les zones (copies), par numéro.
---@return vAvA.VoiceZone[]
function zones.all()
    local out = {}
    for _, zone in pairs(list) do out[#out + 1] = copy(zone) end
    sort(out, function(a, b) return a.id < b.id end)
    return out
end

---@param id integer
---@return vAvA.VoiceZone|nil
function zones.get(id)
    local zone = list[id]
    return zone and copy(zone)
end

--- Nouvelle zone centrée sur le membre du Conseil.
---@param src integer
---@param label string
---@param radius number
---@param height number
---@param multiplier number  une des valeurs de la configuration (vérifié par le schéma de la RPC)
---@return boolean ok
---@return vAvA.VoiceZone|string result
function zones.create(src, label, radius, height, multiplier)
    if count >= cfg.max then return false, 'too_many_zones' end
    local name, nameErr = names.clean(label)
    if not name then return false, nameErr end
    local position = positionOf(src)
    if not position then return false, 'no_position' end
    local zone = {
        label = name, x = position.x, y = position.y, z = position.z,
        radius = snap(radius, cfg.radius), height = snap(height, cfg.height), multiplier = multiplier,
    }
    local id, err = store.insert(zone)
    if not id then
        VavaVoice.log.error('zone non enregistrée : %s', tostring(err))
        return false, 'db_error'
    end
    zone.id = id
    list[id] = zone
    count = count + 1
    links.record(src, messages.logCreate, describe(zone))
    publish('set', zone, id, src)
    return true, copy(zone)
end

--- Enregistre une modification (nom, dimensions, effet, et centre s'il est donné) ; ne prévient personne.
---@param id integer
---@param label string
---@param radius number
---@param height number
---@param multiplier number
---@param position table|nil
---@return boolean ok
---@return vAvA.VoiceZone|string result
local function edit(id, label, radius, height, multiplier, position)
    local current = list[id]
    if not current then return false, 'unknown_zone' end
    local name, nameErr = names.clean(label)
    if not name then return false, nameErr end
    local zone = copy(current)
    zone.label, zone.radius, zone.height, zone.multiplier = name, snap(radius, cfg.radius), snap(height, cfg.height), multiplier
    if position then zone.x, zone.y, zone.z = position.x, position.y, position.z end
    local ok, err = store.update(zone)
    if not ok then
        VavaVoice.log.error('zone #%d non enregistrée : %s', id, tostring(err))
        return false, 'db_error'
    end
    list[id] = zone
    return true, zone
end

--- Retire une zone de la base et de la mémoire ; ne prévient personne.
---@param id integer
---@return boolean ok
---@return vAvA.VoiceZone|string result
local function delete(id)
    local zone = list[id]
    if not zone then return false, 'unknown_zone' end
    local ok, err = store.delete(id)
    if not ok then
        VavaVoice.log.error('zone #%d non supprimée : %s', id, tostring(err))
        return false, 'db_error'
    end
    list[id] = nil
    count = count - 1
    return true, zone
end

--- Modifie une zone en jeu ; `moveHere` : recentrée sur le membre du Conseil.
---@param src integer
---@param id integer
---@param label string
---@param radius number
---@param height number
---@param multiplier number
---@param moveHere boolean
---@return boolean ok
---@return vAvA.VoiceZone|string result
function zones.update(src, id, label, radius, height, multiplier, moveHere)
    local position = nil
    if moveHere then
        position = positionOf(src)
        if not position then return false, 'no_position' end
    end
    local ok, zone = edit(id, label, radius, height, multiplier, position)
    if not ok then return false, zone end
    local details = describe(zone)
    if moveHere then details.deplacee = 'oui' end
    links.record(src, messages.logUpdate, details)
    publish('set', zone, id, src)
    return true, copy(zone)
end

---@param src integer
---@param id integer
---@return boolean ok
---@return string|nil code
function zones.remove(src, id)
    local ok, zone = delete(id)
    if not ok then return false, zone end
    links.record(src, messages.logDelete, { zone = zone.label })
    publish('remove', nil, id, src)
    return true
end

--- Modification depuis le panneau web : sans recentrage (le compte du panneau n'a pas de position), le journal est
--- tenu par le pont. Renvoie la zone et ses détails pour le journal.
---@return boolean ok
---@return vAvA.VoiceZone|string result
---@return table|nil details
function zones.webUpdate(id, label, radius, height, multiplier)
    local ok, zone = edit(id, label, radius, height, multiplier, nil)
    if not ok then return false, zone end
    publish('set', zone, id, nil)
    return true, copy(zone), describe(zone)
end

---@return boolean ok
---@return string|nil code
---@return table|nil details
function zones.webRemove(id)
    local ok, zone = delete(id)
    if not ok then return false, zone end
    publish('remove', nil, id, nil)
    return true, nil, { zone = zone.label }
end
