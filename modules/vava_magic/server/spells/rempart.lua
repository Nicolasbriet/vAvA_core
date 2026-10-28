--[[
    vava_magic/server/spells/rempart.lua
    Rôle : sort Rempart (utilitaire défensif), décidé par le serveur.
      - Début : point visé revérifié (server/zones.lua : portée du niveau, hauteur, zones protégées), place pour ses
        blocs sous le plafond du royaume (le rempart que le lanceur remplacera compris).
      - Fin : segments calculés ici (shared/geometry.lua : un segment face au lanceur, ou deux bras en chevron au
        niveau 5), aucun point de sa ligne en zone protégée ; refusé si un joueur (lanceur compris) ou un véhicule
        se tient sur la ligne du mur (positions lues côté serveur). Le rempart précédent du lanceur s'effondre. Blocs
        de pierre : objets réseau créés par le serveur et figés, enfouis puis montés par paliers ; les joueurs
        proches voient la poussière et sentent le sol trembler.
      - Debout : il arrête les pas (collision des blocs) et, déclaré obstacle (server/obstacles.lua), les projectiles,
        la vague et les éclats qui voudraient passer à travers, sous sa hauteur.
      - À la fin de sa durée, il s'enfonce et disparaît ; à l'arrêt du module et au nettoyage du Conseil, ses blocs
        sont retirés sur-le-champ. Un rempart reste debout si son lanceur part : il tombe à son heure.
    Dépendances : shared/, config.lua, server/ (noyau, combat, zones, obstacles)
]]

local ipairs, pairs, tostring, abs, max, ceil, random, sort, huge = ipairs, pairs, tostring, math.abs, math.max, math.ceil, math.random, table.sort, math.huge
local SetTimeout, GetHashKey, CreateObjectNoOffset, FreezeEntityPosition, SetEntityHeading, SetEntityCoords, DoesEntityExist, DeleteEntity =
    SetTimeout, GetHashKey, CreateObjectNoOffset, FreezeEntityPosition, SetEntityHeading, SetEntityCoords, DoesEntityExist, DeleteEntity

local world = VavaMagic.world
local spells = VavaMagic.spells
local combat = VavaMagic.combat
local zones = VavaMagic.zones
local obstacles = VavaMagic.obstacles
local sheets = VavaMagic.sheets
local geometry = VavaMagic.geometry
local spellCfg = VavaMagic.config.spells.rempart
local placement = spellCfg.placement
local rise = spellCfg.rise
local EVENTS = VavaMagic.EVENTS
local NAME = 'rempart'
local MODEL = GetHashKey(spellCfg.model)
local COORD = { type = 'number', min = -20000, max = 20000 }
-- désordre du cap entre deux blocs (degrés) : un mur de pierres levées, pas une rangée de copies
local HEADING_JITTER = 15
-- un trajet qui passe à peine sous le pied du mur (sol inégal) est encore arrêté (m)
local BELOW = 0.5
-- la ligne du mur est vérifiée tous les tant de mètres contre les zones protégées
local PROTECTED_SPACING = 1.0

---@class vAvA.Rampart
---@field id integer
---@field owner integer
---@field ownerCharacter integer
---@field level integer
---@field segments { a: table, b: table }[]
---@field view table[]       segments envoyés aux clients (tables à clés nommées)
---@field base number        hauteur du sol au point visé
---@field height number
---@field center table
---@field pieces { entity: integer, x: number, y: number, z: number }[]
---@field gone boolean       blocs retirés du monde

---@type table<integer, vAvA.Rampart>
local ramparts = {}
---@type table<integer, vAvA.Rampart>  remparts qui s'effondrent (plus un obstacle, blocs encore là)
local falling = {}
local pieceCount, lastId = 0, 0

---@param levelCfg table
---@return integer
local function piecesOf(levelCfg)
    return levelCfg.pieces * levelCfg.segments
end

--- Remparts debout d'un personnage, du plus ancien au plus récent.
---@param characterId integer
---@return vAvA.Rampart[]
local function ofCharacter(characterId)
    local list = {}
    for _, rampart in pairs(ramparts) do
        if rampart.ownerCharacter == characterId then list[#list + 1] = rampart end
    end
    sort(list, function(a, b) return a.id < b.id end)
    return list
end

--- Remparts du lanceur qu'un nouveau fera tomber (au-delà de `maxPerCaster`).
---@param src integer
---@return vAvA.Rampart[]
local function replacedBy(src)
    local sheet = sheets.get(src)
    local own = sheet and ofCharacter(sheet.characterId) or {}
    local list = {}
    for i = 1, #own - spellCfg.maxPerCaster + 1 do list[#list + 1] = own[i] end
    return list
end

--- Reste-t-il assez de blocs dans le royaume pour ce rempart (ceux qu'il remplace rendus) ?
---@param src integer
---@param levelCfg table
---@return boolean
local function room(src, levelCfg)
    local freed = 0
    for _, rampart in ipairs(replacedBy(src)) do freed = freed + #rampart.pieces end
    return pieceCount - freed + piecesOf(levelCfg) <= spellCfg.maxPieces
end

---@param rampart vAvA.Rampart
local function destroy(rampart)
    rampart.gone = true
    for _, piece in ipairs(rampart.pieces) do
        if DoesEntityExist(piece.entity) then DeleteEntity(piece.entity) end
    end
end

--- Monte (ou enfonce) les blocs par paliers, puis appelle `done`.
---@param rampart vAvA.Rampart
---@param rising boolean
---@param done? fun()
local function move(rampart, rising, done)
    if rise.steps <= 0 then
        if done then done() end
        return
    end
    local stepMs = rise.ms // rise.steps
    for step = 1, rise.steps do
        SetTimeout(stepMs * step, function()
            if rampart.gone then return end
            local share = step / rise.steps
            local offset = rising and rise.depth * (1 - share) or rise.depth * share
            for _, piece in ipairs(rampart.pieces) do
                if DoesEntityExist(piece.entity) then SetEntityCoords(piece.entity, piece.x, piece.y, piece.z - offset, false, false, false, false) end
            end
            if step == rise.steps and done then done() end
        end)
    end
end

---@param rampart vAvA.Rampart
---@param collapse boolean
local function announce(rampart, collapse)
    local center = rampart.center
    world.broadcast(center, spellCfg.broadcastRadius, EVENTS.BURST, {
        spell = NAME, caster = rampart.owner, x = center.x, y = center.y, z = center.z, level = rampart.level,
        segments = rampart.view, collapse = collapse,
    })
end

--- Le rempart cesse d'être un obstacle ; ses blocs s'enfoncent (`animated`) ou sont retirés sur-le-champ.
---@param id integer
---@param animated boolean
local function remove(id, animated)
    local rampart = ramparts[id]
    if not rampart then return end
    ramparts[id] = nil
    pieceCount = pieceCount - #rampart.pieces
    if not animated then
        destroy(rampart)
        return
    end
    falling[id] = rampart
    announce(rampart, true)
    move(rampart, false, function()
        falling[id] = nil
        destroy(rampart)
    end)
end

--- Retire du monde tous les remparts, debout ou en train de tomber. Renvoie leur nombre.
---@return integer
local function clearAll()
    local count = 0
    for id in pairs(ramparts) do
        remove(id, false)
        count = count + 1
    end
    for id, rampart in pairs(falling) do
        falling[id] = nil
        destroy(rampart)
    end
    return count
end

--- Un joueur ou un véhicule se tient-il sur la ligne du mur ?
---@param segments table[]
---@param levelCfg table
---@param point table
---@return boolean
local function occupied(segments, levelCfg, point)
    local radius = levelCfg.length * levelCfg.segments + levelCfg.width + placement.vehicleMargin
    local function onLine(position, margin)
        if abs(position.z - point.z) > placement.heightMargin then return false end
        for _, segment in ipairs(segments) do
            if geometry.segmentDistance2d(position, segment.a, segment.b) <= levelCfg.width / 2 + margin then return true end
        end
        return false
    end
    for _, entry in ipairs(world.near(point, radius)) do
        if onLine(entry.position, placement.playerMargin) then return true end
    end
    for _, position in ipairs(world.vehiclesNear(point, radius)) do
        if onLine(position, placement.vehicleMargin) then return true end
    end
    return false
end

--- Dresse les blocs (enfouis s'ils doivent monter). Renvoie le rempart, ou nil si un objet n'a pu être créé.
---@return vAvA.Rampart|nil
local function raise(src, characterId, level, levelCfg, point, segments)
    local depth = rise.steps > 0 and rise.depth or 0
    lastId = lastId + 1
    local rampart = {
        id = lastId, owner = src, ownerCharacter = characterId, level = level, segments = segments, view = {},
        base = point.z, height = levelCfg.height, center = point, pieces = {}, gone = false,
    }
    local ground = point.z - spellCfg.sink
    for _, segment in ipairs(segments) do
        local a, b = segment.a, segment.b
        rampart.view[#rampart.view + 1] = { x = a.x, y = a.y, z = a.z, x2 = b.x, y2 = b.y, z2 = b.z }
        local heading = geometry.heading(b.x - a.x, b.y - a.y)
        for i = 1, levelCfg.pieces do
            local t = (i - 0.5) / levelCfg.pieces
            local x, y = a.x + (b.x - a.x) * t, a.y + (b.y - a.y) * t
            local entity = CreateObjectNoOffset(MODEL, x, y, ground - depth, true, true, false)
            if not entity or entity == 0 then
                destroy(rampart)
                return nil
            end
            FreezeEntityPosition(entity, true)
            SetEntityHeading(entity, (heading + (random() * 2 - 1) * HEADING_JITTER) % 360)
            rampart.pieces[#rampart.pieces + 1] = { entity = entity, x = x, y = y, z = ground }
        end
    end
    ramparts[rampart.id] = rampart
    pieceCount = pieceCount + #rampart.pieces
    announce(rampart, false)
    move(rampart, true)
    SetTimeout(levelCfg.durationMs, function()
        if ramparts[rampart.id] == rampart then remove(rampart.id, true) end
    end)
    return rampart
end

---@param ctx table
local function begin(ctx, x, y, z)
    local levelCfg = spellCfg.levels[ctx.level]
    local point, code = zones.aimed(ctx, x, y, z, levelCfg.reach, spellCfg.heightMargin)
    if not point then return false, code end
    if not room(ctx.source, levelCfg) then return false, 'rampart_limit' end
    return true, { point = point }
end

---@param ctx table
local function finish(ctx)
    local src = ctx.source
    local position = world.position(src)
    local sheet = sheets.get(src)
    if not position or not sheet then return false, 'no_position' end
    local levelCfg = spellCfg.levels[ctx.level]
    local point = ctx.data.point
    local segments = geometry.wallSegments(position, point, levelCfg.length, levelCfg.segments, spellCfg.bendDeg)
        or geometry.wallSegments(ctx.origin, point, levelCfg.length, levelCfg.segments, spellCfg.bendDeg)
    if not segments then return false, 'no_point' end
    for _, segment in ipairs(segments) do
        local steps = max(1, ceil(geometry.distance2d(segment.a, segment.b) / PROTECTED_SPACING))
        for i = 0, steps do
            local t = i / steps
            local x, y = segment.a.x + (segment.b.x - segment.a.x) * t, segment.a.y + (segment.b.y - segment.a.y) * t
            if combat.protected({ x = x, y = y, z = point.z }) then return false, 'protected_zone' end
        end
    end
    if occupied(segments, levelCfg, point) then return false, 'blocked_spot' end
    if not room(src, levelCfg) then return false, 'rampart_limit' end
    for _, rampart in ipairs(replacedBy(src)) do remove(rampart.id, true) end
    local rampart = raise(src, sheet.characterId, ctx.level, levelCfg, point, segments)
    if not rampart then return false, 'refused' end
    return { success = true, result = { id = rampart.id } }
end

-- les remparts debout arrêtent ce qui passe à travers, sous leur hauteur
obstacles.add(function(from, to)
    local nearest, best = nil, huge
    for _, rampart in pairs(ramparts) do
        for _, segment in ipairs(rampart.segments) do
            local t = geometry.crossing2d(from, to, segment.a, segment.b)
            if t and t < best then
                local z = from.z + (to.z - from.z) * t
                if z >= rampart.base - BELOW and z <= rampart.base + rampart.height then
                    nearest, best = { x = from.x + (to.x - from.x) * t, y = from.y + (to.y - from.y) * t, z = z }, t
                end
            end
        end
    end
    return nearest
end)

spells.onStop(clearAll)
spells.onCleanup(clearAll)

local ok, err = spells.register(NAME, {
    config = spellCfg,
    beginArgs = { COORD, COORD, COORD },
    finishArgs = {},
    begin = begin,
    finish = finish,
})
if not ok then VavaMagic.log.error('Rempart non déclaré : %s', tostring(err)) end
