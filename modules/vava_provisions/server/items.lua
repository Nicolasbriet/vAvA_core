--[[
    vava_provisions/server/items.lua
    Rôle : objets du module (eau, outre) déclarés à l'inventaire S'ILS N'Y SONT PAS DÉJÀ (un objet déclaré par une autre
           ressource n'est jamais remplacé : avertissement en console, une fois par démarrage et par objet), avec
           l'image du module ; redéclarés au retour de l'inventaire (qui a perdu les déclarations de tous les modules
           et rend alors les piles gardées à part). Recette de l'outre ajoutée à l'artisanat (registres de
           vava_crafting et de vava_skills) dès qu'il est prêt, avant ou après ce module ; sans lui, avertissement et le
           module tourne quand même (aucune outre neuve ne se fabrique).
    Dépendances : shared/constants.lua, config.lua, server/core.lua, bridge/server.lua
]]

local pairs, tostring = pairs, tostring

local bridge = VavaProvisions.bridge
local cfg = VavaProvisions.config

local items = {}
VavaProvisions.items = items

-- objets que ce module a lui-même déclarés au registre actuel de l'inventaire
local ours = {}
-- objets déjà signalés comme déclarés par une autre ressource (une ligne par démarrage du module)
local warned = {}

--- Image d'un objet du module.
---@param name string
---@return string
local function imageOf(name)
    return 'nui://' .. VavaProvisions.resource .. '/web/items/' .. name .. '.svg'
end

--- Déclare les objets de la config que l'inventaire ne connaît pas encore. Sans inventaire prêt : rien (rappelé à son
--- annonce).
function items.declare()
    if not bridge.ItemsReady() then return end
    for name, def in pairs(cfg.items) do
        if bridge.HasItem(name) then
            if not ours[name] and not warned[name] then
                warned[name] = true
                VavaProvisions.log.warn("objet '%s' déjà déclaré par une autre ressource : sa définition est gardée (celle de vava_provisions ne s'applique pas)", name)
            end
        else
            local definition = {}
            for key, value in pairs(def) do definition[key] = value end
            definition.image = imageOf(name)
            local ok, err = bridge.AddItem(name, definition)
            if ok then
                ours[name] = true
            else
                VavaProvisions.log.warn("objet '%s' non déclaré : %s", name, tostring(err))
            end
        end
    end
end

--- Retour de vava_inventory : son registre est neuf, les objets sont redéclarés (les piles gardées à part reviennent).
function items.onInventoryReady()
    ours = {}
    items.declare()
end

--- Ajoute la recette de l'outre à l'artisanat. Absent (ou sans tannerie) : avertissement, rien d'autre.
---@return boolean declared
function items.declareRecipe()
    local recipe = cfg.recipe
    if not recipe then return false end
    local ok, err = bridge.DeclareRecipe(recipe)
    if not ok then
        VavaProvisions.log.warn("recette de l'outre non déclarée : %s", tostring(err))
        return false
    end
    return true
end

--- Vrai si l'objet a été déclaré par ce module (registre actuel de l'inventaire).
---@param name string
---@return boolean
function items.isOurs(name)
    return ours[name] == true
end
