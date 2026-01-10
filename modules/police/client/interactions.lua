--[[
    vAvA_police - Client Interactions
    Interactions diverses et points interactifs
]]

local vCore = exports['vAvA_core']:GetCoreObject()

-- ═══════════════════════════════════════════════════════════════════════════
-- POINTS INTERACTIFS - COMMISSARIATS
-- ═══════════════════════════════════════════════════════════════════════════

CreateThread(function()
    while true do
        Wait(500)
        
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        local playerData = vCore.GetPlayerData()
        
        -- Vérifier si police
        local isPolice = false
        if playerData.job and playerData.job.name then
            for _, policeJob in ipairs(PoliceConfig.General.PoliceJobs) do
                if playerData.job.name == policeJob then
                    isPolice = true
                    break
                end
            end
        end
        
        if not isPolice then
            Wait(2000)
            goto continue
        end
        
        -- Vérifier proximité avec points d'intérêt
        for _, station in ipairs(PoliceConfig.Stations) do
            -- Vestiaire
            if #(coords - station.cloakroom) < 2.0 then
                DrawText3D(station.cloakroom.x, station.cloakroom.y, station.cloakroom.z, '[~g~E~s~] Vestiaire')
                if IsControlJustReleased(0, 38) then
                    OpenCloakroom()
                end
            end
            
            -- Armurerie
            if #(coords - station.armory) < 2.0 then
                DrawText3D(station.armory.x, station.armory.y, station.armory.z, '[~g~E~s~] Armurerie')
                if IsControlJustReleased(0, 38) then
                    OpenArmory()
                end
            end
            
            -- Garage
            if #(coords - station.garage.coords) < 5.0 then
                DrawText3D(station.garage.coords.x, station.garage.coords.y, station.garage.coords.z, '[~g~E~s~] Garage')
                if IsControlJustReleased(0, 38) then
                    OpenGarage()
                end
            end
        end
        
        ::continue::
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- AFFICHAGE 3D
-- ═══════════════════════════════════════════════════════════════════════════

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    local px, py, pz = table.unpack(GetGameplayCamCoords())
    local dist = #(vector3(px, py, pz) - vector3(x, y, z))
    
    local scale = (1 / dist) * 2
    local fov = (1 / GetGameplayCamFov()) * 100
    scale = scale * fov
    
    if onScreen then
        SetTextScale(0.0 * scale, 0.55 * scale)
        SetTextFont(4)
        SetTextProportional(1)
        SetTextColour(255, 255, 255, 215)
        SetTextDropshadow(0, 0, 0, 0, 255)
        SetTextEdge(2, 0, 0, 0, 150)
        SetTextDropShadow()
        SetTextOutline()
        SetTextEntry("STRING")
        SetTextCentre(1)
        AddTextComponentString(text)
        DrawText(_x, _y)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- RÉSULTATS FOUILLE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vAvA_police:client:ShowSearchResults', function(foundItems, illegalItems)
    if #foundItems == 0 then
        vCore.ShowNotification('Aucun item trouvé', 'info')
        return
    end
    
    -- Construire liste items
    local itemsList = {}
    for _, item in ipairs(foundItems) do
        table.insert(itemsList, string.format('%s (x%d)', item.label, item.amount))
    end
    
    vCore.ShowNotification('Items trouvés:\n' .. table.concat(itemsList, '\n'), 'info', 8000)
    
    if #illegalItems > 0 then
        local illegalList = {}
        for _, item in ipairs(illegalItems) do
            table.insert(illegalList, string.format('%s (x%d)', item.label, item.amount))
        end
        vCore.ShowNotification('~r~Items illégaux confisqués:\n~s~' .. table.concat(illegalList, '\n'), 'error', 8000)
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

function GetNearbyPlayers(radius)
    local players = {}
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    
    for _, player in ipairs(GetActivePlayers()) do
        local targetPed = GetPlayerPed(player)
        if targetPed ~= ped then
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(coords - targetCoords)
            
            if distance <= radius then
                table.insert(players, {
                    playerId = player,
                    serverId = GetPlayerServerId(player),
                    ped = targetPed,
                    coords = targetCoords,
                    distance = distance
                })
            end
        end
    end
    
    return players
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('GetNearbyPlayers', GetNearbyPlayers)
