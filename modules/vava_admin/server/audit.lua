--[[
    vava_admin/server/audit.lua
    Rôle : journal des actions du Conseil. Chaque action est écrite en base (sans faire attendre l'action) et publiée
           par le hook vava_admin:action, auquel le futur panneau web ou une alerte peuvent s'abonner.
    Dépendances : shared/constants.lua, server/core.lua, server/store.lua
]]

local type, pairs, ipairs, tostring, concat, sort = type, pairs, ipairs, tostring, table.concat, table.sort
local CreateThread = CreateThread

local store = VavaAdmin.store
local HOOK_ACTION = VavaAdmin.HOOKS.ACTION
-- longueur de la colonne `details`
local MAX_DETAILS = 1000

local audit = {}
VavaAdmin.audit = audit

---@class vAvA.AdminTarget
---@field source integer|nil
---@field accountId integer|nil
---@field label string

--- Détails lisibles dans le journal : « clé : valeur ; … » (clés triées : écriture stable).
---@param details table|nil
---@return string
local function describe(details)
    if type(details) ~= 'table' then return '' end
    local keys = {}
    for key in pairs(details) do keys[#keys + 1] = key end
    sort(keys)
    local parts = {}
    for i, key in ipairs(keys) do parts[i] = key .. ' : ' .. tostring(details[key]) end
    local text = concat(parts, ' ; ')
    if #text > MAX_DETAILS then text = text:sub(1, MAX_DETAILS) end
    return text
end

--- Libellé et détails d'une action inscrite par un autre module : libellé de 32 caractères au plus, détails
--- { clé = texte ou nombre } bornés. Renvoie les détails nettoyés, ou nil s'ils sont refusés.
---@param label any
---@param details any
---@return table|nil
function audit.clean(label, details)
    local limits = VavaAdmin.LOG_LIMITS
    if type(label) ~= 'string' or #label == 0 or #label > limits.label then return nil end
    local clean, count = {}, 0
    for key, value in pairs(type(details) == 'table' and details or {}) do
        count = count + 1
        local kind = type(value)
        if count > limits.details or type(key) ~= 'string' or #key > limits.label
            or (kind ~= 'string' and kind ~= 'number') or (kind == 'string' and #value > limits.value) then
            return nil
        end
        clean[key] = value
    end
    return clean
end

---@param actor vAvA.AdminActor
---@param action string
---@param target vAvA.AdminTarget|nil
---@param details table|nil
function audit.record(actor, action, target, details)
    local text = describe(details)
    CreateThread(function()
        local id, err = store.addLog(actor.accountId, actor.label, action, target and target.accountId, target and target.label, text)
        if not id then VavaAdmin.log.error('journal non écrit (%s) : %s', action, tostring(err)) end
    end)
    VavaAdmin.core.hooks.runAfter(HOOK_ACTION, {
        actor = { accountId = actor.accountId, label = actor.label, rank = actor.rank.name },
        action = action,
        target = target and { source = target.source, accountId = target.accountId, label = target.label } or nil,
        details = details,
    })
end
