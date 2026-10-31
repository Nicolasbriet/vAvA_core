--[[
    vava_magic/server/api.lua
    Rôle : exports serveur pour les autres modules (métiers, quêtes, prisons, combat…) : lecture de la fiche magie d'un
           joueur en jeu et des contrôles durs qui le tiennent. Toute modification passe par les commandes du Conseil
           ou par les sorts.
    Dépendances : server/core.lua, server/sheets.lua, server/mana.lua, server/states.lua
]]

local type, mathType = type, math.type

local sheets = VavaMagic.sheets
local mana = VavaMagic.mana
local states = VavaMagic.states

--- Le personnage actif du joueur est-il mage ?
exports('isMage', function(source)
    local sheet = mathType(source) == 'integer' and sheets.get(source) or nil
    return sheet ~= nil and sheet.isMage == true
end)

--- Niveau d'un sort connu (1 à 5), ou nil.
exports('spellLevel', function(source, spell)
    if mathType(source) ~= 'integer' or type(spell) ~= 'string' then return nil end
    return sheets.level(source, spell)
end)

--- Mana actuelle et maximum (0 pour un non-mage).
exports('mana', function(source)
    if mathType(source) ~= 'integer' then return 0, mana.MAX end
    return mana.current(source), mana.MAX
end)

--- Contrôle dur d'un sort qui tient le joueur (gelé, renversé, chancelant) : son nom (`frozen`, `knockdown`, `stagger`),
--- vrai pour l'appelant, ou nil. Lu par vava_combat pour refuser une frappe (`controlled`) ; mémoire seule, sans attente.
exports('hardControl', function(source)
    if mathType(source) ~= 'integer' then return nil end
    return states.hardControl(source)
end)
