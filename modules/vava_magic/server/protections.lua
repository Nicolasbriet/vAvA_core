--[[
    vava_magic/server/protections.lua
    Rôle : protections magiques des joueurs, tenues par le serveur, et les modificateurs que la magie déclare à la
           chaîne de dégâts de vava_health (registre `vava_health:modifiers`, un par étape, par le bridge) :
      - `vava_magic:zones` (étape annulation, seulement si `combat.protectedZones` en compte) : personne n'est blessé
        dans une zone de paix, ni par un sort ni par une lame, et personne n'en blesse un autre depuis une zone de
        paix (la faim et la soif, si : `protections.ignoredKinds`) ;
      - `vava_magic:protections` (étape bouclier) : les boucliers en cours du joueur touché absorbent le coup, le plus
        proche de sa fin d'abord, chacun jusqu'à sa réserve ; un bouclier vidé se brise (message au porteur) ;
      - `vava_magic:resistances` (étape resistance) : la plus forte résistance et la plus forte faiblesse en cours au
        type du coup retirent ou ajoutent leur part (jamais cumulées entre elles).
      Les calculs sont les règles pures de shared/harm.lua ; un modificateur lit ces données et rend un résultat, sans
      jamais céder la main. Chacun est déclaré avec les types qu'il couvre (`kinds`) : la chaîne ne l'appelle pas pour
      la faim, la soif ni les pertes natives, ni la résistance pour un type auquel on ne résiste pas. Un bouclier
      entamé par un coup reste entamé même si ce coup est ensuite annulé (aucune étape d'annulation ne vient après
      celle des boucliers ; seule une cible partie ou tombée entre-temps le pourrait, sans attente possible : non
      exploitable). Les protections vivent en mémoire (jamais en base), retirées au départ du joueur et à
      l'arrêt du module. Aucun des onze sorts n'en pose encore (sorts de protection : T-123) : `protections.shield` et
      `protections.resist` servent aux sorts à venir et à la commande d'essai du Conseil (`/magie proteger`).
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/world.lua, server/spells.lua,
                  server/combat.lua
]]

local type, ipairs, pairs, next, mathType, huge = type, ipairs, pairs, next, math.type, math.huge
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
-- pertes natives lues par vava_health : jamais passées aux modificateurs, aucun à leur déclarer
local WORLD_KIND = 'monde'

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
-- types que ni bouclier ni zone de paix n'arrêtent (déclarés à la chaîne comme exclus)
local EXCLUDED = { [WORLD_KIND] = true }
for kind in pairs(IGNORED) do EXCLUDED[kind] = true end

---@param value any
---@return boolean
local function isFinite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

local FIELDS = { 'shields', 'resistances' }

--- Retire ce qui a pris fin ; le joueur sans plus rien est oublié.
---@param src integer
---@param now integer
---@return table|nil entry
local function prune(src, now)
    local entry = players[src]
    if not entry then return nil end
    -- en place, sans nouvelle table : ce qui reste est tassé en tête de liste
    for f = 1, #FIELDS do
        local field = FIELDS[f]
        local list = entry[field]
        local kept = 0
        for i = 1, #list do
            local item = list[i]
            if item.untilMs > now and (field ~= 'shields' or item.points > EPSILON) then
                kept = kept + 1
                list[kept] = item
            end
        end
        for i = #list, kept + 1, -1 do list[i] = nil end
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

--- Étape annulation : la cible, ou la source qui frappe un autre joueur, se tient dans une zone de paix (positions
--- lues côté serveur). Un sort a déjà vérifié la place de sa cible dans le même tour (combat.damage) : elle n'est pas
--- relue.
---@param ctx table
---@return table|nil
local function peaceModifier(ctx)
    if EXCLUDED[ctx.kind] then return nil end
    if ctx.origin ~= RESOURCE then
        local position = world.position(ctx.target)
        if position and combat.protected(position) then return { cancel = PEACE } end
    end
    local source = ctx.source
    if source and source ~= ctx.target then
        local from = world.position(source)
        if from and combat.protected(from) then return { cancel = PEACE } end
    end
    return nil
end

--- Étape bouclier : les boucliers de la cible absorbent le coup ; un bouclier vidé se brise.
---@param ctx table
---@return table|nil
local function shieldModifier(ctx)
    if EXCLUDED[ctx.kind] then return nil end
    local now = GetGameTimer()
    local entry = prune(ctx.target, now)
    if not entry or #entry.shields == 0 then return nil end
    local absorbed, takes = harm.absorb(entry.shields, ctx.amount, ctx.kind, now)
    if absorbed <= 0 then return nil end
    local shields, kept, broken = entry.shields, 0, false
    for i = 1, #shields do
        local shield = shields[i]
        shield.points = shield.points - takes[i]
        if shield.points > EPSILON then
            kept = kept + 1
            shields[kept] = shield
        else
            broken = true
        end
    end
    for i = #shields, kept + 1, -1 do shields[i] = nil end
    if broken then bridge.Notify(ctx.target, notify.shieldBroken, 'warning') end
    return { absorbed = absorbed }
end

--- Étape resistance : résistance ou faiblesse de la cible au type du coup.
---@param ctx table
---@return table|nil
local function resistanceModifier(ctx)
    local now = GetGameTimer()
    local entry = prune(ctx.target, now)
    if not entry or #entry.resistances == 0 then return nil end
    return harm.resist(entry.resistances, ctx.kind, ctx.amount, now)
end

--- Déclare les modificateurs de la magie (par le bridge, et de nouveau à chaque démarrage de vava_health), chacun
--- avec les types qu'il couvre : la chaîne ne les appelle pas pour les autres coups. Appelé pendant le setup du module.
function protections.start()
    local list = {
        [RESOURCE .. ':protections'] = { stage = 'bouclier', label = cfg.labels.shields, apply = shieldModifier,
            exceptKinds = EXCLUDED },
        [RESOURCE .. ':resistances'] = { stage = 'resistance', label = cfg.labels.resistances, apply = resistanceModifier,
            kinds = cfg.kinds },
    }
    -- aucune zone de paix réglée : aucun modificateur, aucun coût par coup
    if next(combatCfg.protectedZones) ~= nil then
        list[RESOURCE .. ':zones'] = { stage = 'annulation', label = cfg.labels.zones, apply = peaceModifier,
            exceptKinds = EXCLUDED }
    end
    bridge.SetModifiers(list)
end

-- départ du joueur (ou changement de personnage) : ses protections tombent ; à l'arrêt du module, elles disparaissent
-- avec lui, et ses entrées du registre aussi
VavaMagic.spells.onLeave(protections.clear)
