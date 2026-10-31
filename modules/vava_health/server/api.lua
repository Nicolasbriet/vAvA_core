--[[
    vava_health/server/api.lua
    Rôle : exports serveur pour les autres modules (combat, magie, besoins, médecin, administration…). Cible : un joueur
           (son personnage actif). Vie de 0 à 1 : part de la vie au-dessus du seuil de mise à terre ; les coups parlent
           en points (`chain.healthPoints` pour une vie pleine). La vie est celle du serveur : aucune lecture du ped,
           aucune condition d'apparition.
             - hit(cible, paquet) : la chaîne de dégâts (server/chain.lua) ; `origin` = ressource appelante ;
             - vocabulary() : listes fermées de la chaîne (types, parties, étiquettes, étapes) pour les éditeurs ;
             - modifiers() : modificateurs déclarés, dans l'ordre d'appel ;
             - damage(cible, part) : enveloppe de hit (`pur`, `tags.legacy`), dépréciée pour les coups et les sorts.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, server/life.lua, server/modifiers.lua,
                  server/chain.lua
]]

local type, ipairs = type, ipairs
local mathType, huge = math.type, math.huge
local find = string.find
local GetInvokingResource = GetInvokingResource

local life = VavaHealth.life
local hits = VavaHealth.hits
local modifiers = VavaHealth.modifiers
local cfg = VavaHealth.config
local LEGACY_KIND = 'pur'
-- cause d'une mise à terre décidée par un module (hooks, journaux)
local CAUSE_PATTERN = '^[A-Za-z0-9_%-]+$'
local CAUSE_MAX = 32

---@param src any
---@return vAvA.HealthEntry|nil
---@return string|nil code
local function resolve(src)
    if not VavaHealth.ready then return nil, 'not_ready' end
    if mathType(src) ~= 'integer' then return nil, 'invalid_target' end
    local entry = life.entry(src)
    if not entry then return nil, 'no_character' end
    return entry
end

---@param value any
---@param low number
---@return boolean
local function isAmount(value, low)
    return type(value) == 'number' and value == value and value ~= huge and value >= low and value <= 1
end

---@return string
local function caller()
    local resource = GetInvokingResource()
    if type(resource) == 'string' and resource ~= '' then return resource end
    return VavaHealth.resource
end

---@param list string[]
---@return string[]
local function copyList(list)
    local out = {}
    for i, value in ipairs(list) do out[i] = value end
    return out
end

--- Un coup sur un joueur : résultat chiffré, ou nil et un code (docs/api.md, § vava_health).
exports('hit', function(target, raw)
    return hits.hit(target, raw, caller())
end)

--- Listes fermées de la chaîne (copies).
exports('vocabulary', function()
    local chain = cfg.chain
    return {
        healthPoints = chain.healthPoints, maxAmount = chain.maxAmount, kinds = copyList(chain.kinds),
        parts = copyList(chain.parts), tags = copyList(chain.tags), stages = copyList(VavaHealth.STAGES),
    }
end)

--- Modificateurs déclarés, dans l'ordre d'appel, sans leurs fonctions.
exports('modifiers', function()
    return modifiers.describe()
end)

--- { health, downed, downedFor } ; health est la vie du serveur (0 à terre).
exports('get', function(src)
    local entry, code = resolve(src)
    if not entry then return nil, code end
    return { health = life.currentHealth(src, entry), downed = entry.downed, downedFor = entry.downedFor }
end)

exports('isDowned', function(src)
    local entry = resolve(src)
    return entry ~= nil and entry.downed
end)

--- Fixe la vie d'un joueur debout (0 le met à terre aussitôt).
exports('setHealth', function(src, health)
    local entry, code = resolve(src)
    if not entry then return false, code end
    if not isAmount(health, 0) then return false, 'invalid_amount' end
    return life.setHealth(src, health)
end)

--- Soigne à partir de la vie du serveur (ce n'est pas un dégât : aucune chaîne).
exports('heal', function(src, amount)
    local entry, code = resolve(src)
    if not entry then return false, code end
    if not isAmount(amount, 0) then return false, 'invalid_amount' end
    return life.adjust(src, amount)
end)

--- Dépréciée pour les coups et les sorts : enveloppe de hit (`pur`, `tags.legacy`). Vrai si la perte est appliquée ;
--- faux et le code (refus de hit) ou la raison de l'annulation.
exports('damage', function(src, amount)
    local entry, code = resolve(src)
    if not entry then return false, code end
    if not isAmount(amount, 0) then return false, 'invalid_amount' end
    if amount == 0 then return true end
    local result, refusal = hits.hit(src, {
        amount = amount * cfg.chain.healthPoints, kind = LEGACY_KIND, tags = { legacy = true },
    }, caller())
    if not result then return false, refusal end
    if result.cancelled then return false, result.cancelled end
    return true
end)

--- Met à terre (cause pour les hooks : identifiant ASCII de 32 octets au plus, 'execution', 'piege'…).
exports('down', function(src, cause)
    local entry, code = resolve(src)
    if not entry then return false, code end
    if cause ~= nil and (type(cause) ~= 'string' or #cause > CAUSE_MAX or not find(cause, CAUSE_PATTERN)) then
        return false, 'invalid_cause'
    end
    return life.down(src, 'api', cause)
end)

--- Relève sur place, avec la vie donnée (par défaut celle d'une réanimation).
exports('revive', function(src, health)
    local entry, code = resolve(src)
    if not entry then return false, code end
    if health ~= nil and not isAmount(health, 0.01) then return false, 'invalid_amount' end
    return life.revive(src, health or cfg.assist.health, 'api')
end)
