--[[
    vava_pause/client/settings.lua
    Rôle : réglages du joueur, gardés sur sa machine (stockage local de FiveM, pour tous ses personnages), jamais
           envoyés au serveur : lus au démarrage (lecture tolérante, shared/settings.lua), changés depuis la page,
           remis aux défauts ; chaque changement est écrit aussitôt et publié par le crochet local
           `vava_pause:settingChanged` ({ key, value }) aux modules qui l'appliquent (vava_hud, vava_voice). Exports
           client `setting(clé)` et `settings()`.
    Dépendances : shared/constants.lua, config_client.lua, shared/settings.lua, client/core.lua, client/sources.lua
]]

local pairs, ipairs = pairs, ipairs
local GetResourceKvpString, SetResourceKvp = GetResourceKvpString, SetResourceKvp
local encode, decode = json.encode, json.decode

local core = VavaPause.core
if not core then return end

local cfg = VavaPause.config.settings
local rules = VavaPause.settings
local sources = VavaPause.sources
local HOOK_CHANGED = VavaPause.HOOKS.SETTING_CHANGED
local LIST = cfg.list

local store = {}
VavaPause.store = store

local values = rules.read(GetResourceKvpString(cfg.kvp), LIST, decode)

local function save()
    SetResourceKvp(cfg.kvp, encode(rules.encodable(values, LIST)))
end

---@param key string
---@param value any
local function publish(key, value)
    core.hooks.runAfter(HOOK_CHANGED, { key = key, value = value })
end

--- Copie des valeurs effectives.
---@return table<string, any>
function store.values()
    local copy = {}
    for key, value in pairs(values) do copy[key] = value end
    return copy
end

--- Définitions montrées à la page : réglages dont une ressource de `uses` tourne.
---@return table[]
function store.definitions()
    return rules.visible(LIST, sources.started)
end

--- Change un réglage : `true, valeur` ou `false, code` (unknown_setting, invalid_value).
---@param key any
---@param value any
---@return boolean ok
---@return any valueOrCode
function store.set(key, value)
    local ok, clean = rules.validate(LIST, key, value)
    if not ok then return false, clean end
    if values[key] ~= clean then
        values[key] = clean
        save()
        publish(key, clean)
    end
    return true, clean
end

--- Remet chaque réglage à son défaut ; seuls les réglages changés sont publiés.
---@return table<string, any> values
function store.reset()
    local defaults = rules.defaults(LIST)
    local changed = {}
    for key, value in pairs(defaults) do
        if values[key] ~= value then changed[#changed + 1] = key end
    end
    values = defaults
    save()
    for _, key in ipairs(changed) do publish(key, values[key]) end
    return store.values()
end

--- Valeur effective d'un réglage, ou nil (clé inconnue).
exports('setting', function(key)
    return values[key]
end)

--- Copie { [clé] = valeur } de tous les réglages.
exports('settings', function()
    return store.values()
end)
