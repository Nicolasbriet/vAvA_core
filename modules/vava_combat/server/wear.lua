--[[
    vava_combat/server/wear.lua
    Rôle : usure d'une arme, décidée par le serveur et écrite aussitôt dans les métadonnées de la pile (patchMetadata :
           `durability` toujours à la baisse, `max_durability` pour une pile qui n'en portait pas ; jamais `broken`,
           jamais `history`). Seuils prévenus au SEUL porteur (quart de la solidité, arme émoussée) ; hook
           `vava_combat:dulled` quand une arme atteint 0. Une écriture refusée (pile partie, garde de l'artisanat) est
           une ligne de console limitée, sans nouvelle tentative. Aucun état : rien n'est perdu sur un plantage. Sert
           aussi à /armes user (T-111) et servira à l'usure du bouclier qui bloque (T-113).
    Dépendances : shared/constants.lua, config.lua, shared/weapons.lua, server/core.lua, bridge/server.lua,
                  server/catalog.lua
]]

local tostring, ipairs = tostring, ipairs
local random = math.random
local format = string.format

local bridge = VavaCombat.bridge
local weapons = VavaCombat.weapons
local catalog = VavaCombat.catalog
local cfg = VavaCombat.config
local HOOKS = VavaCombat.HOOKS

-- une ligne de console par joueur et par minute au plus pour les écritures refusées
local WARN_MS = 60000

local wear = {}
VavaCombat.wear = wear

-- source → instant du dernier avertissement
local warnedAt = {}

---@param source integer
---@param fmt string
local function warnLimited(source, fmt, ...)
    local now = bridge.Timer()
    local last = warnedAt[source]
    if last and now - last < WARN_MS then return end
    warnedAt[source] = now
    VavaCombat.log.warn(fmt, ...)
end

--- Applique un pas d'usure déjà calculé (weapons.lower / wearStep) : écriture, seuils, hook. Rend le pas, ramené à
--- « rien n'a changé » si l'écriture est refusée.
---@param source integer
---@param instanceId integer
---@param item string
---@param step table
---@param characterId? integer
---@return table step
function wear.applyStep(source, instanceId, item, step, characterId)
    if not step.patch then return step end
    local ok, code = bridge.PatchMetadata(source, instanceId, step.patch)
    if not ok then
        warnLimited(source, "usure de '%s' (pile %s, joueur %d) refusée : %s", item, tostring(instanceId), source, tostring(code))
        step.worn, step.durability, step.crossedWarn, step.dulled = false, step.before, false, false
        step.dull = step.before <= 0
        step.patch = nil
        return step
    end
    local def = catalog.weapon(item)
    local label = def and def.label or item
    local messages = cfg.messages
    if step.crossedWarn then
        bridge.Notify(source, format(messages.worn, label, step.durability, step.maxDurability), 'info')
    end
    if step.dulled then
        bridge.Notify(source, format(messages.dull, label), 'warning')
        bridge.RunAfter(HOOKS.DULLED, {
            source = source, characterId = characterId or bridge.ActiveCharacterId(source), instanceId = instanceId, item = item,
        })
    end
    return step
end

--- Un coup qui use : la pile est RELUE juste avant l'écriture (un abonné de la chaîne de dégâts a pu céder la main et
--- un autre coup l'user entre-temps), le pas est calculé sur cette lecture, puis écrit (une écriture au plus par coup),
--- sans céder la main entre la lecture et l'écriture. Inventaire muet, ou pile partie de la besace : aucune usure, nil.
---@param source integer
---@param instanceId integer
---@param item string
---@param def table   fiche de l'arme
---@param characterId? integer
---@return table|nil step
function wear.apply(source, instanceId, item, def, characterId)
    local list = bridge.Items(source, item)
    if not list then return nil end
    local pile
    for _, entry in ipairs(list) do
        if entry.id == instanceId then pile = entry end
    end
    if not pile then return nil end
    local step = weapons.wearStep(pile.metadata, def, random(), cfg)
    return wear.applyStep(source, instanceId, item, step, characterId)
end

--- Joueur parti : avertissements oubliés.
---@param source integer
function wear.forget(source)
    warnedAt[source] = nil
end
