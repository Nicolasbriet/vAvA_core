--[[
    vava_magic/shared/harm.lua
    Rôle : règles pures des blessures des sorts, portées par la chaîne de dégâts de vava_health (T-116) :
      - montant d'un coup : les points du sort, une vie pleine au plus (`combat.healthPoints`), mis à l'échelle de la
        chaîne (ses `healthPoints`, les mêmes 100 par défaut : le montant est alors celui du sort, tel quel) ;
      - type de dégât d'un élément (`combat.kinds`, sinon `pur`), étiquettes selon la nature du coup (impact d'un
        projectile, zone instantanée, zone qui dure, brûlure), source du coup (le lanceur, sauf s'il joue désormais
        un autre personnage), paquet de `hit` ;
      - protections lues par les modificateurs de la magie : absorption des boucliers (le plus proche de sa fin
        d'abord, chacun jusqu'à sa réserve), résistance ou faiblesse à un type (la plus forte de chaque sens
        l'emporte, jamais cumulée).
    Aucune native ni aucun état : servi au seul serveur (server_scripts) et essayé hors jeu (tests/spec).
    Dépendances : shared/constants.lua
]]

local type, ipairs, pairs, min, max, huge = type, ipairs, pairs, math.min, math.max, math.huge
local mathType, sort, find = math.type, table.sort, string.find

local harm = {}
VavaMagic.harm = harm

-- Nature d'un coup de sort (sert aux étiquettes du paquet et à la réaction de la victime).
harm.NATURE = { IMPACT = 'impact', ZONE = 'zone', AURA = 'aura', BURN = 'brulure' }

-- Étiquettes de la chaîne (vava_health `chain.tags`) selon la nature : un projectile vient de loin, une zone touche
-- une étendue, une zone qui dure et une brûlure sont des dégâts dans le temps (ils passent même si le lanceur est
-- tombé depuis : ce ne sont plus des gestes).
local TAGS = {
    impact = { 'spell', 'ranged' },
    zone = { 'spell', 'area' },
    aura = { 'spell', 'area', 'overTime' },
    brulure = { 'spell', 'overTime' },
}
local SPELL_ONLY = { 'spell' }
local DEFAULT_KIND = 'pur'
local SOURCE_MAX = 65535
local CHARACTER_MAX = 2147483647
-- identifiant de sort admis par la chaîne (ASCII, 64 octets)
local REF_PATTERN = '^[A-Za-z0-9_%-%.:]+$'
local REF_MAX = 64
-- part de résistance (ou de faiblesse) la plus forte
local SHARE_MAX = 1

---@param value any
---@return boolean
local function isFinite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Montant d'un coup pour la chaîne : `points` du sort, au plus une vie pleine (`scale`), mis à l'échelle de la
--- chaîne (`chainPoints`, absent : la même). Rend nil pour un montant nul, négatif ou non fini.
---@param points any
---@param scale number        points de vie d'un personnage en pleine santé pour la magie (combat.healthPoints)
---@param chainPoints? number points de vie d'une vie pleine pour la chaîne (vocabulary().healthPoints)
---@return number|nil
function harm.amount(points, scale, chainPoints)
    if not isFinite(points) or points <= 0 or not isFinite(scale) or scale <= 0 then return nil end
    local capped = min(points, scale)
    if not isFinite(chainPoints) or chainPoints <= 0 or chainPoints == scale then return capped end
    return capped * chainPoints / scale
end

--- Type de dégât d'un élément de la magie (`combat.kinds`), `pur` s'il n'en a pas.
---@param element any
---@param kinds table<string, string>
---@return string
function harm.kindOf(element, kinds)
    local kind = type(element) == 'string' and kinds[element] or nil
    return type(kind) == 'string' and kind or DEFAULT_KIND
end

--- Étiquettes du paquet pour une nature de coup (copie neuve ; une nature inconnue n'a que `spell`).
---@param nature string
---@return table<string, true>
function harm.tags(nature)
    local tags = {}
    for _, tag in ipairs(TAGS[nature] or SPELL_ONLY) do tags[tag] = true end
    return tags
end

---@param value any
---@param high integer
---@return integer|nil
local function idIn(value, high)
    if mathType(value) ~= 'integer' or value < 1 or value > high then return nil end
    return value
end

--- Source du coup et personnage du lanceur. Le lanceur parti (personnage absent) reste la source : son numéro garde
--- le débit par paire et l'interrupteur des combats entre joueurs, la chaîne prend alors le personnage du paquet.
--- Un lanceur qui joue désormais un autre personnage n'est plus la source (le coup reste signé du personnage d'origine).
---@param caster any            numéro du lanceur (0 ou nil : aucun)
---@param casterCharacter any   personnage du lanceur au moment du sort (0 ou nil : inconnu)
---@param currentCharacter any  personnage que le lanceur joue maintenant (nil : aucun)
---@return integer|nil source
---@return integer|nil sourceCharacter
function harm.source(caster, casterCharacter, currentCharacter)
    local character = idIn(casterCharacter, CHARACTER_MAX)
    local current = idIn(currentCharacter, CHARACTER_MAX)
    local source = idIn(caster, SOURCE_MAX)
    if not source then return nil, character end
    if not current then return source, character end
    if not character or current == character then return source, current end
    return nil, character
end

--- Paquet de `exports.vava_health:hit`. `opts` : amount (déjà calculé par harm.amount), kind, nature, source?,
--- sourceCharacter?, spell? (omis s'il n'est pas un identifiant admis par la chaîne).
---@param opts table
---@return table
function harm.packet(opts)
    local spell = opts.spell
    if type(spell) ~= 'string' or #spell > REF_MAX or not find(spell, REF_PATTERN) then spell = nil end
    return {
        amount = opts.amount, kind = opts.kind, source = opts.source, sourceCharacter = opts.sourceCharacter,
        spell = spell, tags = harm.tags(opts.nature),
    }
end

---@param shield table
---@param kind string
---@param now number
---@return boolean
local function shieldHolds(shield, kind, now)
    return isFinite(shield.points) and shield.points > 0 and isFinite(shield.untilMs) and shield.untilMs > now
        and (shield.kinds == nil or shield.kinds[kind] == true)
end

--- Absorption des boucliers d'un joueur (étape `bouclier`) : chaque bouclier en cours qui couvre ce type prend ce
--- qu'il peut de `amount`, le plus proche de sa fin d'abord (à égalité, le plus ancien). Ne modifie rien : rend le
--- total absorbé et, pour chaque bouclier de la liste (même rang), ce qu'il prend.
---@param shields table[]  { points, untilMs, kinds? (ensemble de types) }
---@param amount number
---@param kind string
---@param now number
---@return number absorbed
---@return number[] takes
function harm.absorb(shields, amount, kind, now)
    local takes = {}
    for i = 1, #shields do takes[i] = 0 end
    if not isFinite(amount) or amount <= 0 then return 0, takes end
    local order = {}
    for i, shield in ipairs(shields) do
        if shieldHolds(shield, kind, now) then order[#order + 1] = i end
    end
    sort(order, function(a, b)
        if shields[a].untilMs ~= shields[b].untilMs then return shields[a].untilMs < shields[b].untilMs end
        return a < b
    end)
    local left = amount
    for _, i in ipairs(order) do
        if left <= 0 then break end
        local taken = min(shields[i].points, left)
        takes[i] = taken
        left = left - taken
    end
    return amount - left, takes
end

--- Résistance d'un joueur à un type (étape `resistance`) : la plus forte résistance en cours et la plus forte
--- faiblesse en cours pour ce type, jamais cumulées entre elles ; leur somme fait la part retirée (rendu
--- `{ resisted }`) ou ajoutée (rendu `{ added }`, bornée ensuite par la chaîne). Rend nil si rien ne change.
---@param resistances table[]  { kind, share (-1 à 1 : négatif = faiblesse), untilMs }
---@param kind string
---@param amount number
---@param now number
---@return table|nil
function harm.resist(resistances, kind, amount, now)
    if not isFinite(amount) or amount <= 0 then return nil end
    local strongest, weakest = 0, 0
    for _, entry in ipairs(resistances) do
        local share = entry.share
        if entry.kind == kind and isFinite(share) and isFinite(entry.untilMs) and entry.untilMs > now then
            if share > strongest then strongest = share end
            if share < weakest then weakest = share end
        end
    end
    local net = min(SHARE_MAX, strongest) + max(-SHARE_MAX, weakest)
    if net > 0 then return { resisted = amount * net } end
    if net < 0 then return { added = amount * -net } end
    return nil
end

--- Ensemble (clé → true) d'une liste de types, ou nil pour une liste absente ou vide.
---@param list any
---@return table<string, true>|nil
function harm.kindSet(list)
    if type(list) ~= 'table' then return nil end
    local set, any = {}, false
    for _, kind in pairs(list) do
        if type(kind) == 'string' then
            set[kind] = true
            any = true
        end
    end
    return any and set or nil
end
