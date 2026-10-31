--[[
    vava_combat/server/api.lua
    Rôle : exports serveur des armes : fiche d'une arme et catalogue ordonné (pour l'éditeur de techniques, T-121),
           techniques (copies, T-115 et T-121), arme tenue par un joueur et son coup de base (« mains vides » de la
           magie, T-140), mains encore prises pendant le rengainement (T-112), bouclier accroché et prêt au bras
           (T-113), brique `strike` réservée aux ressources de `strike.callers` (les techniques appellent la fonction
           interne).
    Dépendances : shared/constants.lua, config_client.lua, config.lua, shared/weapons.lua, server/core.lua,
                  bridge/server.lua, server/catalog.lua, server/shields.lua, server/strike.lua, server/hands.lua
]]

local type, ipairs, pairs, tostring = type, ipairs, pairs, tostring
local tointeger = math.tointeger
local GetInvokingResource = GetInvokingResource

local bridge = VavaCombat.bridge
local weapons = VavaCombat.weapons
local catalog = VavaCombat.catalog
local shields = VavaCombat.shields
local strike = VavaCombat.strike
local hands = VavaCombat.hands
local cfg = VavaCombat.config
local SHIELD = VavaCombat.SHIELD_CATEGORY

-- une ligne de console par minute et par ressource refusée
local REFUSED_WARN_MS = 60000

local api = {}
VavaCombat.api = api

local callers = {}
for _, name in ipairs(cfg.strike.callers) do callers[name] = true end
-- ressource refusée → instant du dernier avertissement
local refusedAt = {}

--- Arme tenue par un joueur et son coup à × 1,0 ; pendant le rengainement (arme rangée depuis moins de
--- `draw.sheatheMs`), `{ item, category, family, sheathing = true, readyInMs }` : les mains ne sont pas encore libres
--- (la magie refuse d'incanter) ; sinon `nil, code` (`not_ready`, `no_character`, `no_weapon`).
---@param src any
---@return table|nil
---@return string|nil code
function api.armed(src)
    if not VavaCombat.ready then return nil, 'not_ready' end
    local source = type(src) == 'number' and tointeger(src) or nil
    if not source or not bridge.ActiveCharacterId(source) then return nil, 'no_character' end
    local held = bridge.Held(source)
    local item = held and held.item
    local def = catalog.weapon(item)
    if not def or def.category == SHIELD or not catalog.holdable(item) then
        local now = bridge.Timer()
        local sheath = hands.sheathing(source, now)
        local class = sheath and cfg.weaponClasses[sheath.item]
        if not class then return nil, 'no_weapon' end
        return { item = sheath.item, category = class.category, family = class.family, sheathing = true,
            readyInMs = sheath.untilMs - now }
    end
    hands.noteHeld(source, item)
    local meta = held.metadata
    local d = weapons.durabilityOf(meta, def)
    local amount, factor = weapons.amount(def, meta, 1, cfg)
    return {
        instanceId = held.id, item = item, category = def.category, family = def.family, kind = def.kind,
        damage = def.damage, factor = factor, amount = amount, reachBonus = def.reachBonus,
        quality = weapons.quality(type(meta) == 'table' and meta.quality or nil, cfg), durability = d.current,
        maxDurability = d.max, dull = d.dull,
    }
end

--- Export `strike` : contrôle de l'appelant (`strike.callers`), puis la brique serveur.
---@param caller string|nil  ressource appelante
---@return table|nil
---@return string|nil code
function api.strike(caller, src, target, opts)
    if not callers[caller] then
        local key = tostring(caller)
        local now = bridge.Timer()
        if not refusedAt[key] or now - refusedAt[key] >= REFUSED_WARN_MS then
            refusedAt[key] = now
            VavaCombat.log.warn("export strike refusé à la ressource '%s' (absente de strike.callers)", key)
        end
        return nil, 'not_allowed'
    end
    return strike.run(src, target, opts)
end

--- Copie d'une fiche, ou nil.
exports('weapon', function(item)
    return catalog.view(item)
end)

--- Fiches ordonnées (catégorie, puis libellé).
exports('weapons', function()
    local out = {}
    for i, def in ipairs(catalog.list()) do
        local view = {}
        for key, value in pairs(def) do view[key] = value end
        out[i] = view
    end
    return out
end)

exports('armed', function(src)
    return api.armed(src)
end)

--- Techniques (copies), par style puis libellé — pour les compétences (T-115) et l'éditeur (T-121).
exports('techniques', function()
    return catalog.techniques()
end)

--- Copie d'une technique, ou nil.
exports('technique', function(id)
    return catalog.techniqueView(id)
end)

--- Bouclier accroché d'un joueur, ou nil.
exports('shield', function(src)
    if not VavaCombat.ready then return nil end
    local source = type(src) == 'number' and tointeger(src) or nil
    if not source then return nil end
    return shields.view(source)
end)

exports('strike', function(src, target, opts)
    return api.strike(GetInvokingResource(), src, target, opts)
end)
