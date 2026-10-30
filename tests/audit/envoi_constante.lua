--[[
    tests/audit/envoi_constante.lua
    Rôle : cas écrits pour `./scripts/audit-reseau.sh --essai` (jamais chargé, ni linté, ni audité en mode normal) :
           envoi à tous écrit par une constante valant -1. Chaque ligne qui compte finit par ce que l'audit doit en
           dire : « attendu: BLOQUANT », « attendu: AVERTISSEMENT » ou « attendu: rien ».
]]

local EVERYONE = -1  -- attendu: rien
local NO_PLAYER = -1 -- une constante qui n'est jamais une cible
local Cible = {}
Cible.TOUS = -1

local function annonce(x, src)
    TriggerClientEvent('t:e', EVERYONE, x)  -- attendu: BLOQUANT
    TriggerLatentClientEvent('t:e', EVERYONE, 8192, x)  -- attendu: BLOQUANT
    TriggerClientEvent('t:e', Cible.TOUS, x)  -- attendu: BLOQUANT
    if src ~= NO_PLAYER then TriggerClientEvent('t:e', src) end  -- attendu: rien
    TriggerClientEvent('t:e', -1, x)  -- attendu: BLOQUANT
    -- constante posée dans un autre fichier : limite connue du contrôle (core.net refuse -1 à l'exécution)
    TriggerClientEvent('t:e', Autre.EVERYONE_DISTANT, x)  -- attendu: rien
    TriggerClientEvent('t:e', src, EVERYONE)  -- attendu: rien
end

return annonce
