--[[
    vava_magic/server/combat.lua
    Rôle : blessures infligées par les sorts, décidées par le serveur : dégâts en points de vie (sur
           `combat.healthPoints`), entre joueurs activés ou non, zones protégées (personne n'y est blessé), application
           par le bridge (vava_health), et journal des dégâts pour le Conseil (lanceur, cible, dégâts, position),
           écrit en base par lots. La victime d'un impact ou d'une zone reçoit la réaction du sort (son élément, ou son
           champ `reaction` : geste, effet d'écran) ; une brûlure qui dure n'en envoie pas à chaque morsure. Un sort
           offensif sans dégâts (recul, état) demande d'abord si la cible peut être touchée (`combat.affects`).
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/world.lua
]]

local ipairs, tostring, min = ipairs, tostring, math.min
local time, rep, move = os.time, string.rep, table.move
local SetTimeout, TriggerClientEvent = SetTimeout, TriggerClientEvent

local bridge = VavaMagic.bridge
local world = VavaMagic.world
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config.combat
local EVENTS = VavaMagic.EVENTS

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

--- Un sort offensif peut-il toucher ce joueur ? (dégâts entre joueurs activés, personnage en jeu, hors zone
--- protégée) Renvoie sa position lue côté serveur, ou nil.
---@param target integer
---@return table|nil
function combat.affects(target)
    if not cfg.pvp or not bridge.GetCharacterId(target) then return nil end
    local position = world.position(target)
    if not position or combat.protected(position) then return nil end
    return position
end

--- La victime d'un sort réagit : geste bref et effet d'écran selon le sort (son élément, ou son champ `reaction`).
---@param target integer
---@param spell string
function combat.react(target, spell)
    local def = VavaMagic.spells.get(spell)
    if def then TriggerClientEvent(EVENTS.HIT, target, def.config.reaction or def.config.element) end
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
---@param points number    points de vie retirés
---@param kind string      combat.KIND
---@param casterCharacter? integer  personnage du lanceur, quand il a pu partir depuis (zone, brûlure)
---@return boolean
function combat.damage(caster, target, spell, points, kind, casterCharacter)
    if not cfg.pvp or points <= 0 then return false end
    local part = min(1, points / cfg.healthPoints)
    local position = world.position(target)
    if not position or combat.protected(position) then return false end
    local targetCharacter = bridge.GetCharacterId(target)
    if not targetCharacter then return false end
    if not bridge.ApplyDamage(target, part) then return false end
    queue[#queue + 1] = {
        time(), spell, casterCharacter or bridge.GetCharacterId(caster) or 0, targetCharacter, kind, points, position.x, position.y, position.z,
    }
    if #queue >= cfg.log.batch then combat.flush() end
    if kind ~= combat.KIND.BURN then combat.react(target, spell) end
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
