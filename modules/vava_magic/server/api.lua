--[[
    vava_magic/server/api.lua
    Rôle : exports serveur pour les autres modules (métiers, quêtes, prisons…) : lecture de la fiche magie d'un
           joueur en jeu. Toute modification passe par les commandes du Conseil ou par les sorts.
    Dépendances : server/core.lua, server/sheets.lua, server/mana.lua
]]

local type, mathType = type, math.type

local sheets = VavaMagic.sheets
local mana = VavaMagic.mana

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
