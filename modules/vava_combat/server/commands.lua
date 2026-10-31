--[[
    vava_combat/server/commands.lua
    Rôle : commandes du Conseil `/armes liste | voir <n°> | user <n°> <points>` (droit `metiers` de vava_admin, sinon
           ACE `combat.admin`, revérifié à chaque appel ; console admise) et leur déclaration au registre
           `core:commands` (chapitre « Combat »). `voir` et `user` sont inscrits au journal du Registre ; `user` ne fait
           que BAISSER la solidité (la garde de l'artisanat refuserait toute remontée), seuils prévenus comme une usure.
           Réponses au seul lanceur (vava_chat, sinon notification ; console : print).
    Dépendances : shared/constants.lua, config.lua, shared/weapons.lua, shared/shield.lua, server/core.lua,
                  bridge/server.lua, server/catalog.lua, server/wear.lua, server/shields.lua
]]

local type, tostring, tonumber, ipairs, pairs = type, tostring, tonumber, ipairs, pairs
local tointeger, floor = math.tointeger, math.floor
local format = string.format

local bridge = VavaCombat.bridge
local weapons = VavaCombat.weapons
local catalog = VavaCombat.catalog
local wear = VavaCombat.wear
local shields = VavaCombat.shields
local cfg = VavaCombat.config
local SHIELD = VavaCombat.SHIELD_CATEGORY
local REGISTRY = 'core:commands'
local CHAPTER = 'Combat'

local commands = {}
VavaCombat.commands = commands

local function entries()
    local admin = cfg.admin
    return {
        [admin.command] = { kind = 'command', scope = 'admin', permission = admin.permission, ace = admin.ace,
            label = 'Armes du royaume', description = 'Les armes de corps à corps, l\'arme d\'un joueur, et son usure pour les essais.',
            actions = {
                { id = 'liste', label = 'Liste des armes', description = 'Chaque arme, sa catégorie, son type, son coup et sa solidité.' },
                { id = 'voir', label = 'Arme d\'un joueur', description = 'Arme en main et bouclier accroché (inscrit au journal).',
                    args = { { name = 'joueur', type = 'player' } } },
                { id = 'user', label = 'User une arme', description = 'Baisse la solidité de l\'arme en main (inscrit au journal).',
                    args = { { name = 'joueur', type = 'player' }, { name = 'points', type = 'integer', min = 1, max = admin.maxWear } } },
            } },
    }
end

--- Déclare la commande au registre du core. Appelée en tête du setup ; sans ce registre (core plus ancien), rien.
---@return boolean ok
---@return string|nil err
function commands.declare()
    local core = VavaCombat.core
    if not core.registry.exists(REGISTRY) then return true end
    for name, def in pairs(entries()) do
        def.module, def.chapter = VavaCombat.resource, CHAPTER
        local ok, err = core.registry.add(REGISTRY, name, def)
        if not ok then return false, format('%s : %s', name, tostring(err)) end
    end
    return true
end

---@param value number
---@return string
local function number(value)
    local rounded = weapons.tenth(value)
    if rounded == floor(rounded) then return tostring(floor(rounded)) end
    return (tostring(rounded):gsub('%.', ','))
end

---@param source integer
---@param text string
local function reply(source, text)
    bridge.Chat(source, text)
end

--- /armes liste : en-tête et une ligne par arme, regroupées en aussi peu de messages que possible (bridge.ChatLines).
---@param source integer
local function list(source)
    local messages = cfg.messages
    local all = catalog.list()
    local lines = { format(messages.listHeader, #all) }
    for _, def in ipairs(all) do
        lines[#lines + 1] = format(messages.list, def.label, cfg.categories[def.category].label,
            cfg.kindLabels[def.kind] or def.kind, number(def.damage), def.durability,
            def.provisional and messages.provisional or '')
    end
    bridge.ChatLines(source, lines)
end

--- Joueur ciblé (en jeu, avec un personnage), ou nil.
---@param value any
---@return integer|nil
local function targetOf(value)
    local target = tointeger(tonumber(value))
    if not target or target <= 0 or not bridge.ActiveCharacterId(target) then return nil end
    return target
end

--- Arme du catalogue tenue en main par un joueur : pile, fiche ; ou nil.
---@param target integer
---@return table|nil held
---@return table|nil def
local function heldWeapon(target)
    local held = bridge.Held(target)
    local def = held and catalog.weapon(held.item)
    if not def or def.category == SHIELD then return nil, nil end
    return held, def
end

--- /armes voir <n°>
---@param source integer
---@param target integer
local function inspect(source, target)
    local messages = cfg.messages
    local held, def = heldWeapon(target)
    local details = { cible = target }
    if held then
        local meta = type(held.metadata) == 'table' and held.metadata or {}
        local d = weapons.durabilityOf(meta, def)
        local amount = weapons.amount(def, meta, 1, cfg)
        reply(source, format(messages.inspect, target, def.label, weapons.quality(meta.quality, cfg) // 1,
            tostring(meta.tier or '—'), d.current, d.max, number(def.damage), number(amount), d.dull and messages.dullSuffix or ''))
        details.objet = held.item
    else
        reply(source, format(messages.inspectNone, target))
    end
    local view = shields.view(target)
    if view then
        local def2 = catalog.weapon(view.item)
        reply(source, format(messages.inspectShield, def2 and def2.label or view.item,
            messages.positions[view.position] or view.position, view.durability, view.maxDurability))
        details.bouclier = view.item
    end
    bridge.AdminLog(source, cfg.journal.inspect, details)
end

--- /armes user <n°> <points>
---@param source integer
---@param target integer
---@param points integer
local function lower(source, target, points)
    local messages = cfg.messages
    local held, def = heldWeapon(target)
    if not held then
        reply(source, messages.adminNoWeapon)
        return
    end
    local step = weapons.lower(held.metadata, def, points, cfg)
    if not step.worn then
        reply(source, format(messages.adminNothing, def.label))
        return
    end
    step = wear.applyStep(target, held.id, held.item, step)
    if not step.worn then
        -- écriture refusée (pile partie entre-temps, garde de l'artisanat) : l'arme n'est pas émoussée pour autant
        reply(source, format(messages.adminFailed, def.label))
        return
    end
    reply(source, format(messages.wornByCouncil, def.label, step.before, step.durability, target))
    bridge.AdminLog(source, cfg.journal.wear, { cible = target, objet = held.item, avant = step.before, apres = step.durability })
end

--- Point d'entrée de /armes (RegisterCommand).
---@param source integer
---@param args string[]
function commands.handle(source, args)
    local messages = cfg.messages
    local admin = cfg.admin
    if not bridge.IsAllowed(source, admin.permission) then
        reply(source, messages.adminDenied)
        return
    end
    local action = args[1]
    if action == 'liste' then
        list(source)
        return
    end
    if action ~= 'voir' and action ~= 'user' then
        reply(source, format(messages.adminUsage, admin.maxWear))
        return
    end
    local target = targetOf(args[2])
    if not target then
        reply(source, args[2] and messages.adminNoPlayer or format(messages.adminUsage, admin.maxWear))
        return
    end
    if action == 'voir' then
        inspect(source, target)
        return
    end
    local points = tointeger(tonumber(args[3]))
    if not points or points < 1 or points > admin.maxWear then
        reply(source, format(messages.adminUsage, admin.maxWear))
        return
    end
    lower(source, target, points)
end
