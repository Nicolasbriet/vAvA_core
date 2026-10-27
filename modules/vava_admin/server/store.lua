--[[
    vava_admin/server/store.lua
    Rôle : accès à la base (seul fichier du module qui écrit du SQL) : membres du Conseil, bans, avertissements,
           journal. Dates calculées et formatées par la base (une seule horloge, celle de MySQL).
    Dépendances : server/core.lua
]]

local tonumber, ipairs = tonumber, ipairs

local store = {}
VavaAdmin.store = store

local DATE = "'%d/%m/%Y %H:%i'"
-- compte 0 : la console (aucun compte) ; une valeur nil en fin de liste de paramètres serait perdue en route
local NO_ACCOUNT = 0
local ACTIVE = '`revoked_at` IS NULL AND (`expires_at` IS NULL OR `expires_at` > NOW())'

local SQL = {
    staffAll = 'SELECT `account_id`, `rank` FROM `vava_admin_staff`',
    staffSet = 'INSERT INTO `vava_admin_staff` (`account_id`, `rank`, `granted_by`) VALUES (?, ?, ?) '
        .. 'ON DUPLICATE KEY UPDATE `rank` = VALUES(`rank`), `granted_by` = VALUES(`granted_by`), `granted_at` = CURRENT_TIMESTAMP',
    staffRemove = 'DELETE FROM `vava_admin_staff` WHERE `account_id` = ?',
    banActive = 'SELECT `id`, `reason`, DATE_FORMAT(`expires_at`, ' .. DATE .. ') AS `until` FROM `vava_admin_bans` '
        .. 'WHERE `account_id` = ? AND ' .. ACTIVE .. ' ORDER BY `id` DESC LIMIT 1',
    banInsert = 'INSERT INTO `vava_admin_bans` (`account_id`, `target_label`, `reason`, `actor_account_id`, `actor_label`, `expires_at`) '
        .. 'VALUES (?, ?, ?, ?, ?, IF(? = 0, NULL, DATE_ADD(NOW(), INTERVAL ? HOUR)))',
    banRevoke = 'UPDATE `vava_admin_bans` SET `revoked_at` = NOW(), `revoked_by` = ? WHERE `account_id` = ? AND `revoked_at` IS NULL',
    bansPage = 'SELECT `id`, `account_id`, `target_label`, `reason`, `actor_label`, DATE_FORMAT(`created_at`, ' .. DATE .. ') AS `created`, '
        .. 'DATE_FORMAT(`expires_at`, ' .. DATE .. ') AS `until` FROM `vava_admin_bans` WHERE ' .. ACTIVE
        .. ' ORDER BY `id` DESC LIMIT ? OFFSET ?',
    warningInsert = 'INSERT INTO `vava_admin_warnings` (`account_id`, `reason`, `actor_label`) VALUES (?, ?, ?)',
    warningsOf = 'SELECT `id`, `reason`, `actor_label`, DATE_FORMAT(`created_at`, ' .. DATE .. ') AS `created` '
        .. 'FROM `vava_admin_warnings` WHERE `account_id` = ? ORDER BY `id` DESC LIMIT ?',
    logInsert = 'INSERT INTO `vava_admin_logs` (`actor_account_id`, `actor_label`, `action`, `target_account_id`, `target_label`, `details`) '
        .. 'VALUES (?, ?, ?, ?, ?, ?)',
    logsPage = 'SELECT `id`, `actor_label`, `action`, `target_label`, `details`, DATE_FORMAT(`created_at`, ' .. DATE .. ') AS `created` '
        .. 'FROM `vava_admin_logs` ORDER BY `id` DESC LIMIT ? OFFSET ?',
    logsPurge = 'DELETE FROM `vava_admin_logs` WHERE `created_at` < DATE_SUB(NOW(), INTERVAL ? DAY)',
}

local function db()
    return VavaAdmin.core.db
end

--- Entiers de la base : oxmysql renvoie parfois des nombres en texte.
---@param rows table[]|nil
---@param fields string[]
---@return table[]|nil
local function integers(rows, fields)
    if not rows then return rows end
    for _, row in ipairs(rows) do
        for _, field in ipairs(fields) do
            if row[field] ~= nil then row[field] = tonumber(row[field]) end
        end
    end
    return rows
end

-- Conseil ------------------------------------------------------------------------------------------------------

---@return table[]|nil rows  { account_id, rank }
---@return string|nil err
function store.staff()
    local rows, err = db().query(SQL.staffAll, {})
    return integers(rows, { 'account_id' }), err
end

---@return boolean ok
---@return string|nil err
function store.setStaff(accountId, rank, grantedBy)
    local _, err = db().update(SQL.staffSet, { accountId, rank, grantedBy or NO_ACCOUNT })
    return err == nil, err
end

function store.removeStaff(accountId)
    local _, err = db().update(SQL.staffRemove, { accountId })
    return err == nil, err
end

-- Bans ---------------------------------------------------------------------------------------------------------

---@return table|nil ban  { id, reason, until? }
---@return string|nil err
function store.activeBan(accountId)
    local row, err = db().single(SQL.banActive, { accountId })
    if row then row.id = tonumber(row.id) end
    return row, err
end

---@param hours integer  0 = définitif
---@return integer|nil id
---@return string|nil err
function store.addBan(accountId, targetLabel, reason, actorAccountId, actorLabel, hours)
    local id, err = db().insert(SQL.banInsert, { accountId, targetLabel, reason, actorAccountId or NO_ACCOUNT, actorLabel, hours, hours })
    return tonumber(id), err
end

---@return integer|nil revoked
---@return string|nil err
function store.revokeBans(accountId, by)
    local affected, err = db().update(SQL.banRevoke, { by, accountId })
    return tonumber(affected), err
end

function store.activeBans(page, size)
    local rows, err = db().query(SQL.bansPage, { size, page * size })
    return integers(rows, { 'id', 'account_id' }), err
end

-- Avertissements et journal ---------------------------------------------------------------------------------------

function store.addWarning(accountId, reason, actorLabel)
    local id, err = db().insert(SQL.warningInsert, { accountId, reason, actorLabel })
    return tonumber(id), err
end

function store.warningsOf(accountId, limit)
    local rows, err = db().query(SQL.warningsOf, { accountId, limit })
    return integers(rows, { 'id' }), err
end

function store.addLog(actorAccountId, actorLabel, action, targetAccountId, targetLabel, details)
    local id, err = db().insert(SQL.logInsert, { actorAccountId or NO_ACCOUNT, actorLabel, action, targetAccountId or NO_ACCOUNT, targetLabel or '', details or '' })
    return tonumber(id), err
end

function store.logs(page, size)
    local rows, err = db().query(SQL.logsPage, { size, page * size })
    return integers(rows, { 'id' }), err
end

function store.purgeLogs(days)
    local affected, err = db().update(SQL.logsPurge, { days })
    return tonumber(affected), err
end
