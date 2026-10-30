--[[
    tests/audit/evenement_zone.lua
    Rôle : cas écrits pour `./scripts/audit-reseau.sh --essai` (jamais chargé, ni linté, ni audité en mode normal) :
           un module qui nomme un évènement des abonnements de zone du core (T-014). Chaque ligne qui compte finit par
           ce que l'audit doit en dire : « attendu: BLOQUANT », « attendu: AVERTISSEMENT » ou « attendu: rien ».
]]

local function triche(src, handle)
    TriggerEvent('vAvA:zone:leave', { handle })  -- attendu: BLOQUANT
    RegisterNetEvent('vAvA:zone:state', function() end)  -- attendu: BLOQUANT
    TriggerClientEvent("vAvA:zone:diff", src, handle, 2, {})  -- attendu: BLOQUANT
    -- vAvA:zone:state est réservé au core  -- attendu: rien
    core.zones.set('place', { a = 1 })  -- attendu: rien
    TriggerClientEvent('vava_test:zone:state', src)  -- attendu: rien
end
