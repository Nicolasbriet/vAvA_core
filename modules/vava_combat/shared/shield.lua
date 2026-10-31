--[[
    vava_combat/shared/shield.lua
    Rôle : règles pures du bouclier accroché, côté client et serveur. La valeur publiée sur le statebag du ped du porteur
           est réduite à { id, item } : le placement (modèle, os, décalage, rotation) se lit dans la config de chaque
           client, et la position (bras ou dos) se déduit de ce que le porteur tient en main. Ces règles disent où
           porter le bouclier, quel placement montrer, si une valeur est publiable et si deux valeurs sont la même
           (garde du serveur), et quel ped vise un statebag. Les règles de valeur sont celles de
           vava_inventory/shared/held.lua, recopiées (une ressource n'en charge pas une autre) ; le délai de la garde,
           appliqué par le seul serveur, est dans shared/guard.lua (servi au seul serveur depuis 1.2.0).
    Dépendances : shared/constants.lua
]]

local type, next, tonumber, ipairs = type, next, tonumber, ipairs
local mathType, tointeger = math.type, math.tointeger
local match = string.match

local MAX_ID = VavaCombat.MAX_ID
local ITEM_MAX = VavaCombat.ITEM_MAX
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

--- Position du bouclier : au bras si l'objet en main est une arme dont la catégorie est dans `armWith`, ou si les mains
--- sont vides et `armWithEmptyHand` ; dans le dos sinon (arme à deux mains, bâton, outil, objet inconnu).
---@param handItem string|nil  objet tenu en main (nil : mains vides)
---@param classes table        classes des armes (config.weaponClasses : catégorie, famille)
---@param armWith string[]     catégories qui font porter le bouclier au bras (config.shield.armWith)
---@param armWithEmptyHand boolean  mains vides : au bras (config.shield.armWithEmptyHand)
---@return string 'arm' | 'back'
function shield.position(handItem, classes, armWith, armWithEmptyHand)
    if handItem == nil then return armWithEmptyHand == true and ARM or BACK end
    local class = type(handItem) == 'string' and type(classes) == 'table' and classes[handItem] or nil
    if type(class) ~= 'table' or type(armWith) ~= 'table' then return BACK end
    for _, category in ipairs(armWith) do
        if class.category == category then return ARM end
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

