--[[
    vava_admin/server/extensions.lua
    Rôle : outils ajoutés au Registre par d'autres modules (zones de voix…), par le registre du core
           `vava_admin:tools` : clé `<ressource>:<nom>`, { label, hint?, permission }. Une entrée disparaît avec le
           module qui l'a ajoutée. Le Registre les montre dans sa page Outils selon les droits du membre ; ouvrir
           un outil ferme le Registre et prévient le module côté client (hook vava_admin:toolOpened), qui revérifie
           ensuite chaque action côté serveur.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/staff.lua
]]

local pairs, ipairs, sort = pairs, ipairs, table.sort

local staff = VavaAdmin.staff
local cfg = VavaAdmin.config
local REGISTRY = VavaAdmin.REGISTRY_TOOLS
local HOOK_READY = VavaAdmin.HOOKS.TOOLS_READY
local LIMITS = VavaAdmin.TOOL_LIMITS

local extensions = {}
VavaAdmin.extensions = extensions

--- Tous les droits connus, pour borner celui d'un outil.
---@return string[]
local function allPermissions()
    local out = {}
    for _, rank in ipairs(cfg.ranks) do
        for _, permission in ipairs(rank.permissions) do out[#out + 1] = permission end
    end
    return out
end

--- Définit le registre puis prévient les modules qu'ils peuvent y ajouter leurs outils (au démarrage, comme
--- après un redémarrage du Registre : les entrées d'avant ont disparu avec lui).
---@return boolean ok
---@return string|nil err
function extensions.start()
    local core = VavaAdmin.core
    local ok, err = core.registry.define(REGISTRY, {
        schema = { type = 'table', fields = {
            label = { type = 'string', min = 1, max = LIMITS.label },
            hint = { type = 'string', max = LIMITS.hint, optional = true },
            permission = { type = 'string', enum = allPermissions() },
        } },
        maxEntries = LIMITS.entries,
    })
    if not ok then return false, err end
    core.hooks.runAfter(HOOK_READY, {})
    return true
end

--- Outils ouverts à ce membre : liste { key, label, hint }, triée par libellé.
---@param actor vAvA.AdminActor
---@return table[]
function extensions.listFor(actor)
    local out = {}
    for key, entry in pairs(VavaAdmin.core.registry.all(REGISTRY) or {}) do
        if staff.can(actor, entry.permission) then
            out[#out + 1] = { key = key, label = entry.label, hint = entry.hint or '' }
        end
    end
    sort(out, function(a, b) return a.label < b.label end)
    return out
end

--- Un membre peut-il ouvrir cet outil ?
---@param actor vAvA.AdminActor
---@param key string
---@return boolean ok
---@return string|nil code
function extensions.check(actor, key)
    local entry = VavaAdmin.core.registry.get(REGISTRY, key)
    if not entry then return false, 'unknown_tool' end
    if not staff.can(actor, entry.permission) then return false, 'forbidden' end
    return true
end
