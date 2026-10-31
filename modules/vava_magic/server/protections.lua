--[[
    vava_magic/server/protections.lua
    Rôle : protections magiques des joueurs, tenues par le serveur, et les modificateurs que la magie déclare à la
           chaîne de dégâts de vava_health (registre `vava_health:modifiers`, un par étape, par le bridge) :
      - `vava_magic:zones` (étape annulation, seulement si `combat.protectedZones` en compte) : personne n'est blessé
        dans une zone de paix, ni par un sort ni par une lame (la faim et la soif, si : `protections.ignoredKinds`) ;
      - `vava_magic:protections` (étape bouclier) : les boucliers en cours du joueur touché absorbent le coup, le plus
        proche de sa fin d'abord, chacun jusqu'à sa réserve ; un bouclier vidé se brise (message au porteur) ;
      - `vava_magic:resistances` (étape resistance) : la plus forte résistance et la plus forte faiblesse en cours au
        type du coup retirent ou ajoutent leur part (jamais cumulées entre elles).
      Les calculs sont les règles pures de shared/harm.lua ; un modificateur lit ces données et rend un résultat, sans
      jamais céder la main. Les protections vivent en mémoire (jamais en base), retirées au départ du joueur et à
      l'arrêt du module. Aucun des onze sorts n'en pose encore (sorts de protection : T-123) : `protections.shield` et
      `protections.resist` servent aux sorts à venir et à la commande d'essai du Conseil (`/magie proteger`).
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/world.lua, server/spells.lua,
                  server/combat.lua
]]

local type, ipairs, next, mathType, huge = type, ipairs, next, math.type, math.huge
local GetGameTimer = GetGameTimer

local bridge = VavaMagic.bridge
local world = VavaMagic.world
local combat = VavaMagic.combat
local harm = VavaMagic.harm
local cfg = VavaMagic.config.protections
local combatCfg = VavaMagic.config.combat
local notify = VavaMagic.config.texts.notify
local RESOURCE = VavaMagic.resource
-- reste d'une réserve en deçà duquel un bouclier est brisé (arrondis des parts)
local EPSILON = 1e-6
-- raison d'annulation d'un coup dans une zone de paix (motif de la chaîne : ^[A-Za-z0-9_]+$, 32 octets)
local PEACE = 'zone_protegee'
local SHARE_MAX = 1

local protections = {}
VavaMagic.protections = protections

---@class vAvA.MagicShield
---@field id integer
---@field points number
---@field untilMs integer
---@field kinds table<string, true>|nil
---@field spell string|nil

---@class vAvA.MagicResistance
---@field id integer
---@field kind string
---@field share number
---@field untilMs integer
---@field spell string|nil

---@type table<integer, { shields: vAvA.MagicShield[], resistances: vAvA.MagicResistance[] }>
local players = {}
local lastId = 0
local IGNORED = cfg.ignoredKinds or {}
local RESISTIBLE = {}
for _, kind in ipairs(cfg.kinds) do RESISTIBLE[kind] = true end

---@param value any
---@return boolean
local function isFinite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Retire ce qui a pris fin ; le joueur sans plus rien est oublié.
---@param src integer
---@param now integer
---@return table|nil entry
local function prune(src, now)
    local entry = players[src]
    if not entry then return nil end
    for _, field in ipairs({ 'shields', 'resistances' }) do
        local kept = {}
        for _, item in ipairs(entry[field]) do
            if item.untilMs > now and (field ~= 'shields' or item.points > EPSILON) then kept[#kept + 1] = item end
        end
        entry[field] = kept
    end
    if #entry.shields == 0 and #entry.resistances == 0 then
        players[src] = nil
        return nil
    end
    return entry
end

---@param src integer
---@return table
local function entryOf(src)
    local entry = players[src]
    if not entry then
        entry = { shields = {}, resistances = {} }
        players[src] = entry
    end
    return entry
end

---@param durationMs any
---@return integer|nil
local function durationOf(durationMs)
    if durationMs == nil then return cfg.defaultDurationMs end
    if mathType(durationMs) ~= 'integer' or durationMs < 1 or durationMs > cfg.maxDurationMs then return nil end
    return durationMs
end

--- Pose un bouclier sur un joueur en jeu. `opts` : points (réserve, 0 à `maxPoints`), durationMs? (défaut
--- `defaultDurationMs`, au plus `maxDurationMs`), kinds? (types couverts ; absent : tous), spell? (sort qui l'a posé).
--- Renvoie son numéro, ou nil et la raison (no_target, invalid, too_many).
---@param src integer
---@param opts table
---@return integer|nil id
---@return string|nil reason
function protections.shield(src, opts)
    if type(opts) ~= 'table' or not bridge.GetCharacterId(src) then return nil, 'no_target' end
    local points, duration = opts.points, durationOf(opts.durationMs)
    if not isFinite(points) or points <= 0 or points > cfg.maxPoints or not duration then return nil, 'invalid' end
    local now = GetGameTimer()
    local entry = prune(src, now) or entryOf(src)
    if #entry.shields >= cfg.maxShields then return nil, 'too_many' end
    lastId = lastId + 1
    entry.shields[#entry.shields + 1] = {
        id = lastId, points = points, untilMs = now + duration, kinds = harm.kindSet(opts.kinds),
        spell = type(opts.spell) == 'string' and opts.spell or nil,
    }
    return lastId
end

--- Pose une résistance (part positive) ou une faiblesse (part négative) à un type sur un joueur en jeu. `opts` :
--- kind (un de `protections.kinds`), share (-1 à 1, jamais 0), durationMs?, spell?. Renvoie son numéro, ou nil et la
--- raison (no_target, invalid, too_many).
---@param src integer
---@param opts table
---@return integer|nil id
---@return string|nil reason
function protections.resist(src, opts)
    if type(opts) ~= 'table' or not bridge.GetCharacterId(src) then return nil, 'no_target' end
    local share, duration = opts.share, durationOf(opts.durationMs)
    if not RESISTIBLE[opts.kind] or not isFinite(share) or share == 0 or share > SHARE_MAX or share < -SHARE_MAX
        or not duration then
        return nil, 'invalid'
    end
    local now = GetGameTimer()
    local entry = prune(src, now) or entryOf(src)
    if #entry.resistances >= cfg.maxResistances then return nil, 'too_many' end
    lastId = lastId + 1
    entry.resistances[#entry.resistances + 1] = {
        id = lastId, kind = opts.kind, share = share, untilMs = now + duration,
        spell = type(opts.spell) == 'string' and opts.spell or nil,
    }
    return lastId
end

--- Retire toutes les protections d'un joueur (départ, commande du Conseil). Renvoie vrai s'il en avait.
---@param src integer
---@return boolean
function protections.clear(src)
    local had = players[src] ~= nil
    players[src] = nil
    return had
end

--- Protections en cours d'un joueur : nombre de boucliers, réserve totale, nombre de résistances et faiblesses.
---@param src integer
---@return integer shields
---@return number points
---@return integer resistances
function protections.count(src)
    local entry = prune(src, GetGameTimer())
    if not entry then return 0, 0, 0 end
    local points = 0
    for _, shield in ipairs(entry.shields) do points = points + shield.points end
    return #entry.shields, points, #entry.resistances
end

-- Modificateurs de la chaîne ----------------------------------------------------------------------------------------
-- Appelés par vava_health pendant un coup, sur une copie du contexte : ils lisent ces données, rendent un résultat et
-- ne cèdent jamais la main (ni attente, ni base).

--- Étape annulation : la cible se tient dans une zone de paix (position lue côté serveur).
---@param ctx table
---@return table|nil
local function peaceModifier(ctx)
    if IGNORED[ctx.kind] then return nil end
    local position = world.position(ctx.target)
    if position and combat.protected(position) then return { cancel = PEACE } end
    return nil
end

--- Étape bouclier : les boucliers de la cible absorbent le coup ; un bouclier vidé se brise.
---@param ctx table
---@return table|nil
local function shieldModifier(ctx)
    if IGNORED[ctx.kind] then return nil end
    local now = GetGameTimer()
    local entry = prune(ctx.target, now)
    if not entry or #entry.shields == 0 then return nil end
    local absorbed, takes = harm.absorb(entry.shields, ctx.amount, ctx.kind, now)
    if absorbed <= 0 then return nil end
    local kept, broken = {}, false
    for i, shield in ipairs(entry.shields) do
        shield.points = shield.points - takes[i]
        if shield.points > EPSILON then
            kept[#kept + 1] = shield
        else
            broken = true
        end
    end
    entry.shields = kept
    if broken then bridge.Notify(ctx.target, notify.shieldBroken, 'warning') end
    return { absorbed = absorbed }
end

--- Étape resistance : résistance ou faiblesse de la cible au type du coup.
---@param ctx table
---@return table|nil
local function resistanceModifier(ctx)
    local entry = prune(ctx.target, GetGameTimer())
    if not entry or #entry.resistances == 0 then return nil end
    return harm.resist(entry.resistances, ctx.kind, ctx.amount, GetGameTimer())
end

--- Déclare les modificateurs de la magie (par le bridge, et de nouveau à chaque démarrage de vava_health). Appelé
--- pendant le setup du module.
function protections.start()
    local list = {
        [RESOURCE .. ':protections'] = { stage = 'bouclier', label = cfg.labels.shields, apply = shieldModifier },
        [RESOURCE .. ':resistances'] = { stage = 'resistance', label = cfg.labels.resistances, apply = resistanceModifier },
    }
    -- aucune zone de paix réglée : aucun modificateur, aucun coût par coup
    if next(combatCfg.protectedZones) ~= nil then
        list[RESOURCE .. ':zones'] = { stage = 'annulation', label = cfg.labels.zones, apply = peaceModifier }
    end
    bridge.SetModifiers(list)
end

-- départ du joueur (ou changement de personnage) : ses protections tombent ; à l'arrêt du module, elles disparaissent
-- avec lui, et ses entrées du registre aussi
VavaMagic.spells.onLeave(protections.clear)
