--[[
    vava_combat/server/strike.lua
    Rôle : brique serveur d'un coup d'arme, appelée par le relevé d'une technique (server/swings.lua, T-112) après sa
           géométrie, et par l'export `strike` des ressources admises : `strike.run(src, cible, opts[, ctx])`
           vérifie (module prêt, cibles, personnages, attaquant debout, options bornées, arme RÉELLEMENT tenue lue côté
           serveur, même instance et distance lue côté serveur), construit le paquet fermé de vava_health depuis l'arme
           tenue (qualité, usure, multiplicateur de la technique), appelle la chaîne de dégâts commune (`hit`), puis use
           l'arme si le coup a touché, sur la pile relue juste avant l'écriture (server/wear.lua). Débit, cible à terre,
           combats coupés, refus des hooks et modificateurs sont tenus par vava_health, pas recopiés ici. L'export
           `strike` (server/api.lua) est réservé à `strike.callers` et ne transmet jamais `ctx`.
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
--- `ctx` (interne, jamais transmis par l'export `strike`) : pile tenue et personnage de l'attaquant que l'appelant vient
--- de lire dans ce même tour (relevé d'une technique, server/swings.lua), pour ne pas les relire ; tout le reste est
--- revérifié.
---@param src integer
---@param target integer
---@param opts table|nil  { technique?, damage?, tags?, part? }
---@param ctx? { held: table, characterId: integer }
---@return table|nil result
---@return string|nil code
function strike.run(src, target, opts, ctx)
    if not VavaCombat.ready then return nil, 'not_ready' end
    src, target = player(src), player(target)
    if not src or not target or src == target then return nil, 'invalid_target' end
    local known = type(ctx) == 'table' and type(ctx.held) == 'table' and type(ctx.characterId) == 'number'
    local attacker = known and ctx.characterId or bridge.ActiveCharacterId(src)
    if not attacker or not bridge.ActiveCharacterId(target) then return nil, 'no_character' end
    if bridge.IsDowned(src) then return nil, 'downed' end
    local options = weapons.options(opts, cfg)
    if not options then return nil, 'invalid_options' end

    -- l'arme réellement tenue, lue par le serveur (ou par l'appelant dans ce tour) : jamais une donnée du client
    local held = known and ctx.held or bridge.Held(src)
    local item = held and held.item
    local def = catalog.weapon(item)
    if not def or def.category == SHIELD or not catalog.holdable(item) then return nil, 'no_weapon' end

    local ax, ay, az = bridge.Position(src)
    local tx, ty, tz = bridge.Position(target)
    -- une autre instance (routing bucket : intérieur, cachot, essai) est hors d'atteinte, quelle que soit la distance
    if not ax or not tx or not bridge.SameBucket(src, target) then return nil, 'too_far' end
    local dx, dy, dz = ax - tx, ay - ty, az - tz
    if sqrt(dx * dx + dy * dy + dz * dz) > cfg.strike.maxDistance then return nil, 'too_far' end

    local meta = held.metadata
    local amount = weapons.amount(def, meta, options.damage, cfg)
    local result, code = bridge.Hit(target, weapons.packet(item, def, amount, src, options))
    if not result then return nil, code end

    local step
    if weapons.shouldWear(result, cfg) then step = wear.apply(src, held.id, item, def, attacker) end
    if step then
        result.weapon = { item = item, durability = step.durability, maxDurability = step.maxDurability, worn = step.worn,
            dull = step.dull }
    else
        local d = weapons.durabilityOf(meta, def)
        result.weapon = { item = item, durability = d.current, maxDurability = d.max, worn = false, dull = d.dull }
    end
    return result
end
