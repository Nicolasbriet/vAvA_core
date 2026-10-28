--[[
    vava_codex/server/prefs.lua
    Rôle : préférences du Codex par personnage, dans un champ de personnage du core (écrit en base avec lui, visible
           du seul joueur) : signets (favoris, bornés), dernières pages (commandes lancées, les plus récentes en tête,
           sans doublon), réglage « rester ouvert après Lancer ».
    Dépendances : shared/constants.lua, config.lua, server/core.lua, bridge/server.lua
]]

local ipairs, type = ipairs, type
local time = os.time

local core = VavaCodex.core
local bridge = VavaCodex.bridge
local cfg = VavaCodex.config
local FIELD = VavaCodex.PREFS_FIELD
local MAX_NAME, MAX_ACTION = VavaCodex.MAX_NAME, VavaCodex.MAX_ACTION

local prefs = {}
VavaCodex.prefs = prefs

---@return table
local function default()
    return { favorites = {}, recent = {}, keepOpen = cfg.keepOpenDefault }
end

--- Déclare le champ. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function prefs.define()
    return core.characters.defineField(FIELD, {
        schema = {
            type = 'table',
            fields = {
                favorites = { type = 'array', max = cfg.favorites.max, items = { type = 'string', min = 1, max = MAX_NAME } },
                recent = { type = 'array', max = cfg.recent.max, items = {
                    type = 'table',
                    fields = {
                        name = { type = 'string', min = 1, max = MAX_NAME },
                        action = { type = 'string', min = 1, max = MAX_ACTION, optional = true },
                        at = { type = 'integer', min = 0 },
                    },
                } },
                keepOpen = { type = 'boolean' },
            },
        },
        default = default(),
        visibility = 'owner',
    })
end

--- Préférences du joueur (copie défensive : les tableaux reviennent toujours comme des listes).
---@param src integer
---@return table|nil prefs
---@return integer|nil characterId
function prefs.get(src)
    local characterId = bridge.GetCharacterId(src)
    if not characterId then return nil end
    local value = core.characters.get(characterId, FIELD)
    if type(value) ~= 'table' then value = default() end
    local out = default()
    for i, name in ipairs(value.favorites or {}) do out.favorites[i] = name end
    for i, entry in ipairs(value.recent or {}) do out.recent[i] = { name = entry.name, action = entry.action, at = entry.at } end
    if type(value.keepOpen) == 'boolean' then out.keepOpen = value.keepOpen end
    return out, characterId
end

---@param src integer
---@param mutate fun(current: table): boolean, string?
---@return boolean ok
---@return string|nil code
---@return table|nil prefs
local function update(src, mutate)
    local current, characterId = prefs.get(src)
    if not current then return false, 'no_character' end
    local accepted, code = mutate(current)
    if not accepted then return false, code end
    local ok, err = core.characters.set(characterId, FIELD, current)
    if not ok then return false, err end
    return true, nil, current
end

--- Pose ou retire un signet.
---@param src integer
---@param name string
---@param on boolean
---@return boolean ok
---@return string|nil code
---@return table|nil prefs
function prefs.setFavorite(src, name, on)
    return update(src, function(current)
        local list = {}
        for _, entry in ipairs(current.favorites) do
            if entry ~= name then list[#list + 1] = entry end
        end
        if on then
            if #list >= cfg.favorites.max then return false, 'favorites_full' end
            list[#list + 1] = name
        end
        current.favorites = list
        return true
    end)
end

--- Note une commande lancée : en tête des dernières pages, sans doublon, liste bornée.
---@param src integer
---@param name string
---@param action string|nil
---@return boolean ok
---@return string|nil code
---@return table|nil prefs
function prefs.pushRecent(src, name, action)
    return update(src, function(current)
        local list = { { name = name, action = action, at = time() } }
        for _, entry in ipairs(current.recent) do
            if (entry.name ~= name or (entry.action or '') ~= (action or '')) and #list < cfg.recent.max then list[#list + 1] = entry end
        end
        current.recent = list
        return true
    end)
end

---@param src integer
---@param keepOpen boolean
---@return boolean ok
---@return string|nil code
---@return table|nil prefs
function prefs.setKeepOpen(src, keepOpen)
    return update(src, function(current)
        current.keepOpen = keepOpen
        return true
    end)
end
