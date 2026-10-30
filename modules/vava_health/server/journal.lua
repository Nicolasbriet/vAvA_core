--[[
    vava_health/server/journal.lua
    Rôle : journal des coups (table vava_health_hits, sql/0001_hits.sql) : coups venus d'un autre joueur qui ont atteint
           la chaîne (annulés compris) et toutes les mises à terre par la chaîne ou par une perte native. Écrit en base
           par lots (patron de vava_magic/server/combat.lua) : un lot plein s'écrit dans son propre thread (un coup
           n'attend jamais la base), le reste toutes les `journal.flushMs` ; à l'arrêt du module, tout ce qui attend
           part en une seule requête. File bornée : une base qui ne répond pas ne fait pas grossir la mémoire. Les
           lignes plus anciennes que `journal.retentionDays` sont retirées au démarrage puis une fois par jour, par
           lots bornés. Requêtes paramétrées seulement : le texte SQL n'est fait que de morceaux constants (groupes
           de `?`) ; une valeur absente devient NULL par NULLIF, jamais par un trou dans la liste des paramètres (elle
           traverse un export).
    Dépendances : config.lua, server/core.lua
]]

local ipairs, tostring, tonumber, min, floor = ipairs, tostring, tonumber, math.min, math.floor
local time, concat, move = os.time, table.concat, table.move
local SetTimeout, CreateThread, Wait, GetGameTimer = SetTimeout, CreateThread, Wait, GetGameTimer

local cfg = VavaHealth.config.journal

local INSERT = 'INSERT INTO `vava_health_hits` (`at`, `target_id`, `source_id`, `origin`, `kind`, `ref`, `weapon`, '
    .. '`amount`, `applied`, `blocked`, `absorbed`, `resisted`, `cancelled`, `downed`, `x`, `y`, `z`) VALUES '
-- 0 et '' deviennent NULL ; une ligne sans position (ped introuvable) écrit NULL sans paramètre
local ROW_HEAD = "(?, ?, NULLIF(?, 0), ?, ?, NULLIF(?, ''), NULLIF(?, ''), ?, ?, ?, ?, ?, NULLIF(?, ''), ?, "
local ROW_POSITION = ROW_HEAD .. '?, ?, ?)'
local ROW_NO_POSITION = ROW_HEAD .. 'NULL, NULL, NULL)'
local HEAD_PARAMS = 14
-- arrêt du module : une seule requête, dans la limite des paramètres d'une requête préparée (65 535, 17 par ligne)
local STOP_ROWS = 65535 // 17
local PURGE = 'DELETE FROM `vava_health_hits` WHERE `at` < ? LIMIT ?'
local PURGE_BATCH = 5000
local PURGE_PAUSE_MS = 1000
local SECONDS_PER_DAY = 86400
local DAY_MS = SECONDS_PER_DAY * 1000
-- ligne de console d'une file pleine : au plus une par minute
local FULL_LOG_MS = 60000

local journal = {}
VavaHealth.journal = journal

---@class vAvA.HealthHitRow
---@field targetCharacter integer
---@field sourceCharacter integer|nil
---@field origin string
---@field kind string
---@field ref string|nil
---@field weapon string|nil
---@field amount number
---@field applied number
---@field blocked number
---@field absorbed number
---@field resisted number
---@field cancelled string|nil
---@field downed boolean
---@field position { x: number, y: number, z: number }|nil

-- lignes en attente : { template, values }
local queue = {}
-- écriture d'un lot plein déjà demandée (un seul thread à la fois)
local scheduled = false
local dropped, droppedLoggedAt = 0, nil

--- Écrit en base au plus `limit` lignes en attente, les plus anciennes, en une requête ; refusée, elles reviennent en
--- attente (dans la limite de la file).
---@param limit integer
local function write(limit)
    if #queue == 0 then return end
    local count = min(#queue, limit)
    local rows = move(queue, 1, count, 1, {})
    local remaining = {}
    move(queue, count + 1, #queue, 1, remaining)
    queue = remaining
    local params, templates, n = {}, {}, 0
    for i, row in ipairs(rows) do
        templates[i] = row.template
        for _, value in ipairs(row.values) do
            n = n + 1
            params[n] = value
        end
    end
    -- seuls des morceaux constants (groupes de `?`) sont assemblés ; les valeurs passent par params
    local sql = INSERT .. concat(templates, ', ')
    local _, err = VavaHealth.core.db.query(sql, params)
    if err then
        VavaHealth.log.warn('journal des coups non écrit (%d lignes) : %s', count, tostring(err))
        if #queue + count <= cfg.queueMax then move(rows, 1, count, #queue + 1, queue) end
    end
end

--- Écrit un lot en attente (une requête, `journal.batch` lignes au plus).
function journal.flush()
    write(cfg.batch)
end

--- Arrêt du module : tout le journal en attente part, en une seule requête.
function journal.flushAll()
    if #queue > STOP_ROWS then
        VavaHealth.log.warn('journal des coups : %d ligne(s) au-delà de %d non écrite(s) à l\'arrêt',
            #queue - STOP_ROWS, STOP_ROWS)
    end
    write(STOP_ROWS)
end

--- Inscrit un coup. Ne cède jamais la main : un lot plein part dans son propre thread.
---@param row vAvA.HealthHitRow
function journal.add(row)
    if #queue >= cfg.queueMax then
        dropped = dropped + 1
        local now = GetGameTimer()
        if not droppedLoggedAt or now - droppedLoggedAt >= FULL_LOG_MS then
            droppedLoggedAt = now
            VavaHealth.log.warn('journal des coups : file pleine (%d lignes, la base ne suit pas), '
                .. '%d ligne(s) abandonnée(s)', cfg.queueMax, dropped)
            dropped = 0
        end
        return
    end
    local values = {
        time(), row.targetCharacter, row.sourceCharacter or 0, row.origin, row.kind, row.ref or '', row.weapon or '',
        row.amount, row.applied, row.blocked, row.absorbed, row.resisted, row.cancelled or '', row.downed and 1 or 0,
    }
    local template = ROW_NO_POSITION
    local position = row.position
    if position then
        values[HEAD_PARAMS + 1], values[HEAD_PARAMS + 2], values[HEAD_PARAMS + 3] = position.x, position.y, position.z
        template = ROW_POSITION
    end
    queue[#queue + 1] = { template = template, values = values }
    if #queue >= cfg.batch and not scheduled then
        scheduled = true
        CreateThread(function()
            scheduled = false
            journal.flush()
        end)
    end
end

--- Lignes en attente (diagnostic, tests).
---@return integer
function journal.pending()
    return #queue
end

--- Retire les lignes plus anciennes que `journal.retentionDays` jours, par lots bornés. Bloque le thread appelant.
---@return integer removed
function journal.purge()
    local days = cfg.retentionDays
    if not days or days <= 0 then return 0 end
    local cutoff = time() - floor(days * SECONDS_PER_DAY)
    local removed = 0
    while true do
        local affected, err = VavaHealth.core.db.update(PURGE, { cutoff, PURGE_BATCH })
        if err then
            VavaHealth.log.warn('journal des coups non purgé : %s', tostring(err))
            break
        end
        affected = tonumber(affected) or 0
        removed = removed + affected
        if affected < PURGE_BATCH then break end
        Wait(PURGE_PAUSE_MS)
    end
    if removed > 0 then
        VavaHealth.log.info('journal des coups : %d ligne(s) de plus de %d jours retirée(s)', removed, days)
    end
    return removed
end

--- Écriture régulière ; purge au démarrage, puis une fois par jour. Appelé pendant le setup du module.
function journal.start()
    local function loop()
        journal.flush()
        SetTimeout(cfg.flushMs, loop)
    end
    SetTimeout(cfg.flushMs, loop)
    local function daily()
        journal.purge()
        SetTimeout(DAY_MS, daily)
    end
    -- dans son propre thread : le setup n'attend pas la base
    CreateThread(daily)
end
