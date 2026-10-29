--[[
    vava_magic/server/combat.lua
    Rôle : blessures infligées par les sorts, décidées par le serveur : dégâts en points de vie (sur
           `combat.healthPoints`), entre joueurs activés ou non, zones protégées (personne n'y est blessé), application
           par le bridge (vava_health), et journal des dégâts pour le Conseil (lanceur, cible, dégâts, position),
           écrit en base par lots. La victime d'un impact ou d'une zone reçoit la réaction du sort (son élément, ou son
           champ `reaction` : geste, effet d'écran) ; une brûlure qui dure n'en envoie pas à chaque morsure. Un sort
           offensif sans dégâts (recul, état) demande d'abord si la cible peut être touchée (`combat.affects` : jamais
           un joueur à terre).
           Un lot plein du journal s'écrit dans son propre thread : celui qui blesse (vérification des zones, morsure
           d'une brûlure, impact) n'attend jamais la base au milieu de son travail. À l'arrêt du module, tout ce qui
           attend part en une seule requête. Les lignes plus anciennes que `combat.log.retentionDays` sont retirées
           au démarrage du module puis une fois par jour, par lots bornés.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/world.lua
]]

local ipairs, tostring, tonumber, min, floor = ipairs, tostring, tonumber, math.min, math.floor
local time, rep, move = os.time, string.rep, table.move
local SetTimeout, CreateThread, Wait, TriggerClientEvent = SetTimeout, CreateThread, Wait, TriggerClientEvent

local bridge = VavaMagic.bridge
local world = VavaMagic.world
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config.combat
local EVENTS = VavaMagic.EVENTS

local INSERT = 'INSERT INTO `vava_magic_damage_log` (`at`, `spell`, `caster_id`, `target_id`, `kind`, `damage`, `x`, `y`, `z`) VALUES '
local ROW = '(?, ?, ?, ?, ?, ?, ?, ?, ?)'
-- au-delà, les lignes en attente d'une base qui ne répond pas sont abandonnées (journal en console)
local QUEUE_MAX = 500
-- arrêt du module : une seule requête pour tout ce qui attend, dans la limite des paramètres d'une requête préparée
-- (65 535 pour MySQL et MariaDB, 9 par ligne)
local STOP_ROWS = 65535 // 9
-- purge des lignes anciennes : par lots bornés (index sur `at`), une courte pause entre deux lots, une fois par jour
local PURGE = 'DELETE FROM `vava_magic_damage_log` WHERE `at` < ? LIMIT ?'
local PURGE_BATCH = 5000
local PURGE_PAUSE_MS = 1000
local SECONDS_PER_DAY = 86400
local DAY_MS = SECONDS_PER_DAY * 1000

local combat = {}
VavaMagic.combat = combat

combat.KIND = { IMPACT = 'impact', ZONE = 'zone', BURN = 'brulure' }

local queue = {}
-- écriture d'un lot plein déjà demandée (un seul thread à la fois)
local scheduled = false

--- Point dans une zone protégée ?
---@param point table
---@return boolean
function combat.protected(point)
    return geometry.protectedZone(point) ~= nil
end

--- Un sort offensif peut-il toucher ce joueur ? (dégâts entre joueurs activés, personnage en jeu, hors zone
--- protégée, pas à terre : un corps au sol n'est ni mouillé, ni poussé, ni renversé) Renvoie sa position lue côté
--- serveur, ou nil.
---@param target integer
---@return table|nil
function combat.affects(target)
    if not cfg.pvp or not bridge.GetCharacterId(target) then return nil end
    local position = world.position(target)
    if not position or combat.protected(position) then return nil end
    -- en dernier : un appel à vava_health, seulement pour qui serait touché
    if bridge.IsDowned(target) then return nil end
    return position
end

--- La victime d'un sort réagit : geste bref et effet d'écran selon le sort (son élément, ou son champ `reaction`).
---@param target integer
---@param spell string
function combat.react(target, spell)
    local def = VavaMagic.spells.get(spell)
    if def then TriggerClientEvent(EVENTS.HIT, target, def.config.reaction or def.config.element) end
end

--- Écrit en base au plus `limit` lignes en attente, les plus anciennes, en une requête ; refusée, elles reviennent en
--- attente (dans la limite de QUEUE_MAX).
---@param limit integer
local function write(limit)
    if #queue == 0 then return end
    local count = min(#queue, limit)
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

--- Écrit en base un lot de dégâts en attente (une requête, `log.batch` lignes au plus).
function combat.flush()
    write(cfg.log.batch)
end

--- Arrêt du module : tout le journal en attente part, en une seule requête (rien ne dépend d'un thread repris entre
--- deux attentes de la base pendant que la ressource s'arrête).
function combat.flushAll()
    if #queue > STOP_ROWS then
        VavaMagic.log.warn('journal des dégâts : %d ligne(s) au-delà de %d non écrite(s) à l\'arrêt', #queue - STOP_ROWS, STOP_ROWS)
    end
    write(STOP_ROWS)
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
    -- lot plein : écrit à part ; l'appelant peut parcourir les zones, qu'une attente de la base laisserait changer
    -- sous lui (parcours rompu, vérification des zones arrêtée pour de bon)
    if #queue >= cfg.log.batch and not scheduled then
        scheduled = true
        CreateThread(function()
            scheduled = false
            combat.flush()
        end)
    end
    if kind ~= combat.KIND.BURN then combat.react(target, spell) end
    return true
end

--- Retire du journal les lignes plus anciennes que `log.retentionDays` jours, par lots bornés. Bloque le thread
--- appelant (base de données). Renvoie le nombre de lignes retirées.
---@return integer
function combat.purge()
    local days = cfg.log.retentionDays
    if not days or days <= 0 then return 0 end
    local cutoff = time() - floor(days * SECONDS_PER_DAY)
    local removed = 0
    while true do
        local affected, err = bridge.db.update(PURGE, { cutoff, PURGE_BATCH })
        if err then
            VavaMagic.log.warn('journal des dégâts non purgé : %s', tostring(err))
            break
        end
        affected = tonumber(affected) or 0
        removed = removed + affected
        -- lot incomplet : plus rien d'aussi ancien
        if affected < PURGE_BATCH then break end
        Wait(PURGE_PAUSE_MS)
    end
    if removed > 0 then VavaMagic.log.info('journal des dégâts : %d ligne(s) de plus de %d jours retirée(s)', removed, days) end
    return removed
end

--- Écriture régulière du journal ; purge au démarrage, puis une fois par jour. Appelé pendant le setup du module.
function combat.start()
    local function loop()
        combat.flush()
        SetTimeout(cfg.log.flushMs, loop)
    end
    SetTimeout(cfg.log.flushMs, loop)
    local function daily()
        combat.purge()
        SetTimeout(DAY_MS, daily)
    end
    -- dans son propre thread : le setup n'attend pas la base
    CreateThread(daily)
end
