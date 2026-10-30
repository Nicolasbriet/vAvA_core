--[[
    vava_chancellerie/server/links.lua
    Rôle : comptes de jeu que le pont a lui-même vus reliés à un compte du panneau. Un compte n'y entre que lorsqu'un
           joueur a tapé en jeu un code juste (`chancellerie <code>`) et que la Chancellerie l'a confirmé en réponse à
           la demande du pont : la clé du pont ne suffit pas à y ajouter un compte. Il en sort quand le panneau le
           délie (retrait marqué `unlinked`). Le panneau ne donne un rang du Conseil (`/staff/sync`) qu'à ces comptes ;
           retirer un rang reste toujours permis (shared/rules.lua).
           Le panneau applique le rang pendant qu'il répond au pont : une liaison en cours pour le compte est attendue
           avant de trancher, sous une seule échéance par requête (`links.waitMs`, un seul minuteur, posé à la première
           attente). Gardés en base (`vava_chancellerie_links`), lus au démarrage.
    Dépendances : config.lua, server/core.lua
]]

local ipairs, pairs, tointeger, tostring, sub = ipairs, pairs, math.tointeger, tostring, string.sub
local CreateThread, SetTimeout = CreateThread, SetTimeout

local core = VavaBridge.core
local cfg = VavaBridge.config.links
local PANEL_ACCOUNT_MAX = 64
local SQL = {
    all = 'SELECT `account_id` FROM `vava_chancellerie_links`',
    remember = 'INSERT INTO `vava_chancellerie_links` (`account_id`, `panel_account`) VALUES (?, ?) '
        .. 'ON DUPLICATE KEY UPDATE `panel_account` = VALUES(`panel_account`), `linked_at` = CURRENT_TIMESTAMP',
    forget = 'DELETE FROM `vava_chancellerie_links` WHERE `account_id` = ?',
}

local links = {}
VavaBridge.links = links

---@type table<integer, boolean>
local known = {}
---@type table<integer, { waiters: table[] }>  liaison partie vers la Chancellerie, sans réponse encore
local pending = {}

---@class vAvA.BridgeWaiter
---@field promise table
---@field settled boolean

---@param waiter vAvA.BridgeWaiter
local function settle(waiter)
    if waiter.settled then return end
    waiter.settled = true
    waiter.promise:resolve(true)
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
    if not pending[accountId] then pending[accountId] = { waiters = {} } end
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
    if entry then
        for _, waiter in ipairs(entry.waiters) do settle(waiter) end
    end
end

--- Compte délié dans le panneau : le pont l'oublie ; il devra être relié de nouveau en jeu pour recevoir un rang.
---@param accountId integer
function links.forget(accountId)
    if not known[accountId] then return end
    known[accountId] = nil
    CreateThread(function()
        local _, err = core.db.update(SQL.forget, { accountId })
        if err then core.log.error('compte n° %d délié, mais toujours en base : %s', accountId, tostring(err)) end
    end)
    core.log.info('compte n° %d délié de la Chancellerie', accountId)
end

--- Échéance d'une requête : toutes ses attentes de liaison finissent au plus tard `links.waitMs` après la première
--- (un seul minuteur, posé seulement s'il faut attendre).
---@return table deadline
function links.deadline()
    return { started = false, expired = false, waiters = {} }
end

---@param deadline table
local function arm(deadline)
    if deadline.started then return end
    deadline.started = true
    SetTimeout(cfg.waitMs, function()
        deadline.expired = true
        for waiter in pairs(deadline.waiters) do settle(waiter) end
        deadline.waiters = {}
    end)
end

--- Le compte a-t-il été vu relié en jeu ? Une liaison en cours est d'abord attendue, sous l'échéance de la requête.
--- À appeler dans un thread.
---@param accountId integer|nil
---@param deadline table|nil  links.deadline() ; sans elle, aucune attente
---@return boolean
function links.known(accountId, deadline)
    if not accountId then return false end
    local entry = pending[accountId]
    if entry and not known[accountId] and deadline and not deadline.expired then
        arm(deadline)
        local waiter = { promise = promise.new(), settled = false }
        entry.waiters[#entry.waiters + 1] = waiter
        deadline.waiters[waiter] = true
        Citizen.Await(waiter.promise)
        deadline.waiters[waiter] = nil
    end
    return known[accountId] == true
end
