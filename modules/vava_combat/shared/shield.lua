--[[
    vava_combat/shared/shield.lua
    Rôle : règles pures du bouclier accroché, côté client et serveur. La valeur publiée sur le statebag du ped du porteur
           est réduite à { id, item } : le placement (modèle, os, décalage, rotation) se lit dans la config de chaque
           client, et la position (bras ou dos) se déduit de ce que le porteur tient en main. Ces règles disent où
           porter le bouclier, quel placement montrer, si une valeur est publiable et si deux valeurs sont la même
           (garde du serveur), quel ped vise un statebag, et quand remettre une valeur réécrite par un client. Les
           règles de valeur et de garde sont celles de vava_inventory/shared/held.lua, recopiées (une ressource n'en
           charge pas une autre).
    Dépendances : shared/constants.lua
]]

local type, next, tonumber, ipairs = type, next, tonumber, ipairs
local min, mathType, tointeger = math.min, math.type, math.tointeger
local match = string.match

local MAX_ID = VavaCombat.MAX_ID
local ITEM_MAX = VavaCombat.ITEM_MAX
-- au-delà, le décalage du délai déborderait : le plafond est atteint bien avant
local MAX_SHIFT = 20
local ARM, BACK = 'arm', 'back'

local shield = {}
VavaCombat.shield = shield
shield.ARM, shield.BACK = ARM, BACK

---@param id any
---@return boolean
local function validId(id)
    if type(id) ~= 'number' then return false end
    if mathType(id) == 'float' and (id ~= id or id % 1 ~= 0) then return false end
    return id >= 1 and id <= MAX_ID
end

---@param item any
---@return boolean
local function validItem(item)
    return type(item) == 'string' and #item >= 1 and #item <= ITEM_MAX
end

--- Position du bouclier : au bras si l'objet en main est une arme dont la catégorie est dans `rules.armWith`, ou si les
--- mains sont vides et `rules.armWithEmptyHand` ; dans le dos sinon (arme à deux mains, bâton, outil, objet inconnu).
---@param handItem string|nil  objet tenu en main (nil : mains vides)
---@param weapons table        fiches des armes (config.weapons)
---@param rules { armWith: string[], armWithEmptyHand: boolean }  config.shield
---@return string 'arm' | 'back'
function shield.position(handItem, weapons, rules)
    if handItem == nil then return rules.armWithEmptyHand == true and ARM or BACK end
    local def = type(handItem) == 'string' and type(weapons) == 'table' and weapons[handItem] or nil
    if type(def) ~= 'table' then return BACK end
    for _, category in ipairs(rules.armWith) do
        if def.category == category then return ARM end
    end
    return BACK
end

--- Placement à montrer pour un bouclier et une position, ou nil (objet absent de la config des boucliers).
---@param item string
---@param position string  'arm' | 'back'
---@param shields table    config.shields
---@return { model: string, bone: integer, offset: number[], rotation: number[] }|nil
function shield.placement(item, position, shields)
    if type(shields) ~= 'table' or type(item) ~= 'string' then return nil end
    local def = shields[item]
    if type(def) ~= 'table' then return nil end
    local place = def[position == ARM and ARM or BACK]
    if type(place) ~= 'table' then return nil end
    return { model = def.model, bone = place.bone, offset = place.offset, rotation = place.rotation }
end

--- Valeur publiée pour un bouclier accroché : { id, item }.
---@param id integer
---@param item string
---@return table
function shield.value(id, item)
    return { id = id, item = item }
end

--- Vrai si `value` est publiable : nil (rien d'accroché) ou une table à exactement deux clés, `id` et `item`, bien
--- formées. Une table venue d'un client peut avoir n'importe quelle forme : au plus trois clés sont parcourues.
---@param value any
---@return boolean
function shield.valid(value)
    if value == nil then return true end
    if type(value) ~= 'table' or not validId(value.id) or not validItem(value.item) then return false end
    local count, key = 0, nil
    repeat
        key = next(value, key)
        if key ~= nil then count = count + 1 end
    until key == nil or count > 2
    return count == 2
end

--- Vrai si deux valeurs sont la même : toutes deux nil, ou toutes deux valides avec le même `id` et le même `item`. Une
--- valeur mal formée n'est égale à rien (pas même à elle-même) : la garde la remplace toujours.
---@param a any
---@param b any
---@return boolean
function shield.same(a, b)
    if a == nil or b == nil then return a == nil and b == nil end
    if not shield.valid(a) or not shield.valid(b) then return false end
    return a.id == b.id and a.item == b.item
end

--- Numéro réseau d'une entité d'après le nom de son statebag (`entity:<n>`), ou nil pour tout autre statebag.
---@param bagName any
---@return integer|nil
function shield.netIdOf(bagName)
    if type(bagName) ~= 'string' then return nil end
    local digits = match(bagName, '^entity:(%d+)$')
    if not digits or #digits > 9 then return nil end
    local netId = tointeger(tonumber(digits))
    if not netId or netId < 1 then return nil end
    return netId
end

--- Délai avant de remettre la valeur du serveur sur un ped dont le statebag a été réécrit : `guardDelayMs` tant que la
--- valeur n'a pas été remise `guardMaxCorrections` fois depuis la dernière publication, puis doublé à chaque remise
--- jusqu'à `guardMaxDelayMs`.
---@param streak integer  remises déjà faites depuis la dernière publication
---@param cfg { guardDelayMs: integer, guardMaxCorrections: integer, guardMaxDelayMs: integer }
---@return integer
function shield.guardDelay(streak, cfg)
    local over = streak - cfg.guardMaxCorrections
    if over < 0 then return cfg.guardDelayMs end
    if over >= MAX_SHIFT then return cfg.guardMaxDelayMs end
    return min(cfg.guardDelayMs << (over + 1), cfg.guardMaxDelayMs)
end
