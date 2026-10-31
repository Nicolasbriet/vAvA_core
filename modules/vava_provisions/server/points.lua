--[[
    vava_provisions/server/points.lua
    Rôle : catalogue des points d'eau tenu par le serveur. Chaque point validé par rules.validatePoint (seul juge) est
           une zone du core (`def` : de quoi le dessiner) que seuls les joueurs proches reçoivent ; aucune boucle, aucun
           envoi de plus. Réserve par point des sortes qui en ont une, EN MÉMOIRE (pleine à chaque démarrage, jamais
           publiée) : niveau calculé sur l'heure à chaque lecture, puisages réservés avant l'échange et rendus s'il
           échoue, réglage du Conseil. `put` et `drop` sont les futures `apply` et `remove` de l'éditeur de l'Atelier ;
           le chargement de la config passe déjà par `put`.
    Dépendances : shared/constants.lua, config.lua, shared/rules.lua, shared/pointzone.lua, server/core.lua,
                  bridge/server.lua
]]

local ipairs, tostring = ipairs, tostring
local sqrt, min, max, huge = math.sqrt, math.min, math.max, math.huge
local remove = table.remove

local bridge = VavaProvisions.bridge
local rules = VavaProvisions.rules
local pointzone = VavaProvisions.pointzone
local cfg = VavaProvisions.config
local streaming = cfg.streaming
local DEF = pointzone.DEF

local points = {}
VavaProvisions.points = points

---@class vAvA.WaterPoint
---@field id string
---@field kind string
---@field label string
---@field x number
---@field y number
---@field z number
---@field heading number
---@field model string   '' : aucun prop

---@type table<string, vAvA.WaterPoint>
local byId = {}
---@type vAvA.WaterPoint[]  dans l'ordre de déclaration (config d'abord)
local ordered = {}
---@type table<string, { level: number, at: integer }>  sortes à réserve seulement ; `level` garde la fraction en cours
local reserves = {}

---@param point vAvA.WaterPoint
---@return table
local function areaOf(point)
    return pointzone.area(point, streaming.zoneRadius, streaming.radius + streaming.subscribeSlack)
end

---@param kindId string
---@return { capacity: integer, refillSeconds?: integer }
local function reserveOf(kindId)
    return cfg.kinds[kindId].reserve
end

---@param id string
local function unlist(id)
    for index, point in ipairs(ordered) do
        if point.id == id then
            remove(ordered, index)
            return
        end
    end
end

--- Déclare ou met à jour un point d'eau : validé, zone du core déclarée (ou déplacée puis remplacée), réserve gardée
--- s'il garde sa sorte (ramenée à la nouvelle capacité), pleine s'il est nouveau ou change de sorte, oubliée pour une
--- sorte sans fond. Zone refusée par le core (`full` : trop de zones) : point absent (ou inchangé), code rendu.
---@param def table
---@return boolean ok
---@return string|nil code  invalid_* | unknown_kind | too_many | code du core
---@return string|nil field
function points.put(def)
    local ok, point, field = rules.validatePoint(def, cfg.kinds)
    if not ok then return false, point, field end
    local previous = byId[point.id]
    if not previous and #ordered >= cfg.maxPoints then return false, 'too_many' end
    local state = { [DEF] = pointzone.drawing(point, cfg.kinds) }
    local zoneOk, zoneErr
    if previous then
        zoneOk, zoneErr = bridge.Zones.move(point.id, areaOf(point))
        if zoneOk then zoneOk, zoneErr = bridge.Zones.replace(point.id, state) end
    else
        zoneOk, zoneErr = bridge.Zones.define(point.id, areaOf(point), state)
    end
    if not zoneOk then return false, tostring(zoneErr) end

    local reserve = reserveOf(point.kind)
    local now = bridge.Now()
    if reserve.capacity == 0 then
        reserves[point.id] = nil
    elseif previous and previous.kind == point.kind and reserves[point.id] then
        local kept = reserves[point.id]
        reserves[point.id] = { level = min(reserve.capacity, rules.level(kept.level, kept.at, now, reserve)), at = now }
    else
        reserves[point.id] = { level = reserve.capacity, at = now }
    end
    byId[point.id] = point
    if previous then
        for index, entry in ipairs(ordered) do
            if entry.id == point.id then ordered[index] = point end
        end
    else
        ordered[#ordered + 1] = point
    end
    return true
end

--- Retire un point : sa zone (les abonnés en reçoivent la sortie) et sa réserve.
---@param id string
---@return boolean ok
---@return string|nil code
function points.drop(id)
    if not byId[id] then return false, 'unknown_point' end
    local ok, err = bridge.Zones.remove(id)
    if not ok then return false, tostring(err) end
    byId[id], reserves[id] = nil, nil
    unlist(id)
    return true
end

--- Charge les points de la config (setup). Un point refusé par le core est écrit en console et n'empêche pas les autres.
---@return integer shared  points déclarés
function points.loadConfig()
    local shared = 0
    for _, def in ipairs(cfg.points) do
        local ok, code = points.put(def)
        if ok then
            shared = shared + 1
        else
            VavaProvisions.log.error("point d'eau '%s' non partagé avec les joueurs proches : %s", tostring(def.id), tostring(code))
        end
    end
    return shared
end

---@param id any
---@return vAvA.WaterPoint|nil
function points.get(id)
    return byId[id]
end

--- Points dans l'ordre de déclaration (liste du module : ne pas la modifier).
---@return vAvA.WaterPoint[]
function points.list()
    return ordered
end

--- Niveau de la réserve d'un point à `now` (math.huge sans fond).
---@param point vAvA.WaterPoint
---@param now integer
---@return number
function points.level(point, now)
    local stored = reserves[point.id]
    if not stored then return huge end
    return rules.level(stored.level, stored.at, now, reserveOf(point.kind))
end

--- Réserve d'un point : `{ level, capacity }` (niveau entier disponible), ou nil sans fond.
---@param point vAvA.WaterPoint
---@param now integer
---@return { level: integer, capacity: integer }|nil
function points.reserve(point, now)
    if not reserves[point.id] then return nil end
    return { level = rules.available(points.level(point, now)), capacity = reserveOf(point.kind).capacity }
end

--- Réserve `count` puisages AVANT l'échange (rien entre la lecture du niveau et cet appel ne cède la main) : le niveau
--- présent, moins `count`, est gardé à `now`. Sans fond : rien.
---@param point vAvA.WaterPoint
---@param level number  niveau lu à `now`
---@param count integer
---@param now integer
function points.take(point, level, count, now)
    if not reserves[point.id] then return end
    reserves[point.id] = { level = level - count, at = now }
end

--- Rend `count` puisages réservés (échange refusé), au plus la capacité, même heure.
---@param point vAvA.WaterPoint
---@param count integer
function points.giveBack(point, count)
    local stored = reserves[point.id]
    if not stored then return end
    stored.level = min(reserveOf(point.kind).capacity, stored.level + count)
end

--- Fixe la réserve d'un point (Conseil).
---@param point vAvA.WaterPoint
---@param amount integer
---@param now integer
---@return boolean ok  faux pour une sorte sans fond
function points.setReserve(point, amount, now)
    if not reserves[point.id] then return false end
    reserves[point.id] = { level = max(0, min(reserveOf(point.kind).capacity, amount)), at = now }
    return true
end

--- Point le plus proche d'une position à au plus `radius` mètres (distance 3D), et sa distance ; ou nil.
---@param x number
---@param y number
---@param z number
---@param radius number
---@return string|nil id
---@return number|nil distance
function points.near(x, y, z, radius)
    local bestId, bestDistance = nil, radius
    for _, point in ipairs(ordered) do
        local dx, dy, dz = x - point.x, y - point.y, z - point.z
        local distance = sqrt(dx * dx + dy * dy + dz * dz)
        if distance <= bestDistance then bestId, bestDistance = point.id, distance end
    end
    if not bestId then return nil end
    return bestId, bestDistance
end

--- Vue d'un point pour les exports : `{ id, kind, label, x, y, z, reserve? = { level, capacity } }`.
---@param point vAvA.WaterPoint
---@param now integer
---@return table
function points.view(point, now)
    return {
        id = point.id, kind = point.kind, label = point.label, x = point.x, y = point.y, z = point.z,
        reserve = points.reserve(point, now),
    }
end
