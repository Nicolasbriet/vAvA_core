--[[
    server/core/commands.lua
    Rôle : registre `core:commands` : chaque module y déclare ses commandes (à taper) et ses touches (RegisterKeyMapping)
           avec leur public (joueur, droit du Conseil, console), leurs sous-commandes et leurs arguments typés. Le core
           ne fait que tenir le registre : le Codex (vava_codex) le lit pour afficher, composer et lancer, et le chat
           pour ses suggestions. Les commandes elles-mêmes restent enregistrées et contrôlées par leur module.
    Dépendances : shared/init.lua, server/core/registry.lua
]]

local ipairs = ipairs
local format = string.format

local registry = vAvA.registry

local REGISTRY = 'core:commands'

local commands = { REGISTRY = REGISTRY }
vAvA.commands = commands

-- Un argument d'une commande ou d'une sous-commande. `type` :
--   player   : joueur en jeu (numéro de session)            account : numéro de compte (console)
--   integer / number : valeur bornée par min, max (et step)  text : libre ; `rest` : prend tout le reste de la ligne
--   choice   : une valeur parmi `choices` (libellés facultatifs dans `labels`)
--   registry : une clé d'un registre du core (`registry`), affichée par son champ `labelField` (défaut : label)
--   list     : une valeur fournie par l'export `codexList(list)` du module déclarant : { { value, label }, … }
local ARG = {
    type = 'table',
    fields = {
        name = { type = 'string', min = 1, max = 32 },
        type = { type = 'string', enum = { 'player', 'account', 'integer', 'number', 'text', 'choice', 'registry', 'list' } },
        optional = { type = 'boolean', optional = true },
        rest = { type = 'boolean', optional = true },
        min = { type = 'number', optional = true },
        max = { type = 'number', optional = true },
        step = { type = 'number', optional = true },
        choices = { type = 'array', min = 1, max = 64, items = { type = 'string', min = 1, max = 32 }, optional = true },
        labels = { type = 'map', max = 64, key = { type = 'string' }, value = { type = 'string', max = 64 }, optional = true },
        registry = { type = 'string', min = 1, max = 64, optional = true },
        labelField = { type = 'string', min = 1, max = 32, optional = true },
        list = { type = 'string', min = 1, max = 32, optional = true },
        hint = { type = 'string', max = 120, optional = true },
    },
}

-- Une sous-commande (`/metiers niveau …`) ; sans `id`, la forme nue de la commande.
local ACTION = {
    type = 'table',
    fields = {
        id = { type = 'string', min = 1, max = 32, optional = true },
        label = { type = 'string', min = 1, max = 64 },
        description = { type = 'string', max = 240, optional = true },
        permission = { type = 'string', min = 1, max = 32, optional = true },
        args = { type = 'array', max = 8, items = ARG, optional = true },
    },
}

-- Une entrée : la clé du registre est le nom de la commande (sans « / », sans « + »).
local SCHEMA = {
    type = 'table',
    fields = {
        kind = { type = 'string', enum = { 'command', 'key' } },            -- commande à taper, ou touche
        module = { type = 'string', min = 1, max = 48 },                    -- ressource qui la déclare
        chapter = { type = 'string', min = 1, max = 32 },                   -- chapitre du Codex (« Récolte »)
        label = { type = 'string', min = 1, max = 64 },
        description = { type = 'string', max = 240, optional = true },
        scope = { type = 'string', enum = { 'player', 'admin', 'console' } },  -- tout le monde, Conseil, console
        permission = { type = 'string', min = 1, max = 32, optional = true },  -- droit vava_admin (scope admin)
        ace = { type = 'string', min = 1, max = 64, optional = true },         -- repli ACE sans vava_admin
        key = { type = 'string', min = 1, max = 24, optional = true },         -- touche par défaut (RegisterKeyMapping)
        keyDevice = { type = 'string', min = 1, max = 24, optional = true },   -- keyboard (défaut), MOUSE_BUTTON, MOUSE_WHEEL
        keyDisplay = { type = 'string', min = 1, max = 24, optional = true },  -- nom montré (« Clic droit », « 1 à 5 »)
        hold = { type = 'boolean', optional = true },                          -- commande +/− (appui et relâchement)
        ui = { type = 'boolean', optional = true },                            -- ouvre une interface : le Codex se ferme avant
        hidden = { type = 'boolean', optional = true },
        actions = { type = 'array', min = 1, max = 24, items = ACTION, optional = true },
        args = { type = 'array', max = 8, items = ARG, optional = true },
    },
}

---@param args table[]|nil
---@param where string
---@return boolean ok
---@return string|nil err
local function checkArgs(args, where)
    if not args then return true end
    for i, arg in ipairs(args) do
        if arg.type == 'choice' and not arg.choices then return false, format('%s : argument « %s » de type choice sans choices', where, arg.name) end
        if arg.type == 'registry' and not arg.registry then return false, format('%s : argument « %s » de type registry sans registry', where, arg.name) end
        if arg.type == 'list' and not arg.list then return false, format('%s : argument « %s » de type list sans list', where, arg.name) end
        if arg.rest and (arg.type ~= 'text' or i ~= #args) then
            return false, format('%s : « %s » : rest ne vaut que pour un texte en dernière position', where, arg.name)
        end
    end
    return true
end

--- Cohérence d'une entrée au-delà du schéma : touche avec sa touche, actions ou args (pas les deux), identifiants
--- d'actions uniques et une seule forme nue, arguments complets selon leur type.
---@param key string
---@param data table
---@return boolean ok
---@return string|nil err
local function validate(key, data)
    if data.kind == 'key' and not data.key then return false, 'une touche doit indiquer `key`' end
    if data.actions and data.args then return false, 'actions et args sont exclusifs (une action sans id est la forme nue)' end
    local seen, bare = {}, false
    for _, action in ipairs(data.actions or {}) do
        if action.id then
            if seen[action.id] then return false, format("sous-commande '%s' déclarée deux fois", action.id) end
            seen[action.id] = true
        else
            if bare then return false, 'deux actions sans id' end
            bare = true
        end
        local ok, err = checkArgs(action.args, action.id and ('action ' .. action.id) or 'forme nue')
        if not ok then return false, err end
    end
    return checkArgs(data.args, key)
end

local ok, err = registry.define(vAvA.CORE_OWNER, REGISTRY, { schema = SCHEMA, validator = validate })
if not ok then
    vAvA.logger.create('commands').error('registre des commandes non défini : %s', tostring(err))
end

--- Déclare une commande ou une touche du core lui-même.
---@param name string
---@param def table
---@return boolean ok
---@return string|nil err
function commands.declare(name, def)
    def.module, def.chapter = def.module or vAvA.resourceName, def.chapter or 'Core'
    return registry.add(vAvA.CORE_OWNER, REGISTRY, name, def)
end
