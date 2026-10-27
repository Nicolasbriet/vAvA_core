--[[
    vava_magic/server/combat.lua
    Rôle : blessures infligées par les sorts, décidées par le serveur : dégâts entre joueurs activés ou non, zones
           protégées (personne n'y est blessé), application par le bridge (vava_health), et journal des dégâts pour
           le Conseil (lanceur, cible, dégâts, position), écrit en base par lots.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/world.lua
]]

local ipairs, tostring, min = ipairs, tostring, math.min
local time, rep, concat, move = os.time, string.rep, table.concat, table.move
local SetTimeout = SetTimeout

local bridge = VavaMagic.bridge
local world = VavaMagic.world
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config.combat

local INSERT = 'INSERT INTO `vava_magic_damage_log` (`at`, `spell`, `caster_id`, `target_id`, `kind`, `damage`, `x`, `y`, `z`) VALUES '
local ROW = '(?, ?, ?, ?, ?, ?, ?, ?, ?)'
-- au-delà, les lignes en attente d'une base qui ne répond pas sont abandonnées (journal en console)
local QUEUE_MAX = 500

local combat = {}
VavaMagic.combat = combat

combat.KIND = { IMPACT = 'impact', ZONE = 'zone', BURN = 'brulure' }

local queue = {}

--- Point dans une zone protégée ?
---@param point table
---@return boolean
function combat.protected(point)
    return geometry.protectedZone(point) ~= nil
end

--- Écrit en base les dégâts en attente (une requête par lot).
function combat.flush()
    if #queue == 0 then return end
    local count = min(#queue, cfg.log.batch)
    local rows = move(queue, 1, count, 1, {})
    local remaining = {}
    move(queue, count + 1, #queue, 1, remaining)
    queue = remaining
    local params = {}
    for _, row in ipairs(rows) do
        for _, value in ipairs(row) do params[#params + 1] = value end
    end
    local sql = INSERT .. rep(ROW, count, ', ')
    local _, err = bridge.db.query(sql, params)
    if err then
        VavaMagic.log.warn('journal des dégâts non écrit (%d lignes) : %s', count, tostring(err))
        if #queue + count <= QUEUE_MAX then move(rows, 1, count, #queue + 1, queue) end
    end
end

--- Blesse un joueur au nom d'un sort, puis l'inscrit au journal. Renvoie vrai si la blessure est appliquée.
---@param caster integer   source du lanceur
---@param target integer   source de la cible
---@param spell string
---@param part number      part de la vie (0 à 1)
---@param kind string      combat.KIND
---@return boolean
function combat.damage(caster, target, spell, part, kind)
    if not cfg.pvp or part <= 0 then return false end
    local position = world.position(target)
    if not position or combat.protected(position) then return false end
    local targetCharacter = bridge.GetCharacterId(target)
    if not targetCharacter then return false end
    if not bridge.ApplyDamage(target, part) then return false end
    queue[#queue + 1] = {
        time(), spell, bridge.GetCharacterId(caster) or 0, targetCharacter, kind, part, position.x, position.y, position.z,
    }
    if #queue >= cfg.log.batch then combat.flush() end
    return true
end

--- Écriture régulière du journal. Appelé pendant le setup du module.
function combat.start()
    local function loop()
        combat.flush()
        SetTimeout(cfg.log.flushMs, loop)
    end
    SetTimeout(cfg.log.flushMs, loop)
end
