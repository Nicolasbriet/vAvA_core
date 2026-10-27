--[[
    vava_chat/server/logs.lua
    Rôle : journal du chat pour la modération : les genres choisis dans la config sont mis en file et écrits par lots
           (une seule requête pour tout un lot), au plus tard toutes les `log.flushMs` ; un lot refusé par la base est
           gardé pour l'essai suivant (dans la limite `log.maxQueued`). Ce qui a plus de `log.retentionDays` jours est
           effacé au démarrage puis régulièrement, par tranches pour ne jamais bloquer la table.
    Dépendances : config.lua, server/core.lua
]]

local tonumber, tostring, floor, min, max, osTime = tonumber, tostring, math.floor, math.min, math.max, os.time
local concat, move, remove = table.concat, table.move, table.remove
local CreateThread, Wait = CreateThread, Wait

local core = VavaChat.core
if not core then return end

local cfg = VavaChat.config.log
local DAY = 86400
local INSERT = 'INSERT INTO `vava_chat_logs` (`at`, `kind`, `character_id`, `author`, `target_id`, `target`, `recipients`, `message`) VALUES '
local ROW = '(?, ?, ?, ?, ?, ?, ?, ?)'
-- taille de tranche : entier de la config, écrit dans la requête (jamais une valeur venue d'un joueur)
local PURGE = ('DELETE FROM `vava_chat_logs` WHERE `at` < ? LIMIT %d'):format(floor(cfg.purgeBatch))

local logs = {}
VavaChat.logs = logs

---@type table[]
local queue = {}
local writing = false

--- Une requête pour tout un lot.
---@param rows table[]
---@return integer|nil id
---@return string|nil err
local function insert(rows)
    local values, params = {}, {}
    for i = 1, #rows do
        local row = rows[i]
        values[i] = ROW
        local n = #params
        params[n + 1] = row.at
        params[n + 2] = row.kind
        params[n + 3] = row.characterId
        params[n + 4] = row.author
        params[n + 5] = row.targetId
        params[n + 6] = row.target
        params[n + 7] = row.recipients
        params[n + 8] = row.message
    end
    return core.db.insert(INSERT .. concat(values, ', '), params)
end

--- Écrit un lot ; refusé par la base, il est remis en tête de file (au-delà de la limite, les plus anciens sont perdus).
---@param rows table[]
---@return boolean written
local function write(rows)
    local id, err = insert(rows)
    if id then return true end
    VavaChat.log.error('journal du chat non écrit (%d messages) : %s', #rows, tostring(err))
    local dropped = max(0, #rows + #queue - cfg.maxQueued)
    local merged = move(rows, dropped + 1, #rows, 1, {})
    move(queue, 1, #queue, #merged + 1, merged)
    queue = merged
    return false
end

--- Retire de la file le prochain lot (au plus `log.batch` messages).
---@return table[]
local function take()
    local count = min(#queue, cfg.batch)
    local rows = move(queue, 1, count, 1, {})
    queue = move(queue, count + 1, #queue, 1, {})
    return rows
end

--- Écrit le prochain lot sans attendre (rien si la file est vide ou si un lot est déjà en route).
function logs.flush()
    if writing or #queue == 0 then return end
    local rows = take()
    writing = true
    CreateThread(function()
        write(rows)
        writing = false
    end)
end

--- Arrêt du module : toute la file part en une requête, remise à oxmysql avant que le module s'arrête. FiveM ne dit
--- pas qui, du core ou du module, apprend l'arrêt en premier : si le core a déjà fermé l'accès à la base, les
--- derniers messages (au plus `log.flushMs`) sont perdus, et la console le dit.
function logs.flushAll()
    if #queue == 0 then return end
    local rows = queue
    queue = {}
    local id, err = insert(rows)
    if not id then VavaChat.log.warn('%d message(s) du journal non écrit(s) à l\'arrêt : %s', #rows, tostring(err)) end
end

--- Ajoute un message au journal.
---@param kind string
---@param characterId integer
---@param author string
---@param targetId integer   0 sans destinataire désigné
---@param target string      '' sans destinataire désigné
---@param recipients integer
---@param message string
function logs.push(kind, characterId, author, targetId, target, recipients, message)
    if #queue >= cfg.maxQueued then remove(queue, 1) end
    queue[#queue + 1] = {
        at = osTime(), kind = kind, characterId = characterId, author = author, targetId = targetId, target = target,
        recipients = recipients, message = message,
    }
    if #queue >= cfg.batch then logs.flush() end
end

--- Efface ce qui a passé la durée de garde, par tranches.
function logs.purge()
    CreateThread(function()
        local before = osTime() - cfg.retentionDays * DAY
        while true do
            local count, err = core.db.update(PURGE, { before })
            if not count then
                VavaChat.log.warn('journal du chat non purgé : %s', tostring(err))
                return
            end
            if (tonumber(count) or 0) < cfg.purgeBatch then return end
            Wait(cfg.purgePauseMs)
        end
    end)
end

--- Écritures et purges régulières.
function logs.start()
    logs.purge()
    CreateThread(function()
        local sincePurge = 0
        while true do
            Wait(cfg.flushMs)
            logs.flush()
            sincePurge = sincePurge + cfg.flushMs
            if sincePurge >= cfg.purgeEveryMs then
                sincePurge = 0
                logs.purge()
            end
        end
    end)
end
