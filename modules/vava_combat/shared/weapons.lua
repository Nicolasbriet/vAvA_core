--[[
    vava_combat/shared/weapons.lua
    Rôle : règles pures des armes, servies au seul serveur (server_scripts) : contrôle du catalogue de la config au
           démarrage (classes de config_client.lua et fiches de config.lua), contrôle des techniques et des styles
           (format de COMBAT_V1.md § 3) et des réglages du moteur, qualité lue et facteur de dégâts, solidité lue
           (émoussée ou non), montant d'un coup, chance et pas d'usure, coup qui use (d'après le résultat de
           vava_health:hit), issue d'un coup montrée aux proches, options d'un appel à `strike`, paquet `hit`, raison
           d'un refus montrée au joueur, comparaison de versions. Aucun état, aucune native, ne lève jamais d'erreur sur
           une donnée reçue.
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs, next, tostring, tonumber = type, pairs, ipairs, next, tostring, tonumber
local floor, huge, mathType, tointeger = math.floor, math.huge, math.type, math.tointeger
local find, format, gmatch = string.find, string.format, string.gmatch
local sort = table.sort

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

-- fiche fusionnée : classe (config_client.lua → weaponClasses) et part du serveur (config.lua → weapons)
local WEAPON_KEYS = {
    category = true, family = true, kind = true, damage = true, reachBonus = true, durability = true, block = true,
    provisional = true,
}
local CLASS_KEYS = { category = true, family = true }

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

--- Fiche d'une arme : sa classe (catégorie, famille) et la part du serveur, en une table (copie). Une des deux absente :
--- nil.
---@param class any  config.weaponClasses[objet]
---@param fiche any  config.weapons[objet]
---@return table|nil
function weapons.merge(class, fiche)
    if type(class) ~= 'table' or type(fiche) ~= 'table' then return nil end
    local out = {}
    for key, value in pairs(fiche) do out[key] = value end
    for key, value in pairs(class) do out[key] = value end
    return out
end

--- Les deux parts de la config vont ensemble (1.2.0) : classes dans config_client.lua, fiches et délais du serveur du
--- bouclier dans config.lua, mêmes objets des deux côtés.
---@param cfg table
---@return boolean ok
---@return string|nil err
local function checkParts(cfg)
    if type(cfg.weaponClasses) ~= 'table' then
        return false, "config_client.lua d'avant 1.2.0 : les fiches des armes y sont maintenant `weaponClasses` "
            .. "(catégorie, famille) ; reportez vos changements d'après config_client.lua.nouveau"
    end
    if type(cfg.weapons) ~= 'table' or type(cfg.shield) ~= 'table' or cfg.shield.toggleMs == nil then
        return false, "config.lua d'avant 1.2.0 : les fiches des armes (weapons) et les délais du serveur du bouclier "
            .. "(shield.toggleMs…) y sont maintenant ; reportez vos changements d'après config.lua.nouveau"
    end
    for name, fiche in pairs(cfg.weapons) do
        if type(fiche) == 'table' and (fiche.category ~= nil or fiche.family ~= nil) then
            return false, format("config.lua d'avant 1.2.0 : arme '%s' : catégorie et famille sont dans "
                .. 'config_client.lua (weaponClasses)', tostring(name))
        end
        if cfg.weaponClasses[name] == nil then
            return false, format("arme '%s' : fiche sans classe dans weaponClasses (config_client.lua)", tostring(name))
        end
    end
    for name, class in pairs(cfg.weaponClasses) do
        if cfg.weapons[name] == nil then
            return false, format("arme '%s' : classe sans fiche dans weapons (config.lua)", tostring(name))
        end
        if type(class) ~= 'table' then return false, format("arme '%s' : classe attendue (table)", tostring(name)) end
        for key in pairs(class) do
            if not CLASS_KEYS[key] then
                return false, format("arme '%s' : clé '%s' hors de la classe (category, family)", tostring(name),
                    tostring(key))
            end
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
    local partsOk, partsErr = checkParts(cfg)
    if not partsOk then return false, partsErr end
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
    for name, fiche in pairs(cfg.weapons) do
        local def = weapons.merge(cfg.weaponClasses[name], fiche)
        if not def then return false, format("arme '%s' : fiche attendue", tostring(name)) end
        local ok, err = checkWeapon(name, def, cfg, categories)
        if not ok then return false, err end
    end
    for name in pairs(cfg.items) do
        if not cfg.weapons[name] then return false, format("items : '%s' n'est pas une arme du catalogue", tostring(name)) end
    end
    for name in pairs(cfg.shields) do
        local class = cfg.weaponClasses[name]
        if not class or class.category ~= SHIELD then
            return false, format("shields : '%s' n'est pas un bouclier du catalogue", tostring(name))
        end
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

-- Techniques et styles (docs/plan/COMBAT_V1.md § 3 ; bornes des curseurs de la maquette Combat) -------------------------

local TECHNIQUE_KEYS = {
    label = true, style = true, type = true, gesture = true, phases = true, hit = true, damage = true, stamina = true,
    parryable = true, staggers = true, chain = true, learn = true,
}
local GESTURE_KEYS = { dict = true, clip = true, flag = true }
local PHASE_KEYS = { windup = true, active = true, recovery = true }
local HIT_KEYS = { range = true, angle = true }
local LEARN_KEYS = { skill = true, level = true }
local STYLE_KEYS = { label = true, keys = true }
local TECHNIQUE_PATTERN, TECHNIQUE_MAX = VavaCombat.TECHNIQUE_PATTERN, VavaCombat.TECHNIQUE_MAX
local TYPES = setOf(VavaCombat.TECHNIQUE_TYPES)
local ATTACKS = setOf(VavaCombat.ATTACK_TYPES)
local LABEL_MAX, GESTURE_MAX, SKILL_MAX = 48, 64, 32
local CHAIN_MAX = 4
local PHASES_TOTAL_MAX = 3000

---@param value any
---@param max integer
---@return boolean
local function text(value, max)
    return type(value) == 'string' and #value >= 1 and #value <= max
end

--- Première clé de `map` hors de `allowed`, ou nil.
---@param map table
---@param allowed table<string, true>
---@return any
local function extraKey(map, allowed)
    for key in pairs(map) do
        if not allowed[key] then return key end
    end
    return nil
end

---@param value any
---@param low number
---@param high number
---@return boolean
local function between(value, low, high)
    return finite(value) and value >= low and value <= high
end

--- Liste pure (indices 1 à n, aucune autre clé), de `max` éléments au plus.
---@param list any
---@param max integer
---@return boolean
local function pureList(list, max)
    if type(list) ~= 'table' then return false end
    local count = 0
    for _ in pairs(list) do count = count + 1 end
    return count == #list and count <= max
end

--- Geste : { dict, clip } chaînes de 1 à 64 octets, `flag` entier de 0 à 65535, aucune autre clé. Rend nil ou la raison.
---@param gesture any
---@return string|nil
local function gestureError(gesture)
    if type(gesture) ~= 'table' then return 'geste attendu ({ dict, clip, flag })' end
    local extra = extraKey(gesture, GESTURE_KEYS)
    if extra ~= nil then return format("geste : clé inconnue '%s'", tostring(extra)) end
    if not text(gesture.dict, GESTURE_MAX) or not text(gesture.clip, GESTURE_MAX) then
        return format('geste : dict et clip attendus (1 à %d octets)', GESTURE_MAX)
    end
    if integerIn(gesture.flag, 0, 65535) == nil then return 'geste : flag entier de 0 à 65535 attendu' end
    return nil
end
weapons.gestureError = gestureError

---@param id any
---@param def any
---@param styles table
---@return string|nil err
local function techniqueError(id, def, styles)
    if type(id) ~= 'string' or #id > TECHNIQUE_MAX or not find(id, TECHNIQUE_PATTERN) then
        return format("technique '%s' : identifiant invalide (^[a-z0-9_]+$, %d octets au plus)", tostring(id), TECHNIQUE_MAX)
    end
    local function fail(fmt, ...) return format("technique '%s' : " .. fmt, id, ...) end
    if type(def) ~= 'table' then return fail('table attendue') end
    local extra = extraKey(def, TECHNIQUE_KEYS)
    if extra ~= nil then return fail("clé inconnue '%s'", tostring(extra)) end
    if not text(def.label, LABEL_MAX) then return fail('label attendu (1 à %d octets)', LABEL_MAX) end
    if type(def.style) ~= 'string' or type(styles[def.style]) ~= 'table' then
        return fail("style inconnu '%s'", tostring(def.style))
    end
    if not TYPES[def.type] then return fail("type inconnu '%s'", tostring(def.type)) end
    local gestureErr = gestureError(def.gesture)
    if gestureErr then return fail('%s', gestureErr) end
    local p = def.phases
    if type(p) ~= 'table' or extraKey(p, PHASE_KEYS) ~= nil then
        return fail('phases attendues ({ windup, active, recovery })')
    end
    local windup, active, recovery = integerIn(p.windup, 80, 1500), integerIn(p.active, 40, 500), integerIn(p.recovery, 0, 2000)
    if not windup then return fail('phases.windup entier de 80 à 1 500 ms attendu') end
    if not active then return fail('phases.active entier de 40 à 500 ms attendu') end
    if not recovery then return fail('phases.recovery entier de 0 à 2 000 ms attendu') end
    if windup + active + recovery > PHASES_TOTAL_MAX then return fail('phases : 3 000 ms au plus en tout') end
    local hit = def.hit
    if type(hit) ~= 'table' or extraKey(hit, HIT_KEYS) ~= nil then return fail('hit attendu ({ range, angle })') end
    if not between(hit.range, 1.0, 4.0) then return fail('hit.range attendu de 1 à 4 m') end
    if not between(hit.angle, 10, 180) then return fail('hit.angle attendu de 10 à 180 degrés') end
    if not between(def.damage, 0.5, 2.0) then return fail('damage attendu de 0,5 à 2') end
    if integerIn(def.stamina, 0, 40) == nil then return fail('stamina entier de 0 à 40 attendu') end
    if type(def.parryable) ~= 'boolean' then return fail('parryable attendu (booléen)') end
    if type(def.staggers) ~= 'boolean' then return fail('staggers attendu (booléen)') end
    if not pureList(def.chain, CHAIN_MAX) then return fail('chain : liste de %d techniques au plus attendue', CHAIN_MAX) end
    if def.learn ~= nil then
        local learn = def.learn
        if type(learn) ~= 'table' or extraKey(learn, LEARN_KEYS) ~= nil or not text(learn.skill, SKILL_MAX)
            or not find(learn.skill, ID_PATTERN) or integerIn(learn.level, 0, 100) == nil then
            return fail('learn : { skill (^[a-z0-9_]+$, %d octets), level entier de 0 à 100 } attendu', SKILL_MAX)
        end
    end
    return nil
end

--- Contrôle des techniques et des styles de la config (format de COMBAT_V1.md § 3). Rend `true, avertissements`
--- (technique que rien n'ouvre et qu'aucune chaîne n'atteint : une ligne chacune), ou `false, raison` à la première
--- erreur.
---@param cfg table
---@return boolean ok
---@return string|string[] err_or_warnings
function weapons.checkTechniques(cfg)
    if type(cfg) ~= 'table' or type(cfg.techniques) ~= 'table' or type(cfg.styles) ~= 'table' then
        return false, 'techniques et styles : tables attendues'
    end
    local techniques, styles = cfg.techniques, cfg.styles
    for id, def in pairs(techniques) do
        local err = techniqueError(id, def, styles)
        if err then return false, err end
    end
    local reached = {}
    for id, def in pairs(techniques) do
        local seen = {}
        for _, chained in ipairs(def.chain) do
            local other = techniques[chained]
            if type(chained) ~= 'string' or type(other) ~= 'table' then
                return false, format("technique '%s' : chain vers une technique inconnue '%s'", id, tostring(chained))
            end
            if chained == id then return false, format("technique '%s' : chain vers elle-même", id) end
            if other.style ~= def.style then
                return false, format("technique '%s' : chain vers '%s', d'un autre style", id, chained)
            end
            if seen[chained] then return false, format("technique '%s' : '%s' deux fois dans chain", id, chained) end
            seen[chained], reached[chained] = true, true
        end
    end
    for name, style in pairs(styles) do
        if type(name) ~= 'string' or #name > TECHNIQUE_MAX or not find(name, ID_PATTERN) then
            return false, format("style '%s' : identifiant invalide", tostring(name))
        end
        if type(style) ~= 'table' or extraKey(style, STYLE_KEYS) ~= nil or not text(style.label, LABEL_MAX)
            or type(style.keys) ~= 'table' then
            return false, format("style '%s' : { label (1 à %d octets), keys } attendu", name, LABEL_MAX)
        end
        for slot, id in pairs(style.keys) do
            if not ATTACKS[slot] then return false, format("style '%s' : touche inconnue '%s'", name, tostring(slot)) end
            local def = type(id) == 'string' and techniques[id] or nil
            if type(def) ~= 'table' or def.style ~= name or def.type ~= slot then
                return false, format("style '%s' : la touche %s doit ouvrir une technique %s de ce style", name, slot, slot)
            end
            reached[id] = true
        end
    end
    local warnings = {}
    for id in pairs(techniques) do
        if not reached[id] then
            warnings[#warnings + 1] = format("technique '%s' : aucune touche ne l'ouvre et aucune chaîne ne l'atteint", id)
        end
    end
    sort(warnings)
    return true, warnings
end

--- Contrôle des réglages du moteur (cycle, tolérances bornées, géométrie, bond, réactions, dégainer, chancellement).
--- Rend `true`, ou `false, raison` à la première erreur.
---@param cfg table
---@return boolean ok
---@return string|nil err
function weapons.checkEngine(cfg)
    local r = type(cfg.rateLimits) == 'table' and cfg.rateLimits.use
    if type(r) ~= 'table' or integerIn(r.capacity, 1, 100) == nil or not between(r.refillPerSecond, 0.01, 100) then
        return false, 'rateLimits.use : { capacity entier de 1 à 100, refillPerSecond > 0 } attendu'
    end
    local t = cfg.timing
    if type(t) ~= 'table' or integerIn(t.earlyMs, 0, 500) == nil or integerIn(t.chainMax, 0, 10) == nil
        or integerIn(t.samples, 1, 2) == nil or integerIn(t.staggerImmunityMs, 0, 60000) == nil then
        return false, 'timing : earlyMs (0 à 500), chainMax (0 à 10), samples (1 ou 2), staggerImmunityMs entiers attendus'
    end
    local tol = cfg.tolerance
    if type(tol) ~= 'table' or not between(tol.range, 0, 1.0) or not between(tol.angle, 0, 30)
        or not between(tol.height, 0, 1.0) then
        return false, 'tolerance : range de 0 à 1 m, angle de 0 à 30 degrés, height de 0 à 1 m attendus'
    end
    local g = cfg.geometry
    if type(g) ~= 'table' or not between(g.maxHeight, 0.1, 5) or not between(g.closeRange, 0, 2)
        or integerIn(g.maxTargets, 1, 8) == nil or not between(g.searchMargin, 0, 5) then
        return false, 'geometry : maxHeight (0,1 à 5), closeRange (0 à 2), maxTargets (1 à 8), searchMargin (0 à 5) attendus'
    end
    local l = cfg.lunge
    if type(l) ~= 'table' or not between(l.maxSpeed, 0.1, 30) or not between(l.margin, 0, 5) then
        return false, 'lunge : maxSpeed (0,1 à 30 m/s) et margin (0 à 5 m) attendus'
    end
    if type(cfg.reactions) ~= 'table' or not between(cfg.reactions.radius, 1, 100) then
        return false, 'reactions.radius attendu de 1 à 100 m'
    end
    if type(cfg.notices) ~= 'table' or integerIn(cfg.notices.intervalMs, 0, 3600000) == nil then
        return false, 'notices.intervalMs entier attendu'
    end
    if type(cfg.debug) ~= 'table' or type(cfg.debug.logSamples) ~= 'boolean' then
        return false, 'debug.logSamples attendu (booléen)'
    end
    local d = cfg.draw
    if type(d) ~= 'table' or integerIn(d.drawMs, 0, 5000) == nil or integerIn(d.sheatheMs, 0, 10000) == nil then
        return false, 'draw : drawMs (0 à 5 000) et sheatheMs (0 à 10 000) entiers attendus'
    end
    local err = gestureError(d.drawGesture) or gestureError(d.sheatheGesture)
    if err then return false, 'draw : ' .. err end
    local st = cfg.stagger
    if type(st) ~= 'table' or integerIn(st.durationMs, 0, 5000) == nil then
        return false, 'stagger.durationMs entier de 0 à 5 000 attendu'
    end
    err = gestureError(st.gesture)
    if err then return false, 'stagger : ' .. err end
    return true
end

-- Issue d'un coup -----------------------------------------------------------------------------------------------------

-- étape d'annulation de la chaîne → issue montrée (l'arme a été arrêtée)
local GUARDED = { esquive = 'dodge', parade = 'parry', blocage = 'block', bouclier = 'absorb' }

--- Issue d'un coup qui a atteint la chaîne (résultat de vava_health:hit), montrée aux proches : `down`, `dodge`,
--- `parry`, `block`, `absorb`, `hit` ; nil pour une autre annulation (cible à terre, combats coupés, attaquant à terre,
--- crochet, lieu de paix) : rien n'est montré.
---@param result any
---@return string|nil
function weapons.outcome(result)
    if type(result) ~= 'table' then return nil end
    if result.downed == true then return 'down' end
    if result.cancelled ~= nil then return GUARDED[result.stage] end
    local applied = finite(result.applied) and result.applied or 0
    if applied == 0 and finite(result.blocked) and result.blocked > 0 then return 'block' end
    if applied == 0 and finite(result.absorbed) and result.absorbed > 0 then return 'absorb' end
    return 'hit'
end

--- Avis à l'attaquant d'un coup retenu (clé de config.messages), ou nil : combats coupés (`pvpOff`), lieu de paix
--- (`peace`), refus d'un crochet `before` de la chaîne (`held`).
---@param result any
---@return string|nil
function weapons.noticeOf(result)
    if type(result) ~= 'table' or result.cancelled == nil then return nil end
    if result.cancelled == 'pvp_off' then return 'pvpOff' end
    if result.cancelled == 'zone_protegee' then return 'peace' end
    if result.stage == 'before' then return 'held' end
    return nil
end

--- Raison d'un refus d'un crochet, à montrer au joueur : chaîne sans caractère de contrôle, coupée à `max` octets sans
--- couper un caractère UTF-8 ; vide ou autre chose : nil.
---@param reason any
---@param max integer
---@return string|nil
function weapons.reasonText(reason, max)
    if type(reason) ~= 'string' then return nil end
    local clean = reason:gsub('[\0-\31\127]', ' ')
    if #clean > max then
        local cut = max + 1
        while cut > 1 and (clean:byte(cut) or 0) >= 0x80 and (clean:byte(cut) or 0) <= 0xBF do cut = cut - 1 end
        clean = clean:sub(1, cut - 1)
    end
    clean = clean:match('^ *(.-) *$')
    if clean == '' then return nil end
    return clean
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

-- Tri des libellés ----------------------------------------------------------------------------------------------------

-- lettres accentuées du français (UTF-8) ramenées à leur lettre de base, pour trier « Épée » avec les « e »
local FOLD = {
    ['à'] = 'a', ['â'] = 'a', ['ä'] = 'a', ['À'] = 'a', ['Â'] = 'a', ['Ä'] = 'a',
    ['é'] = 'e', ['è'] = 'e', ['ê'] = 'e', ['ë'] = 'e', ['É'] = 'e', ['È'] = 'e', ['Ê'] = 'e', ['Ë'] = 'e',
    ['î'] = 'i', ['ï'] = 'i', ['Î'] = 'i', ['Ï'] = 'i', ['ô'] = 'o', ['ö'] = 'o', ['Ô'] = 'o', ['Ö'] = 'o',
    ['ù'] = 'u', ['û'] = 'u', ['ü'] = 'u', ['Ù'] = 'u', ['Û'] = 'u', ['Ü'] = 'u', ['ç'] = 'c', ['Ç'] = 'c',
    ['œ'] = 'oe', ['Œ'] = 'oe', ['æ'] = 'ae', ['Æ'] = 'ae',
}

--- Clé de tri d'un libellé : lettres accentuées ramenées à leur base, casse ignorée (octets ASCII seulement baissés :
--- string.lower suit la locale du système).
---@param label any
---@return string
function weapons.sortKey(label)
    if type(label) ~= 'string' then return '' end
    local folded = label:gsub('[\xC3\xC5][\x80-\xBF]', FOLD)
    return (folded:gsub('[A-Z]', function(c) return string.char(c:byte() + 32) end))
end

-- Réponses regroupées -------------------------------------------------------------------------------------------------

--- Regroupe des lignes en messages d'au plus `max` octets, joints par `sep`, dans l'ordre ; une ligne plus longue que
--- `max` part seule (le destinataire la coupe).
---@param lines string[]
---@param max integer
---@param sep string
---@return string[]
function weapons.groupLines(lines, max, sep)
    local out, current = {}, nil
    for _, line in ipairs(lines) do
        if current and #current + #sep + #line <= max then
            current = current .. sep .. line
        else
            if current then out[#out + 1] = current end
            current = line
        end
    end
    if current then out[#out + 1] = current end
    return out
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
