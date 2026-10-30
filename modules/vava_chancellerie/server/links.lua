--[[
    vava_chancellerie/server/links.lua
    Rôle : comptes de jeu que le pont a lui-même vus reliés à un compte du panneau. Un compte n'y entre que lorsqu'un
           joueur a tapé en jeu un code juste (`chancellerie <code>`) et que la Chancellerie l'a confirmé en réponse à
           la demande du pont : la clé du pont ne suffit pas à y ajouter un compte. Le panneau ne donne un rang du
           Conseil (`/staff/sync`) qu'à ces comptes ; retirer un rang reste toujours permis (shared/rules.lua).
           Le panneau applique le rang pendant qu'il répond au pont : une liaison en cours pour le compte est attendue
           (`links.waitMs` au plus) avant de trancher. Gardés en base (`vava_chancellerie_links`), lus au démarrage.
    Dépendances : config.lua, server/core.lua
]]

local ipairs, tointeger, tostring, sub = ipairs, math.tointeger, tostring, string.sub
local CreateThread, SetTimeout = CreateThread, SetTimeout

local core = VavaBridge.core
local cfg = VavaBridge.config.links
local PANEL_ACCOUNT_MAX = 64
local SQL = {
    all = 'SELECT `account_id` FROM `vava_chancellerie_links`',
    remember = 'INSERT INTO `vava_chancellerie_links` (`account_id`, `panel_account`) VALUES (?, ?) '
        .. 'ON DUPLICATE KEY UPDATE `panel_account` = VALUES(`panel_account`), `linked_at` = CURRENT_TIMESTAMP',
}

local links = {}
VavaBridge.links = links

---@type table<integer, boolean>
local known = {}
---@type table<integer, { promise: table, settled: boolean }>  liaison partie vers la Chancellerie, sans réponse encore
local pending = {}

---@param entry { promise: table, settled: boolean }
local function settle(entry)
    if entry.settled then return end
    entry.settled = true
    entry.promise:resolve(true)
end

--- Lit les comptes vus reliés. Appelé pendant le setup.
---@return boolean ok
---@return string|nil err
function links.load()
    local rows, err = core.db.query(SQL.all, {})
    if not rows then return false, tostring(err) end
    for _, row in ipairs(rows) do
        local accountId = tointeger(row.account_id)
        if accountId then known[accountId] = true end
    end
    return true
end

--- Une demande de liaison part vers la Chancellerie pour ce compte de jeu.
---@param accountId integer
function links.begin(accountId)
    if not pending[accountId] then pending[accountId] = { promise = promise.new(), settled = false } end
end

--- Réponse de la Chancellerie à la demande du pont : `linked` si le code était juste (`panelAccount` : le compte du
--- panneau relié, gardé pour mémoire), faux sinon (refus, Chancellerie muette).
---@param accountId integer
---@param linked boolean
---@param panelAccount any
function links.finish(accountId, linked, panelAccount)
    if linked then
        local isNew = not known[accountId]
        known[accountId] = true
        CreateThread(function()
            local _, err = core.db.update(SQL.remember, { accountId, sub(tostring(panelAccount), 1, PANEL_ACCOUNT_MAX) })
            if err then core.log.error('compte n° %d relié, mais non gardé en base : %s', accountId, tostring(err)) end
        end)
        if isNew then core.log.info('compte n° %d relié en jeu à la Chancellerie', accountId) end
    end
    local entry = pending[accountId]
    pending[accountId] = nil
    if entry then settle(entry) end
end

--- Le compte a-t-il été vu relié en jeu ? Une liaison en cours est d'abord attendue (borné). À appeler dans un thread.
---@param accountId integer|nil
---@return boolean
function links.known(accountId)
    if not accountId then return false end
    local entry = pending[accountId]
    if entry and not known[accountId] then
        SetTimeout(cfg.waitMs, function() settle(entry) end)
        Citizen.Await(entry.promise)
    end
    return known[accountId] == true
end
