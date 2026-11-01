--[[
    vava_combat/shared/dummies.lua
    Rôle : index des mannequins d'entraînement (T-156) : numéro `n` = place dans la liste, centre visé. Servi aux deux ;
           la liste est contrôlée au seul serveur (shared/weapons.lua › checkDummies).
    Dépendances : shared/constants.lua
]]

local ipairs = ipairs

local dummyRules = {}
VavaCombat.dummyRules = dummyRules

-- mannequins par numéro et par identifiant ; modèle, hauteur du centre et libellé par défaut
function dummyRules.index(list, model, centerHeight, label)
    local byN, byId = {}, {}
    for n, d in ipairs(list) do
        local entry = {
            n = n, id = d.id, x = d.x, y = d.y, z = d.z, heading = d.heading, model = d.model or model,
            bucket = d.bucket or 0, label = d.label or label,
            center = { x = d.x, y = d.y, z = d.z + centerHeight },
        }
        byN[n] = entry
        byId[d.id] = entry
    end
    return byN, byId
end
