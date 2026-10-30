--[[
    vava_provisions/shared/rules.lua
    Rôle : logique PURE des vivres (aucune native, testée hors jeu : tests/spec/provisions_rules_spec.lua) : validation
           d'un point d'eau (seul juge, repris tel quel par le futur éditeur de l'Atelier) et de la config, réserve d'un
           point (niveau, attente), choix de l'action au point d'eau, contenant gardé ou fendu, lecture de /eau, textes
           montrés au joueur et au Conseil. Motifs écrits octet par octet (ni %c, ni %s, ni %w : ils dépendent de la
           locale du système et prendraient des octets d'un caractère accentué).
    Dépendances : shared/constants.lua
]]

local type, pairs, ipairs, next, tostring, tonumber = type, pairs, ipairs, next, tostring, tonumber
local mathType, tointeger, floor, ceil, min, max, huge = math.type, math.tointeger, math.floor, math.ceil, math.min, math.max, math.huge
local find, format, gsub, sub, byte = string.find, string.format, string.gsub, string.sub, string.byte
local utf8len = utf8.len

local ACTIONS = VavaProvisions.ACTIONS
local ID_PATTERN, ID_MAX = VavaProvisions.ID_PATTERN, VavaProvisions.ID_MAX
local LABEL_MAX, KIND_LABEL_MAX, MODEL_MAX = VavaProvisions.LABEL_MAX, VavaProvisions.KIND_LABEL_MAX, VavaProvisions.MODEL_MAX
local MAX_COORD, MAX_Z = VavaProvisions.MAX_COORD, VavaProvisions.MAX_Z
local MAX_NOTIFICATION, MAX_POINTS = VavaProvisions.MAX_NOTIFICATION, VavaProvisions.MAX_POINTS

-- nom de modèle : lettres ASCII, chiffres, « _ » (écrit en clair : %w dépend de la locale)
local MODEL_PATTERN = '^[A-Za-z0-9_]+$'
-- caractères de contrôle ASCII, écrits octet par octet (jamais %c : T-133)
local CONTROL_PATTERN = '[\0-\31\127]'
-- nom d'objet de l'inventaire et clé d'effet (bornes de vava_inventory)
local ITEM_PATTERN = '^[a-z0-9_]+$'
local EFFECT_PATTERN = '^[A-Za-z_][A-Za-z0-9_]*$'
local ITEM_SIZE_MAX, ITEM_QUANTITY_MAX, EFFECT_ENTRIES_MAX, EFFECT_VALUE_MAX = 8, 1000000, 8, 1000

-- codes de refus du serveur → clé du texte dans `messages`
local REFUSAL_KEYS = {
    wait = 'wait', too_far = 'tooFar', not_thirsty = 'notThirsty', no_container = 'noContainer', no_space = 'noSpace',
    too_heavy = 'tooHeavy', unavailable = 'unavailable',
}
local NOTICE_KEYS = { torn = 'torn', lost = 'lost' }

local rules = {}
VavaProvisions.rules = rules

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end
rules.finite = finite

---@param value any
---@param low integer
---@param high integer
---@return boolean
local function integerIn(value, low, high)
    return mathType(value) == 'integer' and value >= low and value <= high
end

--- Vrai si `value` est une liste pure (clés 1..n sans trou, aucune autre clé ; `{}` en est une).
---@param value any
---@return boolean
local function isList(value)
    if type(value) ~= 'table' then return false end
    local count = 0
    for key in pairs(value) do
        if mathType(key) ~= 'integer' or key < 1 then return false end
        count = count + 1
    end
    return count == #value
end

--- Vrai si `value` est un identifiant de point ou de sorte (32 octets, minuscules ASCII, chiffres, « _ »).
---@param value any
---@return boolean
function rules.isId(value)
    return type(value) == 'string' and #value >= 1 and #value <= ID_MAX and find(value, ID_PATTERN) ~= nil
end

--- Texte UTF-8 valide, sans caractère de contrôle, bords (espaces) retirés, de 1 à `maxBytes` octets ; sinon nil.
---@param value any
---@param maxBytes integer
---@return string|nil
function rules.cleanText(value, maxBytes)
    if type(value) ~= 'string' or utf8len(value) == nil or find(value, CONTROL_PATTERN) then return nil end
    local trimmed = gsub(gsub(value, '^ +', ''), ' +$', '')
    if #trimmed < 1 or #trimmed > maxBytes then return nil end
    return trimmed
end

--- Texte coupé à `maxBytes` octets sans briser un caractère UTF-8, contrôles remplacés par une espace ; nil si vide
--- ou si ce n'est pas un texte.
---@param value any
---@param maxBytes integer
---@return string|nil
function rules.cutText(value, maxBytes)
    if type(value) ~= 'string' then return nil end
    local text = gsub(value, CONTROL_PATTERN, ' ')
    if #text > maxBytes then
        local cut = maxBytes
        -- recule tant que l'octet suivant la coupe est un octet de suite (10xxxxxx) : le caractère entier part
        while cut > 0 and (byte(text, cut + 1) or 0) >= 0x80 and (byte(text, cut + 1) or 0) < 0xC0 do cut = cut - 1 end
        text = sub(text, 1, cut)
    end
    if utf8len(text) == nil then return nil end
    text = gsub(gsub(text, '^ +', ''), ' +$', '')
    if text == '' then return nil end
    return text
end

--- Nom de modèle : absent (nil), '' (aucun prop) ou 1 à 64 octets `^[A-Za-z0-9_]+$`.
---@param value any
---@return boolean
function rules.isModel(value)
    if value == nil or value == '' then return true end
    return type(value) == 'string' and #value <= MODEL_MAX and find(value, MODEL_PATTERN) ~= nil
end

--- Cap ramené dans [0, 360).
---@param heading number
---@return number
function rules.heading(heading)
    local value = heading % 360
    if value < 0 then value = value + 360 end
    return value + 0.0
end

--- Valide un point d'eau : SEUL juge (config, futur éditeur de l'Atelier). Rend une copie normalisée (nom nettoyé,
--- cap dans [0, 360), modèle résolu : celui du point, sinon celui de la sorte ; '' : aucun prop).
---@param def any   { id, kind, label, x, y, z, heading?, model? }
---@param kinds table<string, table>
---@return boolean ok
---@return table|string pointOrCode   point, ou invalid_id | unknown_kind | invalid_label | invalid_position | invalid_heading | invalid_model
---@return string|nil field
function rules.validatePoint(def, kinds)
    if type(def) ~= 'table' then return false, 'invalid_id', 'id' end
    if not rules.isId(def.id) then return false, 'invalid_id', 'id' end
    local kind = type(def.kind) == 'string' and type(kinds) == 'table' and kinds[def.kind] or nil
    if type(kind) ~= 'table' then return false, 'unknown_kind', 'kind' end
    local label = rules.cleanText(def.label, LABEL_MAX)
    if not label then return false, 'invalid_label', 'label' end
    for _, axis in ipairs({ 'x', 'y' }) do
        local value = def[axis]
        if not finite(value) or value > MAX_COORD or value < -MAX_COORD then return false, 'invalid_position', axis end
    end
    if not finite(def.z) or def.z > MAX_Z or def.z < -MAX_Z then return false, 'invalid_position', 'z' end
    local heading = def.heading
    if heading == nil then heading = 0.0 end
    if not finite(heading) then return false, 'invalid_heading', 'heading' end
    if not rules.isModel(def.model) then return false, 'invalid_model', 'model' end
    local model = def.model
    if model == nil then model = type(kind.model) == 'string' and kind.model or '' end
    return true, {
        id = def.id, kind = def.kind, label = label, x = def.x + 0.0, y = def.y + 0.0, z = def.z + 0.0,
        heading = rules.heading(heading), model = model,
    }
end

--- Vrai si le texte « à sec » est un format sûr : 1 à 200 octets, UTF-8 valide, au plus un `%d` et aucune autre
--- directive (`%%` permis).
---@param value any
---@return boolean
local function validDry(value)
    if type(value) ~= 'string' or #value < 1 or #value > MAX_NOTIFICATION or utf8len(value) == nil then return false end
    local rest = gsub(value, '%%%%', '')
    local count = 0
    for directive in rest:gmatch('%%(.?)') do
        if directive ~= 'd' then return false end
        count = count + 1
    end
    return count <= 1
end

--- Valide une sorte de point d'eau.
---@param id any
---@param kind any
---@return boolean ok
---@return string|nil code
---@return string|nil field
function rules.validateKind(id, kind)
    if not rules.isId(id) then return false, 'invalid_id', 'id' end
    if type(kind) ~= 'table' then return false, 'invalid_kind', nil end
    if not rules.cleanText(kind.label, KIND_LABEL_MAX) then return false, 'invalid_label', 'label' end
    if not rules.isModel(kind.model) then return false, 'invalid_model', 'model' end
    local reserve = kind.reserve
    if type(reserve) ~= 'table' or not integerIn(reserve.capacity, 0, 1000) then return false, 'invalid_capacity', 'reserve.capacity' end
    if reserve.capacity > 0 and not integerIn(reserve.refillSeconds, 1, 86400) then
        return false, 'invalid_refill', 'reserve.refillSeconds'
    end
    if type(kind.drink) ~= 'boolean' then return false, 'invalid_drink', 'drink' end
    if not validDry(kind.dry) then return false, 'invalid_dry', 'dry' end
    return true
end

--- Valide un objet déclaré à l'inventaire (forme de docs/api.md § vava_inventory ; aucune image écrite en dur).
---@param name any
---@param def any
---@return boolean ok
---@return string|nil code
---@return string|nil field
function rules.validateItem(name, def)
    if type(name) ~= 'string' or #name < 1 or #name > 64 or not find(name, ITEM_PATTERN) then return false, 'invalid_name', nil end
    if type(def) ~= 'table' then return false, 'invalid_item', nil end
    if not rules.cleanText(def.label, 48) then return false, 'invalid_label', 'label' end
    if def.description ~= nil and (type(def.description) ~= 'string' or #def.description > 300) then
        return false, 'invalid_description', 'description'
    end
    if not integerIn(def.width, 1, ITEM_SIZE_MAX) or not integerIn(def.height, 1, ITEM_SIZE_MAX) then return false, 'invalid_size', 'width' end
    if not integerIn(def.weight, 0, ITEM_QUANTITY_MAX) then return false, 'invalid_weight', 'weight' end
    if not integerIn(def.stack, 1, ITEM_QUANTITY_MAX) then return false, 'invalid_stack', 'stack' end
    if def.image ~= nil then return false, 'image_set', 'image' end
    if def.category ~= nil and (type(def.category) ~= 'string' or #def.category > 32) then return false, 'invalid_category', 'category' end
    if def.effects ~= nil then
        if type(def.effects) ~= 'table' then return false, 'invalid_effects', 'effects' end
        local count = 0
        for key, value in pairs(def.effects) do
            count = count + 1
            if type(key) ~= 'string' or #key > 32 or not find(key, EFFECT_PATTERN) or not finite(value)
                or value < -EFFECT_VALUE_MAX or value > EFFECT_VALUE_MAX then
                return false, 'invalid_effects', 'effects'
            end
        end
        if count < 1 or count > EFFECT_ENTRIES_MAX then return false, 'invalid_effects', 'effects' end
    end
    return true
end

---@param path string
---@param field string|nil
---@return string
local function join(path, field)
    if field == nil then return path end
    return path .. '.' .. field
end

--- Valide la config au démarrage. Rend `true`, ou `false, code, chemin` (« points[2].label », « invalid_label »).
---@param cfg table
---@return boolean ok
---@return string|nil code
---@return string|nil path
function rules.validateConfig(cfg)
    if type(cfg) ~= 'table' then return false, 'invalid_config', 'config' end
    local items = cfg.items
    if type(items) ~= 'table' then return false, 'invalid_items', 'items' end
    for name, def in pairs(items) do
        local ok, code, field = rules.validateItem(name, def)
        if not ok then return false, code, join('items.' .. tostring(name), field) end
    end
    local fill = cfg.fill
    if type(fill) ~= 'table' or type(fill.from) ~= 'string' or not items[fill.from] then return false, 'unknown_item', 'fill.from' end
    if type(fill.to) ~= 'string' or not items[fill.to] or fill.to == fill.from then return false, 'unknown_item', 'fill.to' end
    if not integerIn(fill.maxPerDraw, 1, 20) then return false, 'invalid_count', 'fill.maxPerDraw' end
    if type(cfg.containers) ~= 'table' then return false, 'invalid_containers', 'containers' end
    for item, container in pairs(cfg.containers) do
        local path = 'containers.' .. tostring(item)
        if type(item) ~= 'string' or not items[item] or type(container) ~= 'table' then return false, 'unknown_item', path end
        if type(container.empty) ~= 'string' or not items[container.empty] then return false, 'unknown_item', path .. '.empty' end
        local chance = container.tearChance
        if not finite(chance) or chance < 0 or chance > 1 then return false, 'invalid_chance', path .. '.tearChance' end
    end
    local recipe = cfg.recipe
    if recipe ~= nil then
        if type(recipe) ~= 'table' or not rules.isId(recipe.id) then return false, 'invalid_id', 'recipe.id' end
        if type(recipe.output) ~= 'table' or type(recipe.output.item) ~= 'string' or not items[recipe.output.item] then
            return false, 'unknown_item', 'recipe.output.item'
        end
    end
    local drink = cfg.drink
    if type(drink) ~= 'table' or not integerIn(drink.thirst, 1, 100) then return false, 'invalid_thirst', 'drink.thirst' end
    if not integerIn(drink.fullAt, 1, 100) then return false, 'invalid_thirst', 'drink.fullAt' end
    if not integerIn(cfg.cooldownMs, 500, 60000) then return false, 'invalid_delay', 'cooldownMs' end
    if type(cfg.kinds) ~= 'table' or next(cfg.kinds) == nil then return false, 'invalid_kinds', 'kinds' end
    for id, kind in pairs(cfg.kinds) do
        local ok, code, field = rules.validateKind(id, kind)
        if not ok then return false, code, join('kinds.' .. tostring(id), field) end
    end
    if not integerIn(cfg.maxPoints, 1, MAX_POINTS) then return false, 'invalid_count', 'maxPoints' end
    if not isList(cfg.points) then return false, 'invalid_list', 'points' end
    if #cfg.points > cfg.maxPoints then return false, 'too_many', 'points' end
    local seen = {}
    for index, def in ipairs(cfg.points) do
        local ok, result, field = rules.validatePoint(def, cfg.kinds)
        local path = format('points[%d]', index)
        if not ok then return false, result, join(path, field) end
        if seen[result.id] then return false, 'duplicate', path .. '.id' end
        seen[result.id] = true
    end
    local interact = cfg.interact
    if type(interact) ~= 'table' or not finite(interact.distance) or interact.distance <= 0 or interact.distance > 10 then
        return false, 'invalid_distance', 'interact.distance'
    end
    if not finite(interact.serverTolerance) or interact.serverTolerance < 0 or interact.serverTolerance > 5 then
        return false, 'invalid_distance', 'interact.serverTolerance'
    end
    return true
end

-- Réserve ---------------------------------------------------------------------------------------------------------

--- Niveau d'une réserve à `now` (secondes) : sans fond → math.huge ; sinon le niveau gardé plus un puisage par
--- `refillSeconds` écoulées, plafonné à la capacité (horloge revenue en arrière : rien de plus).
---@param stored number
---@param at number
---@param now number
---@param reserve { capacity: integer, refillSeconds?: integer }
---@return number
function rules.level(stored, at, now, reserve)
    if reserve.capacity == 0 then return huge end
    return min(reserve.capacity, stored + max(0, now - at) / reserve.refillSeconds)
end

--- Secondes avant qu'un puisage entier soit disponible (0 s'il l'est déjà).
---@param level number
---@param reserve { capacity: integer, refillSeconds?: integer }
---@return integer
function rules.waitSeconds(level, reserve)
    if reserve.capacity == 0 or level >= 1 then return 0 end
    return tointeger(ceil((1 - level) * reserve.refillSeconds)) or 0
end

--- Puisages entiers disponibles (math.huge sans fond).
---@param level number
---@return integer|number
function rules.available(level)
    if level == huge then return huge end
    return max(0, floor(level))
end

-- Décision -----------------------------------------------------------------------------------------------------

--- Choix de l'action au point d'eau (le client ne dit rien de ce qu'il veut) : remplir les outres vides s'il y a de
--- quoi, sinon boire si l'on peut et qu'on a soif ; sinon le refus qui explique le mieux.
---@param ctx { empties: integer, maxPerDraw: integer, available: number, drinkable: boolean, thirst: number|nil, fullAt: number }
---@return table|nil decision  { action = 'fill', count } | { action = 'drink', dry }
---@return string|nil code     dry | not_thirsty | no_container
function rules.decide(ctx)
    local empties = ctx.empties or 0
    if empties > 0 and ctx.available >= 1 then
        return { action = ACTIONS.FILL, count = min(empties, ctx.maxPerDraw, ctx.available) }
    end
    local drinkable = ctx.drinkable == true and type(ctx.thirst) == 'number'
    if drinkable and ctx.thirst < ctx.fullAt then
        return { action = ACTIONS.DRINK, dry = empties > 0 }
    end
    if empties > 0 then return nil, 'dry' end
    if drinkable then return nil, 'not_thirsty' end
    return nil, 'no_container'
end

--- Contenant gardé après une gorgée ? `roll` dans [0, 1) (tirage), `chance` : risque de fente (0 : toujours gardé,
--- 1 : toujours fendu).
---@param roll number
---@param chance number
---@return boolean
function rules.keepsContainer(roll, chance)
    return roll >= chance
end

-- Conseil ---------------------------------------------------------------------------------------------------------

--- Lit les arguments de /eau : `points`, ou `reserve <point> <nombre entier ≥ 0>` (la borne haute est celle de la
--- sorte, vérifiée par la commande).
---@param args any
---@return string|nil action   points | reserve
---@return string|nil pointOrCode  identifiant du point, ou 'usage'
---@return integer|nil amount
function rules.parseCommand(args)
    if type(args) ~= 'table' then return nil, 'usage' end
    local action = args[1]
    if action == 'points' then return 'points' end
    if action == 'reserve' then
        local id, raw = args[2], args[3]
        if not rules.isId(id) or type(raw) ~= 'string' or #raw > 4 or not find(raw, '^[0-9]+$') then return nil, 'usage' end
        local amount = tointeger(tonumber(raw))
        if not amount then return nil, 'usage' end
        return 'reserve', id, amount
    end
    return nil, 'usage'
end

--- Ligne de /eau points pour un point : nom, identifiant, sorte, réserve (« 12 / 40 puisages » ou « sans fond »).
---@param point { id: string, kind: string, label: string }
---@param reserve { level: number, capacity: integer }|nil   nil : sans fond
---@param messages table  messages.admin de la config
---@return string
function rules.describePoint(point, reserve, messages)
    local stock = messages.bottomless
    if reserve then stock = format(messages.level, rules.available(reserve.level), reserve.capacity) end
    return format(messages.line, point.label, point.id, point.kind, stock)
end

-- Textes au joueur ------------------------------------------------------------------------------------------------

--- Minutes d'attente annoncées (arrondies au-dessus, au moins 1).
---@param seconds any
---@return integer
function rules.dryMinutes(seconds)
    if not finite(seconds) or seconds <= 0 then return 1 end
    return max(1, tointeger(ceil(seconds / 60)) or 1)
end

--- Texte d'une action réussie (réponse du RPC), ou nil.
---@param result any  { action = 'fill', count } | { action = 'drink', dry }
---@param messages table
---@return string|nil
function rules.successText(result, messages)
    if type(result) ~= 'table' then return nil end
    if result.action == ACTIONS.FILL then
        local count = mathType(result.count) == 'integer' and result.count or 1
        if count <= 1 then return messages.filledOne end
        return format(messages.filledMany, count)
    end
    if result.action == ACTIONS.DRINK then
        return result.dry == true and messages.drankDry or messages.drank
    end
    return nil
end

--- Texte d'un refus du serveur, ou nil quand il n'y a rien à dire (sans personnage, à terre, occupé, point inconnu).
--- `dry` : texte de la sorte avec les minutes d'attente ; `refused` : raison du hook, coupée à 200 octets.
---@param code any
---@param extra any       secondes (dry), raison (refused)
---@param kind table|nil  sorte du point (dry)
---@param messages table
---@return string|nil
function rules.refusalText(code, extra, kind, messages)
    if code == 'dry' then
        if type(kind) ~= 'table' or type(kind.dry) ~= 'string' then return messages.unavailable end
        return format(kind.dry, rules.dryMinutes(extra))
    end
    if code == 'refused' then return rules.cutText(extra, MAX_NOTIFICATION) end
    local key = REFUSAL_KEYS[code]
    return key and messages[key] or nil
end

--- Texte d'un avis du serveur (outre fendue, perdue), ou nil pour toute autre valeur.
---@param code any
---@param messages table
---@return string|nil
function rules.noticeText(code, messages)
    local key = NOTICE_KEYS[code]
    return key and messages[key] or nil
end

--- Verbe de l'invite selon la sorte : on y boit (« Puiser ou boire »), ou on n'y fait que puiser.
---@param kind table|nil
---@param prompt { both: string, fill: string }
---@return string
function rules.promptVerb(kind, prompt)
    if type(kind) == 'table' and kind.drink == true then return prompt.both end
    return prompt.fill
end
