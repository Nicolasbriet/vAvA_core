--[[
    vava_combat/shared/weapons.lua
    Rôle : règles pures des armes, servies au seul serveur (server_scripts) : contrôle du catalogue de la config au
           démarrage, qualité lue et facteur de dégâts, solidité lue (émoussée ou non), montant d'un coup, chance et pas
           d'usure, coup qui use (d'après le résultat de vava_health:hit), options d'un appel à `strike`, paquet `hit`,
           comparaison de versions. Aucun état, aucune native, ne lève jamais d'erreur sur une donnée reçue.
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs, next, tostring, tonumber = type, pairs, ipairs, next, tostring, tonumber
local floor, huge, mathType, tointeger = math.floor, math.huge, math.type, math.tointeger
local find, format, gmatch = string.find, string.format, string.gmatch

local ID_PATTERN = VavaCombat.ID_PATTERN
local REF_PATTERN, REF_MAX = VavaCombat.REF_PATTERN, VavaCombat.REF_MAX
local MAX_AMOUNT, MAX_TAGS = VavaCombat.MAX_AMOUNT, VavaCombat.MAX_TAGS
local MODEL_MAX = VavaCombat.MODEL_MAX
local SHIELD = VavaCombat.SHIELD_CATEGORY
local PARTS = VavaCombat.PARTS
local QUALITY_MAX = 100
local DURABILITY_MAX = 10000

local weapons = {}
VavaCombat.weapons = weapons

-- Petites règles ----------------------------------------------------------------------------------------------------

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end
weapons.finite = finite

---@param list table
---@return table<any, true>
local function setOf(list)
    local out = {}
    for _, value in ipairs(list) do out[value] = true end
    return out
end

--- Entier (ou flottant de valeur entière) entre low et high, rendu en entier ; sinon nil.
---@param value any
---@param low integer
---@param high integer
---@return integer|nil
local function integerIn(value, low, high)
    if not finite(value) then return nil end
    local int = tointeger(value)
    if not int or int < low or int > high then return nil end
    return int
end

---@param value number
---@return number
local function tenth(value)
    return floor(value * 10 + 0.5) / 10
end
weapons.tenth = tenth

--- Vrai si la table n'a que des clés chaînes (aucune clé entière : une liste déguisée est refusée).
---@param map table
---@return boolean
local function stringKeys(map)
    for key in pairs(map) do
        if type(key) ~= 'string' then return false end
    end
    return true
end

-- Contrôle du catalogue ---------------------------------------------------------------------------------------------

local WEAPON_KEYS = {
    category = true, family = true, kind = true, damage = true, reachBonus = true, durability = true, block = true,
    provisional = true,
}

---@param value any
---@return boolean
local function vector3(value)
    return type(value) == 'table' and #value == 3 and finite(value[1]) and finite(value[2]) and finite(value[3])
end

---@param place any
---@return boolean
local function placement(place)
    return type(place) == 'table' and integerIn(place.bone, 0, 65535) ~= nil and vector3(place.offset)
        and vector3(place.rotation)
end

---@param name string
---@param def any
---@param cfg table
---@param categories table<string, true>
---@return boolean ok
---@return string|nil err
local function checkWeapon(name, def, cfg, categories)
    if type(name) ~= 'string' or not find(name, ID_PATTERN) or #name > VavaCombat.ITEM_MAX then
        return false, format("arme '%s' : nom d'objet invalide", tostring(name))
    end
    if type(def) ~= 'table' then return false, format("arme '%s' : fiche attendue", name) end
    for key in pairs(def) do
        if not WEAPON_KEYS[key] then return false, format("arme '%s' : clé inconnue '%s'", name, tostring(key)) end
    end
    if not categories[def.category] then
        return false, format("arme '%s' : catégorie inconnue '%s'", name, tostring(def.category))
    end
    if type(def.family) ~= 'string' or type(cfg.families[def.family]) ~= 'table' then
        return false, format("arme '%s' : famille inconnue '%s'", name, tostring(def.family))
    end
    local kindOk = false
    for _, kind in ipairs(cfg.kinds) do
        if def.kind == kind then kindOk = true end
    end
    if not kindOk then return false, format("arme '%s' : type de dégâts inconnu '%s'", name, tostring(def.kind)) end
    if not finite(def.damage) or def.damage <= 0 or def.damage > 100 then
        return false, format("arme '%s' : damage attendu entre 0 (exclu) et 100", name)
    end
    if not finite(def.reachBonus) or def.reachBonus < -1 or def.reachBonus > 1.5 then
        return false, format("arme '%s' : reachBonus attendu entre -1 et 1,5", name)
    end
    if mathType(def.durability) ~= 'integer' or def.durability < 1 or def.durability > DURABILITY_MAX then
        return false, format("arme '%s' : durability attendue entière, de 1 à %d", name, DURABILITY_MAX)
    end
    if not finite(def.block) or def.block < 0 or def.block > 1 then
        return false, format("arme '%s' : block attendu entre 0 et 1", name)
    end
    if type(def.provisional) ~= 'boolean' then return false, format("arme '%s' : provisional attendu (booléen)", name) end

    local item = cfg.items[name]
    if def.category == SHIELD then
        local hung = cfg.shields[name]
        if type(hung) ~= 'table' then return false, format("bouclier '%s' : placement absent de shields", name) end
        if type(hung.model) ~= 'string' or #hung.model < 1 or #hung.model > MODEL_MAX then
            return false, format("bouclier '%s' : modèle attendu (1 à %d octets)", name, MODEL_MAX)
        end
        if not placement(hung.arm) or not placement(hung.back) then
            return false, format("bouclier '%s' : arm et back attendus ({ bone, offset, rotation })", name)
        end
        if type(item) == 'table' and item.held ~= nil then
            return false, format("bouclier '%s' : un bouclier ne se tient pas en main (held interdit)", name)
        end
    else
        if cfg.shields[name] ~= nil then return false, format("arme '%s' : entrée de shields pour une arme qui n'est pas un bouclier", name) end
        if item ~= nil and (type(item) ~= 'table' or type(item.held) ~= 'table') then
            return false, format("arme '%s' : déclarée dans items sans held", name)
        end
    end
    return true
end

--- Contrôle du catalogue de la config. Rend `true`, ou `false, raison` à la première erreur.
---@param cfg table         VavaCombat.config
---@param CATEGORIES string[]  liste fermée des catégories
---@return boolean ok
---@return string|nil err
function weapons.check(cfg, CATEGORIES)
    if type(cfg) ~= 'table' then return false, 'config absente' end
    for _, key in ipairs({ 'kinds', 'categories', 'families', 'weapons', 'items', 'recipes', 'shields' }) do
        if type(cfg[key]) ~= 'table' then return false, format('%s : table attendue', key) end
    end
    local categories = setOf(CATEGORIES)
    for _, name in ipairs(CATEGORIES) do
        local entry = cfg.categories[name]
        if type(entry) ~= 'table' or type(entry.label) ~= 'string' or mathType(entry.order) ~= 'integer' then
            return false, format("categories : '%s' manquante ({ label, order } attendu)", name)
        end
    end
    for name in pairs(cfg.categories) do
        if not categories[name] then return false, format("categories : '%s' n'est pas une catégorie de COMBAT_V1", tostring(name)) end
    end
    for name, family in pairs(cfg.families) do
        if type(name) ~= 'string' or not find(name, ID_PATTERN) or type(family) ~= 'table' or type(family.label) ~= 'string' then
            return false, format("families : '%s' invalide ({ label } attendu)", tostring(name))
        end
    end
    if #cfg.kinds < 1 then return false, 'kinds : au moins un type de dégâts' end
    for _, kind in ipairs(cfg.kinds) do
        if type(kind) ~= 'string' or not find(kind, ID_PATTERN) then return false, format("kinds : '%s' invalide", tostring(kind)) end
    end
    if next(cfg.weapons) == nil then return false, 'weapons : aucune arme' end
    for name, def in pairs(cfg.weapons) do
        local ok, err = checkWeapon(name, def, cfg, categories)
        if not ok then return false, err end
    end
    for name in pairs(cfg.items) do
        if not cfg.weapons[name] then return false, format("items : '%s' n'est pas une arme du catalogue", tostring(name)) end
    end
    for name in pairs(cfg.shields) do
        local def = cfg.weapons[name]
        if not def or def.category ~= SHIELD then return false, format("shields : '%s' n'est pas un bouclier du catalogue", tostring(name)) end
    end
    for id, recipe in pairs(cfg.recipes) do
        if type(recipe) ~= 'table' then return false, format("recette '%s' : table attendue", tostring(id)) end
        if recipe.durability ~= nil or recipe.signed ~= nil then
            return false, format("recette '%s' : durability et signed sont posés par le code (fiche de l'arme)", tostring(id))
        end
        local output = recipe.output
        if type(output) ~= 'table' or output.item ~= id then
            return false, format("recette '%s' : output.item doit être l'objet de même nom", tostring(id))
        end
        if not cfg.weapons[id] or not cfg.items[id] then
            return false, format("recette '%s' : le produit doit être une arme du catalogue déclarée dans items", tostring(id))
        end
    end
    local q = cfg.quality
    if type(q) ~= 'table' or not finite(q.minFactor) or not finite(q.maxFactor) or q.minFactor <= 0 or q.maxFactor < q.minFactor
        or not finite(q.default) or q.default < 0 or q.default > QUALITY_MAX then
        return false, 'quality : minFactor > 0, maxFactor ≥ minFactor, default de 0 à 100 attendus'
    end
    local w = cfg.wear
    if type(w) ~= 'table' or mathType(w.perHit) ~= 'integer' or w.perHit < 1 or not finite(w.qualitySave) or w.qualitySave < 0
        or w.qualitySave > 1 or not finite(w.dullFactor) or w.dullFactor <= 0 or w.dullFactor > 1 or not finite(w.warnRatio)
        or w.warnRatio < 0 or w.warnRatio > 1 or type(w.cancelledStages) ~= 'table' then
        return false, 'wear : perHit ≥ 1, qualitySave et warnRatio de 0 à 1, dullFactor de 0 (exclu) à 1 attendus'
    end
    local s = cfg.strike
    if type(s) ~= 'table' or not finite(s.maxDistance) or s.maxDistance <= 0 or not finite(s.minMultiplier)
        or s.minMultiplier <= 0 or not finite(s.maxMultiplier) or s.maxMultiplier < s.minMultiplier
        or not finite(s.minAmount) or s.minAmount <= 0 or s.minAmount > MAX_AMOUNT
        or type(s.tags) ~= 'table' or type(s.callers) ~= 'table' then
        return false, 'strike : maxDistance, minMultiplier, maxMultiplier, minAmount, tags et callers attendus'
    end
    for _, tag in ipairs(s.tags) do
        if tag == 'melee' then return false, 'strike.tags : melee est toujours posé, jamais ajouté par un appelant' end
    end
    return true
end

-- Qualité, solidité, montant ----------------------------------------------------------------------------------------

--- Qualité d'une pièce (0 à 100) : nombre fini ramené dans les bornes, sinon la qualité par défaut.
---@param quality any
---@param cfg table  VavaCombat.config
---@return number
function weapons.quality(quality, cfg)
    if not finite(quality) then return cfg.quality.default end
    if quality < 0 then return 0 end
    if quality > QUALITY_MAX then return QUALITY_MAX end
    return quality
end

--- Facteur de dégâts d'une qualité : linéaire de minFactor (0) à maxFactor (100).
---@param quality any
---@param cfg table
---@return number
function weapons.qualityFactor(quality, cfg)
    local q = weapons.quality(quality, cfg)
    local f = cfg.quality
    return f.minFactor + (f.maxFactor - f.minFactor) * q / QUALITY_MAX
end

--- Solidité lue d'une pile : maximale (`max_durability` entier ≥ 1, sinon celle de la fiche), courante (`durability`
--- entier de 0 à la maximale, sinon la maximale), émoussée (courante à 0, ou `broken` posé ailleurs).
---@param meta any  métadonnées de la pile
---@param def table fiche de l'arme
---@return { current: integer, max: integer, dull: boolean, hasMax: boolean }
function weapons.durabilityOf(meta, def)
    meta = type(meta) == 'table' and meta or {}
    local max = integerIn(meta.max_durability, 1, DURABILITY_MAX)
    local hasMax = max ~= nil
    max = max or def.durability
    local current = integerIn(meta.durability, 0, max) or max
    return { current = current, max = max, dull = current <= 0 or meta.broken == true, hasMax = hasMax }
end

--- Montant d'un coup : dégâts de la fiche × facteur de qualité × (émoussée : dullFactor) × multiplicateur de la
--- technique, arrondi au dixième, borné à [minAmount, 200].
---@param def table   fiche de l'arme
---@param meta any    métadonnées de la pile
---@param damage number  multiplicateur de la technique (déjà contrôlé)
---@param cfg table
---@return number amount
---@return number factor  facteur de la pièce (qualité × usure)
function weapons.amount(def, meta, damage, cfg)
    meta = type(meta) == 'table' and meta or {}
    local factor = weapons.qualityFactor(meta.quality, cfg)
    if weapons.durabilityOf(meta, def).dull then factor = factor * cfg.wear.dullFactor end
    local value = tenth(def.damage * factor * damage)
    if value < cfg.strike.minAmount then value = cfg.strike.minAmount end
    if value > MAX_AMOUNT then value = MAX_AMOUNT end
    return value, factor
end

-- Usure ---------------------------------------------------------------------------------------------------------------

--- Chance qu'un coup use l'arme : 1 − qualitySave × qualité / 100.
---@param quality any
---@param cfg table
---@return number
function weapons.wearChance(quality, cfg)
    return 1 - cfg.wear.qualitySave * weapons.quality(quality, cfg) / QUALITY_MAX
end

--- Vrai si un coup (résultat de vava_health:hit) use l'arme : coup arrivé (même entièrement bloqué ou absorbé), ou
--- annulé à une étape où l'arme a touché du fer ou du bois (parade, blocage, bouclier). Une esquive, une annulation
--- (zone, trêve), une précondition (cible à terre, combats coupés) n'usent pas.
---@param result any
---@param cfg table
---@return boolean
function weapons.shouldWear(result, cfg)
    if type(result) ~= 'table' then return false end
    if result.cancelled == nil then return true end
    if type(result.stage) ~= 'string' then return false end
    for _, stage in ipairs(cfg.wear.cancelledStages) do
        if result.stage == stage then return true end
    end
    return false
end

--- Solidité baissée de `points` (au moins 0). Rend ce qui change : `worn` (baissée), `durability`, `maxDurability`,
--- `before`, `crossedWarn` (passée de plus de warnRatio × max à moins ou autant), `dulled` (atteint 0), `patch`
--- (`durability`, plus `max_durability` si la pile n'en portait pas ; nil si rien ne change).
---@param meta any
---@param def table
---@param points integer
---@param cfg table
---@return table step
function weapons.lower(meta, def, points, cfg)
    local d = weapons.durabilityOf(meta, def)
    local step = { worn = false, before = d.current, durability = d.current, maxDurability = d.max,
        crossedWarn = false, dulled = false, dull = d.dull, patch = nil }
    if d.dull or mathType(points) ~= 'integer' or points < 1 then return step end
    local after = d.current - points
    if after < 0 then after = 0 end
    local threshold = cfg.wear.warnRatio * d.max
    step.worn, step.durability = true, after
    step.crossedWarn = d.current > threshold and after <= threshold and after > 0
    step.dulled = after <= 0
    step.dull = step.dulled
    step.patch = { durability = after }
    if not d.hasMax then step.patch.max_durability = d.max end
    return step
end

--- Un coup qui use : tirage `roll` ∈ [0, 1[ comparé à la chance d'user ; sous elle, solidité − perHit.
---@param meta any
---@param def table
---@param roll number
---@param cfg table
---@return table step  (voir weapons.lower)
function weapons.wearStep(meta, def, roll, cfg)
    meta = type(meta) == 'table' and meta or {}
    local points = 0
    if finite(roll) and roll < weapons.wearChance(meta.quality, cfg) then points = cfg.wear.perHit end
    return weapons.lower(meta, def, points, cfg)
end

-- Options et paquet d'un coup -----------------------------------------------------------------------------------------

local OPTION_KEYS = { technique = true, damage = true, tags = true, part = true }
local PART_SET = setOf(PARTS)

--- Options d'un appel à `strike` : nil, ou table aux seules clés `technique` (identifiant de 64 octets), `damage`
--- (multiplicateur borné, défaut 1), `tags` (map étiquette admise → true, 3 au plus), `part` (partie du corps). Rend une
--- copie normalisée, ou `nil, 'invalid_options'`.
---@param opts any
---@param cfg table
---@return table|nil options  { damage, technique?, tags?, part? }
---@return string|nil code
function weapons.options(opts, cfg)
    if opts == nil then return { damage = 1 } end
    if type(opts) ~= 'table' then return nil, 'invalid_options' end
    for key in pairs(opts) do
        if not OPTION_KEYS[key] then return nil, 'invalid_options' end
    end
    local out = { damage = 1 }
    local s = cfg.strike
    if opts.damage ~= nil then
        if not finite(opts.damage) or opts.damage < s.minMultiplier or opts.damage > s.maxMultiplier then
            return nil, 'invalid_options'
        end
        out.damage = opts.damage
    end
    if opts.technique ~= nil then
        local t = opts.technique
        if type(t) ~= 'string' or #t < 1 or #t > REF_MAX or not find(t, REF_PATTERN) then return nil, 'invalid_options' end
        out.technique = t
    end
    if opts.part ~= nil then
        if not PART_SET[opts.part] then return nil, 'invalid_options' end
        out.part = opts.part
    end
    if opts.tags ~= nil then
        if type(opts.tags) ~= 'table' or not stringKeys(opts.tags) then return nil, 'invalid_options' end
        local allowed = setOf(s.tags)
        local tags, count = {}, 0
        for tag, value in pairs(opts.tags) do
            if not allowed[tag] or value ~= true then return nil, 'invalid_options' end
            count = count + 1
            if count > MAX_TAGS then return nil, 'invalid_options' end
            tags[tag] = true
        end
        if count > 0 then out.tags = tags end
    end
    return out
end

--- Paquet `hit` d'un coup d'arme (forme fermée de vava_health) : `melee` toujours posé.
---@param item string    objet qui frappe
---@param def table      fiche de l'arme
---@param amount number
---@param source integer attaquant
---@param options table  options normalisées (weapons.options)
---@return table packet
function weapons.packet(item, def, amount, source, options)
    local tags = { melee = true }
    if options.tags then
        for tag in pairs(options.tags) do tags[tag] = true end
    end
    local packet = { amount = amount, kind = def.kind, source = source, weapon = item, tags = tags }
    if options.technique then packet.technique = options.technique end
    if options.part then packet.part = options.part end
    return packet
end

-- Versions ------------------------------------------------------------------------------------------------------------

--- Vrai si `version` (semver « a.b.c ») est au moins `minimum`. Une version illisible n'est jamais suffisante.
---@param version any
---@param minimum string
---@return boolean
function weapons.versionAtLeast(version, minimum)
    if type(version) ~= 'string' or type(minimum) ~= 'string' then return false end
    local a, b = {}, {}
    for part in gmatch(version, '%d+') do a[#a + 1] = tonumber(part) end
    for part in gmatch(minimum, '%d+') do b[#b + 1] = tonumber(part) end
    if #a == 0 or #b == 0 then return false end
    for i = 1, 3 do
        local x, y = a[i] or 0, b[i] or 0
        if x ~= y then return x > y end
    end
    return true
end
