--[[
    vava_combat/server/strike.lua
    Rôle : brique serveur d'un coup d'arme, que T-112 appellera après sa géométrie : `strike.run(src, cible, opts)`
           vérifie (module prêt, cibles, personnages, attaquant debout, options bornées, arme RÉELLEMENT tenue lue côté
           serveur, distance lue côté serveur), construit le paquet fermé de vava_health depuis l'arme tenue (qualité,
           usure, multiplicateur de la technique), appelle la chaîne de dégâts commune (`hit`), puis use l'arme si le
           coup a touché. Aucun `Wait`, aucune base entre la lecture de l'arme et l'usure. Débit, cible à terre,
           combats coupés, refus des hooks et modificateurs sont tenus par vava_health, pas recopiés ici. Aucun coup
           donné par un joueur dans T-111 : l'export `strike` (server/api.lua) est réservé à `strike.callers`.
    Dépendances : shared/constants.lua, config.lua, shared/weapons.lua, server/core.lua, bridge/server.lua,
                  server/catalog.lua, server/wear.lua
]]

local type = type
local tointeger, sqrt = math.tointeger, math.sqrt

local bridge = VavaCombat.bridge
local weapons = VavaCombat.weapons
local catalog = VavaCombat.catalog
local wear = VavaCombat.wear
local cfg = VavaCombat.config
local SHIELD = VavaCombat.SHIELD_CATEGORY

local strike = {}
VavaCombat.strike = strike

---@param value any
---@return integer|nil
local function player(value)
    local int = type(value) == 'number' and tointeger(value) or nil
    if not int or int <= 0 then return nil end
    return int
end

--- Un coup de l'arme tenue par `src` sur `target`. Rend le résultat de vava_health:hit complété de `weapon` = { item,
--- durability, maxDurability, worn, dull }, ou `nil, code` : `not_ready`, `invalid_target`, `no_character`, `downed`,
--- `invalid_options`, `no_weapon`, `too_far`, `health_unavailable`, ou le code de `hit` (rendu tel quel, sans usure).
---@param src integer
---@param target integer
---@param opts table|nil  { technique?, damage?, tags?, part? }
---@return table|nil result
---@return string|nil code
function strike.run(src, target, opts)
    if not VavaCombat.ready then return nil, 'not_ready' end
    src, target = player(src), player(target)
    if not src or not target or src == target then return nil, 'invalid_target' end
    local attacker = bridge.ActiveCharacterId(src)
    if not attacker or not bridge.ActiveCharacterId(target) then return nil, 'no_character' end
    if bridge.IsDowned(src) then return nil, 'downed' end
    local options = weapons.options(opts, cfg)
    if not options then return nil, 'invalid_options' end

    -- l'arme réellement tenue, lue par le serveur : jamais une donnée du client
    local held = bridge.Held(src)
    local item = held and held.item
    local def = catalog.weapon(item)
    if not def or def.category == SHIELD or not catalog.holdable(item) then return nil, 'no_weapon' end

    local ax, ay, az = bridge.Position(src)
    local tx, ty, tz = bridge.Position(target)
    if not ax or not tx then return nil, 'too_far' end
    local dx, dy, dz = ax - tx, ay - ty, az - tz
    if sqrt(dx * dx + dy * dy + dz * dz) > cfg.strike.maxDistance then return nil, 'too_far' end

    local meta = held.metadata
    local amount = weapons.amount(def, meta, options.damage, cfg)
    local result, code = bridge.Hit(target, weapons.packet(item, def, amount, src, options))
    if not result then return nil, code end

    local step
    if weapons.shouldWear(result, cfg) then step = wear.apply(src, held.id, item, def, meta, attacker) end
    if step then
        result.weapon = { item = item, durability = step.durability, maxDurability = step.maxDurability, worn = step.worn,
            dull = step.dull }
    else
        local d = weapons.durabilityOf(meta, def)
        result.weapon = { item = item, durability = d.current, maxDurability = d.max, worn = false, dull = d.dull }
    end
    return result
end
