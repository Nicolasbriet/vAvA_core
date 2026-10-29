--[[
    vava_magic/server/spells.lua
    Rôle : catalogue des sorts. Chaque sort du module se déclare depuis son fichier (server/spells/<nom>.lua) avec
           `spells.register` ; un autre module en ajoute un par le registre du core `vava_magic:spells` (clé = nom du
           sort), sans toucher au noyau. Un sort fournit sa config (label, niveaux…), les schémas de ses arguments et
           ses fonctions `begin` (validation au début de l'incantation), `finish` (effet à la fin) et `cancel` ; un sort
           du module peut aussi fournir `started` (incantation acceptée : tous les contrôles passés, mana comprise).
           Les RPC de chaque sort (début et fin) sont ouvertes par server/casting.lua. Un sort du module peut aussi
           déclarer ses intentions propres (`addRpc`, ouvertes au démarrage) et son ménage au départ d'un joueur
           (`onLeave`) ou à l'arrêt du module (`onStop`) : main.lua n'a jamais à changer pour un nouveau sort.
    Dépendances : shared/, config.lua, server/core.lua
]]

local type, pairs, ipairs, tostring, pcall = type, pairs, ipairs, tostring, pcall
local mathType = math.type
local sort = table.sort

local core = VavaMagic.core
local progression = VavaMagic.progression
local ELEMENTS = VavaMagic.config.elements
local SPELL_TYPES = VavaMagic.SPELL_TYPES
local AIM_KINDS = VavaMagic.AIM_KINDS
local REGISTRY = VavaMagic.SPELLS_REGISTRY
local RESOURCE = VavaMagic.resource
local MAX_LEVEL = progression.MAX_LEVEL

local spells = {}
VavaMagic.spells = spells

---@class vAvA.MagicSpell
---@field name string
---@field owner string           ressource qui l'a déclaré
---@field config table           label, element, type, icon, aim, levels, baseCost, xp, hitXp?, moveSpeed?, order?
---@field beginArgs table[]      schémas des arguments du début (après le nom du sort)
---@field finishArgs table[]     schémas des arguments de la fin (après le numéro d'incantation)
---@field begin fun(ctx: table, ...): boolean, any
---@field finish fun(ctx: table, ...): table|false, string|nil
---@field cancel? fun(ctx: table)
---@field started? fun(ctx: table)  incantation acceptée (sorts du module seulement)

---@type table<string, vAvA.MagicSpell>
local defs = {}
---@type { name: string, args: table[], rateLimit: table, handler: function }[]  intentions propres aux sorts du module
local extraRpcs = {}

---@param value any
---@return boolean
local function isCount(value)
    return mathType(value) == 'integer' and value >= 0
end

--- Config d'un sort : champs communs que le noyau lit. Renvoie true, ou false et la raison.
---@param config any
---@return boolean ok
---@return string|nil reason
function spells.validate(config)
    if type(config) ~= 'table' then return false, 'config attendue' end
    if type(config.label) ~= 'string' or config.label == '' then return false, 'label attendu' end
    if not ELEMENTS[config.element] then return false, 'element inconnu' end
    if not SPELL_TYPES[config.type] then return false, 'type attendu (projectile, zone, utilitaire)' end
    if type(config.icon) ~= 'string' or not config.icon:find('^[%w_]+$') then return false, 'icon attendu' end
    if type(config.aim) ~= 'table' or not AIM_KINDS[config.aim.kind] then return false, 'aim.kind attendu' end
    if config.hitXp ~= nil and (type(config.hitXp) ~= 'number' or config.hitXp < 0) then return false, 'hitXp invalide' end
    if type(config.baseCost) ~= 'number' or config.baseCost < 0 then return false, 'baseCost attendu' end
    if type(config.xp) ~= 'number' or config.xp < 0 then return false, 'xp attendu' end
    if config.moveSpeed ~= nil and (type(config.moveSpeed) ~= 'number' or config.moveSpeed < 0) then return false, 'moveSpeed invalide' end
    if type(config.levels) ~= 'table' or #config.levels ~= MAX_LEVEL then return false, ('%d niveaux attendus'):format(MAX_LEVEL) end
    for index, level in ipairs(config.levels) do
        if type(level) ~= 'table' or not isCount(level.castMs) or not isCount(level.cooldownMs)
            or type(level.description) ~= 'string' or type(level.unlock) ~= 'string' then
            return false, ('niveau %d : castMs, cooldownMs, description et unlock attendus'):format(index)
        end
    end
    return true
end

--- Déclare un sort. Ses RPC sont ouvertes dès que le module est prêt.
---@param name string
---@param def table
---@param owner? string  ressource déclarante (défaut : ce module)
---@return boolean ok
---@return string|nil err
function spells.register(name, def, owner)
    if type(name) ~= 'string' or not name:find('^[%w_]+$') or #name > 32 then return false, 'nom de sort invalide' end
    if defs[name] then return false, ("sort '%s' déjà déclaré"):format(name) end
    local ok, reason = spells.validate(def.config)
    if not ok then return false, ("sort '%s' : %s"):format(name, reason) end
    if type(def.begin) ~= 'function' and type(def.begin) ~= 'table' then return false, ("sort '%s' : begin attendu"):format(name) end
    if type(def.finish) ~= 'function' and type(def.finish) ~= 'table' then return false, ("sort '%s' : finish attendu"):format(name) end
    defs[name] = {
        name = name, owner = owner or RESOURCE, config = def.config,
        beginArgs = def.beginArgs or {}, finishArgs = def.finishArgs or {},
        begin = def.begin, finish = def.finish, cancel = def.cancel, started = def.started,
    }
    if VavaMagic.ready then return VavaMagic.casting.expose(name) end
    return true
end

--- Retire un sort (module déclarant arrêté) : ses RPC sont fermées, ses incantations en cours annulées.
---@param name string
function spells.unregister(name)
    if not defs[name] then return end
    VavaMagic.casting.hide(name)
    defs[name] = nil
end

---@param name string
---@return vAvA.MagicSpell|nil
function spells.get(name)
    return defs[name]
end

---@return table<string, vAvA.MagicSpell>
function spells.all()
    return defs
end

--- Noms des sorts, dans l'ordre du grimoire.
---@return string[]
function spells.names()
    local names = {}
    for name in pairs(defs) do names[#names + 1] = name end
    sort(names, function(a, b)
        local oa, ob = defs[a].config.order or 1000, defs[b].config.order or 1000
        if oa ~= ob then return oa < ob end
        return a < b
    end)
    return names
end

--- Config des sorts déclarés par d'autres modules : le client ne connaît que ceux du fichier config.lua.
---@return table<string, table>
function spells.catalog()
    local catalog = {}
    for name, def in pairs(defs) do
        if def.owner ~= RESOURCE then catalog[name] = def.config end
    end
    return catalog
end

---@type function[]  à appeler au départ d'un joueur (lumières, orbes, brûlures…)
local leaveHandlers = {}
---@type function[]  à appeler à l'arrêt du module (objets créés par le serveur)
local stopHandlers = {}
---@type function[]  nettoyage d'urgence du Conseil : zones, remparts, orbes (chacun renvoie ce qu'il a retiré)
local cleanupHandlers = {}

--- Ménage d'un sort au départ d'un joueur : `handler(source)`.
---@param handler fun(source: integer)
function spells.onLeave(handler)
    leaveHandlers[#leaveHandlers + 1] = handler
end

--- Ménage d'un sort à l'arrêt du module.
---@param handler fun()
function spells.onStop(handler)
    stopHandlers[#stopHandlers + 1] = handler
end

--- Nettoyage d'urgence (commande du Conseil) : `handler()` retire ses effets du monde et renvoie leur nombre.
---@param handler fun(): integer
function spells.onCleanup(handler)
    cleanupHandlers[#cleanupHandlers + 1] = handler
end

--- Retire du monde tous les effets des sorts. Renvoie le nombre retiré.
---@return integer
function spells.cleanup()
    local total = 0
    for _, handler in ipairs(cleanupHandlers) do
        local ok, count = pcall(handler)
        if not ok then
            VavaMagic.log.error('nettoyage en erreur : %s', tostring(count))
        elseif mathType(count) == 'integer' then
            total = total + count
        end
    end
    return total
end

---@param src integer
function spells.leave(src)
    for _, handler in ipairs(leaveHandlers) do
        local ok, err = pcall(handler, src)
        if not ok then VavaMagic.log.error('ménage de départ en erreur : %s', tostring(err)) end
    end
end

function spells.stop()
    for _, handler in ipairs(stopHandlers) do
        local ok, err = pcall(handler)
        if not ok then VavaMagic.log.error("ménage d'arrêt en erreur : %s", tostring(err)) end
    end
end

--- Intention propre à un sort du module (éteindre une lueur, impact d'un projectile…), ouverte au démarrage.
---@param name string       nom de RPC (préfixé par la ressource)
---@param args table[]      schémas des arguments
---@param rateLimit table
---@param handler function
function spells.addRpc(name, args, rateLimit, handler)
    extraRpcs[#extraRpcs + 1] = { name = name, args = args, rateLimit = rateLimit, handler = handler }
end

--- Registre du core pour les sorts d'autres modules, intentions propres aux sorts. Appelé pendant le setup.
---@return boolean ok
---@return string|nil err
function spells.start()
    for _, rpc in ipairs(extraRpcs) do
        local opened, rpcErr = core.rpc.register(rpc.name, { args = rpc.args, rateLimit = rpc.rateLimit }, rpc.handler)
        if not opened then return false, rpcErr end
    end
    local ok, err = core.registry.define(REGISTRY, {
        schema = { type = 'table', fields = {
            config = { type = 'table', fields = {}, strict = false },
            beginArgs = { type = 'array', items = { type = 'any' }, optional = true },
            finishArgs = { type = 'array', items = { type = 'any' }, optional = true },
            begin = { type = 'function' },
            finish = { type = 'function' },
            cancel = { type = 'function', optional = true },
        } },
        validator = function(key, data)
            if defs[key] then return false, 'sort déjà déclaré' end
            return spells.validate(data.config)
        end,
    })
    if not ok then return false, err end
    for _, def in ipairs({
        { 'core:registry:added', function(payload)
            if payload.registry ~= REGISTRY or payload.owner == RESOURCE then return end
            local entry = core.registry.get(REGISTRY, payload.key)
            if not entry then return end
            local registered, registerErr = spells.register(payload.key, entry, payload.owner)
            if not registered then VavaMagic.log.warn('sort de %s refusé : %s', tostring(payload.owner), tostring(registerErr)) end
        end },
        { 'core:registry:removed', function(payload)
            if payload.registry == REGISTRY then spells.unregister(payload.key) end
        end },
    }) do
        local id, hookErr = core.hooks.after(def[1], def[2])
        if not id then return false, hookErr end
    end
    return true
end
