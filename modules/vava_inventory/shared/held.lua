--[[
    vava_inventory/shared/held.lua
    Rôle : règles pures de l'objet tenu en main (1.7.0). La valeur publiée sur le statebag du ped du porteur est
           réduite à { id, item } : le placement de l'accessoire (modèle, os, décalage, rotation) se lit dans la liste
           des objets tenables que le serveur publie dans GlobalState. Ces règles disent quelle valeur publier, si deux
           valeurs sont la même (garde du serveur), quel accessoire montrer pour une valeur reçue (client), et quand
           remettre une valeur réécrite par un client (délai des remises).
    Dépendances : shared/constants.lua
]]

local type, next, tonumber = type, next, tonumber
local min, mathType, tointeger = math.min, math.type, math.tointeger
local match = string.match

local MAX_ID = VavaInventory.MAX_ID
-- longueur maximale d'un nom d'objet (schéma du registre des objets)
local MAX_ITEM = 64
-- au-delà, le décalage du délai déborderait : le plafond est atteint bien avant
local MAX_SHIFT = 20

local held = {}
VavaInventory.held = held

--- Vrai si `id` est un identifiant de pile (entier de 1 à MAX_ID ; un flottant entier venu du réseau est admis).
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
    return type(item) == 'string' and #item >= 1 and #item <= MAX_ITEM
end

--- Valeur publiée pour une pile tenue : { id, item }.
---@param id integer
---@param item string
---@return table
function held.value(id, item)
    return { id = id, item = item }
end

--- Vrai si `value` est une valeur publiable : nil (mains vides) ou une table à exactement deux clés, `id` et `item`,
--- bien formées. Une table venue d'un client peut avoir n'importe quelle forme : au plus trois clés sont parcourues.
---@param value any
---@return boolean
function held.valid(value)
    if value == nil then return true end
    if type(value) ~= 'table' or not validId(value.id) or not validItem(value.item) then return false end
    local count, key = 0, nil
    repeat
        key = next(value, key)
        if key ~= nil then count = count + 1 end
    until key == nil or count > 2
    return count == 2
end

--- Vrai si deux valeurs sont la même main : toutes deux nil, ou toutes deux valides avec le même `id` et le même
--- `item`. Une valeur mal formée n'est égale à rien (pas même à elle-même) : la garde la remplace toujours.
---@param a any
---@param b any
---@return boolean
function held.same(a, b)
    if a == nil or b == nil then return a == nil and b == nil end
    if not held.valid(a) or not held.valid(b) then return false end
    return a.id == b.id and a.item == b.item
end

--- Accessoire à montrer pour une valeur reçue, ou nil. Seuls `id` et `item` sont lus dans la valeur ; modèle, os et
--- placement viennent de la déclaration publiée par le serveur (`declared[item]`), jamais de la valeur. Rien si la
--- valeur est absente ou mal formée, ou si l'objet n'est pas (ou plus) déclaré tenable.
---@param value any
---@param declared table|nil  objet → { model, bone, offset, rotation }
---@return table|nil prop  { id, model, bone, offset, rotation }
function held.prop(value, declared)
    if value == nil or not held.valid(value) or type(declared) ~= 'table' then return nil end
    local decl = declared[value.item]
    if type(decl) ~= 'table' or not validItem(decl.model) or type(decl.bone) ~= 'number'
        or type(decl.offset) ~= 'table' or type(decl.rotation) ~= 'table' then
        return nil
    end
    return { id = tointeger(value.id), model = decl.model, bone = decl.bone, offset = decl.offset, rotation = decl.rotation }
end

--- Numéro réseau d'une entité d'après le nom de son statebag (`entity:<n>`), ou nil pour tout autre statebag.
---@param bagName any
---@return integer|nil
function held.netIdOf(bagName)
    if type(bagName) ~= 'string' then return nil end
    local digits = match(bagName, '^entity:(%d+)$')
    if not digits or #digits > 9 then return nil end
    local netId = tointeger(tonumber(digits))
    if not netId or netId < 1 then return nil end
    return netId
end

--- Délai avant de remettre la valeur du serveur sur un ped dont la main a été réécrite : `guardDelayMs` tant que la
--- main n'a pas été remise `guardMaxCorrections` fois depuis la dernière publication, puis doublé à chaque remise
--- jusqu'à `guardMaxDelayMs`. Même règle que la garde des champs publics du core (0.9.0).
---@param streak integer  remises déjà faites depuis la dernière publication
---@param cfg { guardDelayMs: integer, guardMaxCorrections: integer, guardMaxDelayMs: integer }
---@return integer
function held.guardDelay(streak, cfg)
    local over = streak - cfg.guardMaxCorrections
    if over < 0 then return cfg.guardDelayMs end
    if over >= MAX_SHIFT then return cfg.guardMaxDelayMs end
    return min(cfg.guardDelayMs << (over + 1), cfg.guardMaxDelayMs)
end
