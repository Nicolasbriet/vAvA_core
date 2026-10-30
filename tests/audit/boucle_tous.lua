--[[
    tests/audit/boucle_tous.lua
    Rôle : cas écrits pour `./scripts/audit-reseau.sh --essai` (jamais chargé, ni linté, ni audité en mode normal) :
           boucles sur tous les joueurs qui envoient. Chaque ligne qui compte finit par ce que l'audit doit en dire.
]]

local function cas(sessions, core, payload, near)
    for src in pairs(sessions.all()) do TriggerClientEvent('t:e', src, payload) end  -- attendu: BLOQUANT

    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        local copy = payload
        TriggerClientEvent('t:e', target, copy)  -- attendu: BLOQUANT
    end

    for _, id in ipairs(GetPlayers()) do
        local target = tonumber(id)
        if near(target) then
            TriggerClientEvent('t:e', target, payload)  -- attendu: AVERTISSEMENT
        end
    end

    local list = {}
    for _, id in ipairs(GetPlayers()) do
        list[#list + 1] = tonumber(id)  -- attendu: rien
    end
    TriggerClientEvent('t:e', list[1], payload)  -- attendu: rien

    for _, id in ipairs(GetPlayers()) do
        core.net.send(tonumber(id), 't:e', payload)  -- attendu: BLOQUANT
    end

    for _, id in ipairs(GetPlayers()) do
        core.net.sendNear(GetEntityCoords(GetPlayerPed(id)), 10.0, 't:e', payload)  -- attendu: rien
    end

    core.characters.forEachActive(function(character)
        TriggerLatentClientEvent('t:e', character.source, 8192, payload)  -- attendu: BLOQUANT
    end)

    -- couvert par tests/audit/exceptions.txt
    for src in pairs(sessions.all()) do TriggerClientEvent('t:excuse', src) end  -- attendu: rien
end

return cas
