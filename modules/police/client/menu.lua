--[[
    vAvA_police - Client Menu
    Menu F6 d'interaction avec les citoyens
]]

local vCore = exports['vAvA_core']:GetCoreObject()

-- ═══════════════════════════════════════════════════════════════════════════
-- MENU PRINCIPAL F6
-- ═══════════════════════════════════════════════════════════════════════════

function OpenPoliceMenu()
    local elements = {
        {label = 'Interaction Citoyen', value = 'citizen_interaction'},
        {label = 'Vestiaire', value = 'cloakroom'},
        {label = 'Armurerie', value = 'armory'},
        {label = 'Garage', value = 'garage'},
        {label = 'Tablette Police', value = 'tablet'},
        {label = 'Radar', value = 'radar'},
        {label = 'Demander Renfort', value = 'backup'}
    }
    
    vCore.UI.Menu.Open('default', GetCurrentResourceName(), 'police_menu', {
        title = 'Menu Police',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        if data.current.value == 'citizen_interaction' then
            OpenCitizenInteraction()
        elseif data.current.value == 'cloakroom' then
            OpenCloakroom()
        elseif data.current.value == 'armory' then
            OpenArmory()
        elseif data.current.value == 'garage' then
            OpenGarage()
        elseif data.current.value == 'tablet' then
            exports['vAvA_police']:OpenTablet()
        elseif data.current.value == 'radar' then
            ToggleRadar()
        elseif data.current.value == 'backup' then
            RequestBackup()
        end
    end, function(data, menu)
        menu.close()
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- INTERACTION CITOYEN
-- ═══════════════════════════════════════════════════════════════════════════

function OpenCitizenInteraction()
    local closestPlayer, closestDistance = vCore.Game.GetClosestPlayer()
    
    if closestPlayer == -1 or closestDistance > 3.0 then
        vCore.ShowNotification('Aucun joueur à proximité', 'error')
        return
    end
    
    local targetId = GetPlayerServerId(closestPlayer)
    
    local elements = {
        {label = '👮 Menotter / Démenotter', value = 'handcuff'},
        {label = '🔍 Fouiller', value = 'search'},
        {label = '🚶 Escorter', value = 'escort'},
        {label = '🚗 Mettre dans véhicule', value = 'put_in_vehicle'},
        {label = '🚪 Sortir du véhicule', value = 'remove_from_vehicle'},
        {label = '💰 Donner une amende', value = 'fine'},
        {label = '⛓️ Envoyer en prison', value = 'jail'},
        {label = '📋 Contrôle d\'identité', value = 'identity'},
        {label = '📄 Casier judiciaire', value = 'record'}
    }
    
    vCore.UI.Menu.Open('default', GetCurrentResourceName(), 'citizen_interaction', {
        title = 'Interaction Citoyen',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        if data.current.value == 'handcuff' then
            TriggerServerEvent('vAvA_police:server:Handcuff', targetId)
            menu.close()
        elseif data.current.value == 'search' then
            TriggerServerEvent('vAvA_police:server:SearchPlayer', targetId)
            menu.close()
        elseif data.current.value == 'escort' then
            TriggerServerEvent('vAvA_police:server:Escort', targetId)
            menu.close()
        elseif data.current.value == 'put_in_vehicle' then
            TriggerServerEvent('vAvA_police:server:PutInVehicle', targetId)
            menu.close()
        elseif data.current.value == 'remove_from_vehicle' then
            TriggerServerEvent('vAvA_police:server:RemoveFromVehicle', targetId)
            menu.close()
        elseif data.current.value == 'fine' then
            OpenFineMenu(targetId)
        elseif data.current.value == 'jail' then
            OpenJailMenu(targetId)
        elseif data.current.value == 'identity' then
            CheckIdentity(targetId)
        elseif data.current.value == 'record' then
            CheckCriminalRecord(targetId)
        end
    end, function(data, menu)
        menu.close()
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MENU AMENDES
-- ═══════════════════════════════════════════════════════════════════════════

function OpenFineMenu(targetId)
    local elements = {
        {label = '🚗 Infractions routières', value = 'traffic'},
        {label = '📋 Infractions administratives', value = 'admin'},
        {label = '⚠️ Infractions criminelles', value = 'criminal'},
        {label = '✍️ Amende personnalisée', value = 'custom'}
    }
    
    vCore.UI.Menu.Open('default', GetCurrentResourceName(), 'fine_category', {
        title = 'Type d\'amende',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        menu.close()
        OpenFineTypeMenu(targetId, data.current.value)
    end, function(data, menu)
        menu.close()
    end)
end

function OpenFineTypeMenu(targetId, category)
    local elements = {}
    
    if category == 'custom' then
        vCore.UI.Menu.Open('dialog', GetCurrentResourceName(), 'fine_amount', {
            title = 'Montant de l\'amende'
        }, function(data, menu)
            local amount = tonumber(data.value)
            if amount and amount > 0 then
                menu.close()
                vCore.UI.Menu.Open('dialog', GetCurrentResourceName(), 'fine_reason', {
                    title = 'Motif de l\'amende'
                }, function(data2, menu2)
                    menu2.close()
                    TriggerServerEvent('vAvA_police:server:GiveFine', targetId, amount, data2.value)
                end, function(data2, menu2)
                    menu2.close()
                end)
            else
                vCore.ShowNotification('Montant invalide', 'error')
            end
        end, function(data, menu)
            menu.close()
        end)
        return
    end
    
    for _, fine in ipairs(PoliceConfig.Fines) do
        if fine.category == category then
            table.insert(elements, {
                label = fine.label .. ' - $' .. fine.amount,
                value = fine
            })
        end
    end
    
    vCore.UI.Menu.Open('default', GetCurrentResourceName(), 'fine_list', {
        title = 'Sélectionner une amende',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        menu.close()
        TriggerServerEvent('vAvA_police:server:GiveFine', targetId, data.current.value.amount, data.current.value.label)
    end, function(data, menu)
        menu.close()
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MENU PRISON
-- ═══════════════════════════════════════════════════════════════════════════

function OpenJailMenu(targetId)
    vCore.UI.Menu.Open('dialog', GetCurrentResourceName(), 'jail_time', {
        title = 'Temps de prison (minutes)'
    }, function(data, menu)
        local time = tonumber(data.value)
        if time and time > 0 and time <= PoliceConfig.Prison.MaxTime then
            menu.close()
            vCore.UI.Menu.Open('dialog', GetCurrentResourceName(), 'jail_reason', {
                title = 'Motif de l\'emprisonnement'
            }, function(data2, menu2)
                menu2.close()
                TriggerServerEvent('vAvA_police:server:SendToJail', targetId, time, data2.value)
            end, function(data2, menu2)
                menu2.close()
            end)
        else
            vCore.ShowNotification('Temps invalide (max ' .. PoliceConfig.Prison.MaxTime .. ' min)', 'error')
        end
    end, function(data, menu)
        menu.close()
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VESTIAIRE
-- ═══════════════════════════════════════════════════════════════════════════

function OpenCloakroom()
    local playerData = vCore.GetPlayerData()
    local grade = playerData.job.grade.level
    
    local elements = {
        {label = '👔 Tenue civile', value = 'civilian'},
        {label = '👮 Tenue de police', value = 'police'}
    }
    
    vCore.UI.Menu.Open('default', GetCurrentResourceName(), 'cloakroom', {
        title = 'Vestiaire',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        if data.current.value == 'civilian' then
            TriggerServerEvent('vAvA_core:server:LoadOutfit')
            vCore.ShowNotification('Tenue civile équipée', 'success')
        elseif data.current.value == 'police' then
            local ped = PlayerPedId()
            local model = GetEntityModel(ped)
            local outfit = model == GetHashKey("mp_m_freemode_01") and PoliceConfig.Outfits.male[grade] or PoliceConfig.Outfits.female[grade]
            
            if outfit then
                TriggerEvent('skinchanger:loadClothes', GetPlayerPed(-1), outfit)
                vCore.ShowNotification('Tenue de police équipée', 'success')
            end
        end
        menu.close()
    end, function(data, menu)
        menu.close()
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ARMURERIE
-- ═══════════════════════════════════════════════════════════════════════════

function OpenArmory()
    local playerData = vCore.GetPlayerData()
    local grade = playerData.job.grade.level
    
    -- Trouver le commissariat le plus proche
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closestStation = nil
    local closestDist = 999999
    
    for _, station in ipairs(PoliceConfig.Stations) do
        local dist = #(coords - station.armory)
        if dist < closestDist and dist < 5.0 then
            closestDist = dist
            closestStation = station
        end
    end
    
    if not closestStation then
        vCore.ShowNotification('Vous devez être à l\'armurerie', 'error')
        return
    end
    
    local elements = {}
    for _, weapon in ipairs(closestStation.armoryItems) do
        if grade >= weapon.grade then
            table.insert(elements, {
                label = weapon.label,
                value = weapon.item
            })
        end
    end
    
    -- Ajouter munitions
    table.insert(elements, {label = '📦 Munitions (x50)', value = 'ammo'})
    
    vCore.UI.Menu.Open('default', GetCurrentResourceName(), 'armory', {
        title = 'Armurerie',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        if data.current.value == 'ammo' then
            TriggerServerEvent('vAvA_police:server:TakeAmmo', 50)
        else
            TriggerServerEvent('vAvA_police:server:TakeWeapon', data.current.value)
        end
        menu.close()
    end, function(data, menu)
        menu.close()
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- GARAGE
-- ═══════════════════════════════════════════════════════════════════════════

function OpenGarage()
    local playerData = vCore.GetPlayerData()
    local grade = playerData.job.grade.level
    
    -- Trouver le garage le plus proche
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local closestStation = nil
    local closestDist = 999999
    
    for _, station in ipairs(PoliceConfig.Stations) do
        local dist = #(coords - station.garage.coords)
        if dist < closestDist and dist < 10.0 then
            closestDist = dist
            closestStation = station
        end
    end
    
    if not closestStation then
        vCore.ShowNotification('Vous devez être au garage', 'error')
        return
    end
    
    local elements = {}
    for _, vehicle in ipairs(closestStation.garage.vehicles) do
        if grade >= vehicle.grade then
            table.insert(elements, {
                label = vehicle.label,
                value = vehicle.model
            })
        end
    end
    
    vCore.UI.Menu.Open('default', GetCurrentResourceName(), 'garage', {
        title = 'Garage Police',
        align = 'top-left',
        elements = elements
    }, function(data, menu)
        menu.close()
        SpawnVehicle(data.current.value, closestStation.garage.coords, closestStation.garage.heading)
    end, function(data, menu)
        menu.close()
    end)
end

function SpawnVehicle(model, coords, heading)
    local hash = GetHashKey(model)
    RequestModel(hash)
    while not HasModelLoaded(hash) do
        Wait(10)
    end
    
    local vehicle = CreateVehicle(hash, coords.x, coords.y, coords.z, heading, true, false)
    SetVehicleNumberPlateText(vehicle, "LSPD" .. math.random(1000, 9999))
    SetEntityAsMissionEntity(vehicle, true, true)
    TaskWarpPedIntoVehicle(PlayerPedId(), vehicle, -1)
    
    TriggerEvent('vehiclekeys:client:SetOwner', GetVehicleNumberPlateText(vehicle))
    vCore.ShowNotification('Véhicule sorti', 'success')
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DEMANDER RENFORT
-- ═══════════════════════════════════════════════════════════════════════════

function RequestBackup()
    local coords = GetEntityCoords(PlayerPedId())
    TriggerServerEvent('vAvA_police:server:RequestBackup', coords)
    vCore.ShowNotification('Demande de renfort envoyée', 'success')
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CONTRÔLE IDENTITÉ / CASIER
-- ═══════════════════════════════════════════════════════════════════════════

function CheckIdentity(targetId)
    vCore.TriggerServerCallback('vAvA_police:server:GetPlayerIdentity', function(identity)
        if identity then
            local msg = string.format(
                "Nom: %s %s\nDate de naissance: %s\nGenre: %s\nTéléphone: %s\nJob: %s",
                identity.firstName,
                identity.lastName,
                identity.dateofbirth,
                identity.sex,
                identity.phone or 'N/A',
                identity.job
            )
            vCore.ShowNotification(msg, 'info', 10000)
        end
    end, targetId)
end

function CheckCriminalRecord(targetId)
    TriggerServerEvent('vAvA_police:server:CheckCriminalRecord', targetId)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- KEYBINDS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterKeyMapping('policemenu', 'Menu Police', 'keyboard', 'F6')
RegisterCommand('policemenu', function()
    local playerData = vCore.GetPlayerData()
    if playerData.job and playerData.job.name then
        for _, policeJob in ipairs(PoliceConfig.General.PoliceJobs) do
            if playerData.job.name == policeJob then
                OpenPoliceMenu()
                return
            end
        end
    end
end, false)
