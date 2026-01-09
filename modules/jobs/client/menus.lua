--[[
    vAvA Core - Module Jobs
    Client - Menus (Wardrobe, Vehicles, Boss)
]]

---Ouvre le vestiaire
---@param interaction table
function OpenWardrobeMenu(interaction)
    TriggerServerEvent('vCore:jobs:getOutfits')
end

RegisterNetEvent('vCore:jobs:receiveOutfits', function(outfits)
    if not outfits or #outfits == 0 then
        Notify('Aucune tenue disponible', 'info')
        return
    end
    
    local menuOptions = {}
    
    -- Option pour retirer la tenue
    table.insert(menuOptions, {
        title = 'Tenue Civile',
        description = 'Remettre vos vêtements',
        icon = 'fas fa-user',
        onSelect = function()
            -- Restaurer la tenue sauvegardée
            TriggerEvent('vCore:restoreSkin')
        end
    })
    
    -- Options des tenues de job
    for _, outfit in ipairs(outfits) do
        table.insert(menuOptions, {
            title = outfit.label,
            description = 'Grade: ' .. outfit.grade,
            icon = 'fas fa-tshirt',
            onSelect = function()
                ApplyOutfit(outfit.outfit)
            end
        })
    end
    
    OpenMenu('wardrobe_menu', 'Vestiaire', menuOptions)
end)

---Applique une tenue
---@param outfit table
function ApplyOutfit(outfit)
    local ped = PlayerPedId()
    
    -- Appliquer chaque composant
    for component, data in pairs(outfit) do
        if type(data) == 'table' and data.drawable ~= nil then
            SetPedComponentVariation(ped, tonumber(component), data.drawable, data.texture or 0, data.palette or 0)
        end
    end
    
    Notify('Tenue équipée', 'success')
end

---Ouvre le menu des véhicules
---@param interaction table
function OpenVehicleMenu(interaction)
    TriggerServerEvent('vCore:jobs:getVehicles')
end

RegisterNetEvent('vCore:jobs:receiveVehicles', function(vehicles)
    if not vehicles or #vehicles == 0 then
        Notify('Aucun véhicule disponible', 'info')
        return
    end
    
    -- Grouper par catégorie
    local categories = {}
    for _, vehicle in ipairs(vehicles) do
        local cat = vehicle.category or 'service'
        if not categories[cat] then
            categories[cat] = {}
        end
        table.insert(categories[cat], vehicle)
    end
    
    local menuOptions = {}
    
    -- Option pour ranger le véhicule
    table.insert(menuOptions, {
        title = 'Ranger le véhicule',
        description = 'Ranger le véhicule actuel',
        icon = 'fas fa-parking',
        onSelect = function()
            StoreJobVehicle()
        end
    })
    
    -- Options par catégorie
    for catName, catVehicles in pairs(categories) do
        table.insert(menuOptions, {
            title = catName:upper(),
            description = #catVehicles .. ' véhicule(s)',
            icon = 'fas fa-car',
            menu = 'vehicle_cat_' .. catName
        })
        
        -- Sous-menu pour la catégorie
        local catOptions = {}
        for _, vehicle in ipairs(catVehicles) do
            table.insert(catOptions, {
                title = vehicle.label,
                description = 'Grade min: ' .. vehicle.min_grade,
                icon = 'fas fa-car-side',
                onSelect = function()
                    SpawnJobVehicle(vehicle)
                end
            })
        end
        
        -- Enregistrer le sous-menu
        RegisterSubMenu('vehicle_cat_' .. catName, catName, catOptions)
    end
    
    OpenMenu('vehicle_menu', 'Véhicules de service', menuOptions)
end)

---Fait spawner un véhicule de job
---@param vehicleData table
function SpawnJobVehicle(vehicleData)
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    -- Trouver un point de spawn
    local spawnCoords = GetVehicleSpawnPoint(coords, 10.0)
    if not spawnCoords then
        Notify('Aucun point de spawn trouvé', 'error')
        return
    end
    
    -- Charger le modèle
    local model = GetHashKey(vehicleData.model)
    RequestModel(model)
    while not HasModelLoaded(model) do
        Wait(10)
    end
    
    -- Créer le véhicule
    local vehicle = CreateVehicle(model, spawnCoords.x, spawnCoords.y, spawnCoords.z, spawnCoords.heading, true, false)
    SetModelAsNoLongerNeeded(model)
    
    -- Appliquer les customisations
    if vehicleData.livery then
        SetVehicleLivery(vehicle, vehicleData.livery)
    end
    
    if vehicleData.extras then
        local extras = json.decode(vehicleData.extras)
        for extra, enabled in pairs(extras) do
            SetVehicleExtra(vehicle, tonumber(extra), enabled and 0 or 1)
        end
    end
    
    -- Mettre le joueur dedans
    TaskWarpPedIntoVehicle(ped, vehicle, -1)
    
    Notify(JobsConfig.Notifications.vehicle_spawned, 'success')
end

---Range le véhicule actuel
function StoreJobVehicle()
    local ped = PlayerPedId()
    local vehicle = GetVehiclePedIsIn(ped, false)
    
    if not vehicle or vehicle == 0 then
        Notify(JobsConfig.Notifications.no_vehicle, 'error')
        return
    end
    
    DeleteVehicle(vehicle)
    Notify(JobsConfig.Notifications.vehicle_stored, 'success')
end

---Trouve un point de spawn pour un véhicule
---@param coords vector3
---@param radius number
---@return table|nil
function GetVehicleSpawnPoint(coords, radius)
    local found, outPosition, outHeading = GetNthClosestVehicleNodeWithHeading(coords.x, coords.y, coords.z, 1, 1, 0x40400000, 0)
    
    if found then
        return {
            x = outPosition.x,
            y = outPosition.y,
            z = outPosition.z,
            heading = outHeading
        }
    end
    
    return nil
end

---Ouvre le menu patron
---@param interaction table
function OpenBossMenu(interaction)
    -- Vérifier les permissions
    if not CurrentJob or CurrentJob.grade < (interaction.min_grade or 3) then
        Notify(JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    local menuOptions = {
        {
            title = 'Gestion des employés',
            description = 'Recruter, promouvoir, renvoyer',
            icon = 'fas fa-users',
            menu = 'boss_employees'
        },
        {
            title = 'Compte société',
            description = 'Gérer les finances',
            icon = 'fas fa-wallet',
            menu = 'boss_society'
        },
        {
            title = 'Salaires',
            description = 'Modifier les salaires',
            icon = 'fas fa-money-bill',
            menu = 'boss_salaries'
        }
    }
    
    -- Sous-menus
    RegisterSubMenu('boss_employees', 'Gestion des employés', {
        {
            title = 'Recruter',
            description = 'Recruter un joueur proche',
            icon = 'fas fa-user-plus',
            onSelect = function()
                OpenHireMenu()
            end
        },
        {
            title = 'Promouvoir',
            description = 'Promouvoir un employé',
            icon = 'fas fa-level-up-alt',
            onSelect = function()
                OpenPromoteMenu()
            end
        },
        {
            title = 'Rétrograder',
            description = 'Rétrograder un employé',
            icon = 'fas fa-level-down-alt',
            onSelect = function()
                OpenDemoteMenu()
            end
        },
        {
            title = 'Licencier',
            description = 'Licencier un employé',
            icon = 'fas fa-user-minus',
            onSelect = function()
                OpenFireMenu()
            end
        }
    })
    
    RegisterSubMenu('boss_society', 'Compte société', {
        {
            title = 'Consulter le solde',
            description = 'Voir le solde du compte',
            icon = 'fas fa-eye',
            onSelect = function()
                TriggerServerEvent('vCore:jobs:requestSocietyMoney')
            end
        },
        {
            title = 'Retirer de l\'argent',
            description = 'Retirer de l\'argent du compte',
            icon = 'fas fa-minus-circle',
            onSelect = function()
                OpenWithdrawMenu()
            end
        },
        {
            title = 'Déposer de l\'argent',
            description = 'Déposer de l\'argent sur le compte',
            icon = 'fas fa-plus-circle',
            onSelect = function()
                OpenDepositMenu()
            end
        }
    })
    
    OpenMenu('boss_menu', 'Menu Patron', menuOptions)
end

RegisterNetEvent('vCore:jobs:receiveSocietyMoney', function(money)
    Notify('Solde du compte société: ' .. money .. '$', 'info')
end)

---Ouvre le menu de recrutement
function OpenHireMenu()
    -- Trouver les joueurs proches
    local players = GetNearbyPlayers(5.0)
    
    if #players == 0 then
        Notify('Aucun joueur à proximité', 'error')
        return
    end
    
    local menuOptions = {}
    
    for _, player in ipairs(players) do
        table.insert(menuOptions, {
            title = 'Joueur #' .. player.id,
            description = 'Distance: ' .. string.format('%.1f', player.distance) .. 'm',
            icon = 'fas fa-user',
            onSelect = function()
                TriggerServerEvent('vCore:jobs:hirePlayer', player.id, CurrentJob.name, 0)
            end
        })
    end
    
    OpenMenu('hire_menu', 'Recruter un joueur', menuOptions)
end

---Ouvre le menu de retrait
function OpenWithdrawMenu()
    -- Utiliser un input dialog
    local input = GetPlayerInput('Montant à retirer', 'number')
    if input and tonumber(input) and tonumber(input) > 0 then
        TriggerServerEvent('vCore:jobs:withdrawMoney', tonumber(input))
    end
end

---Ouvre le menu de dépôt
function OpenDepositMenu()
    local input = GetPlayerInput('Montant à déposer', 'number')
    if input and tonumber(input) and tonumber(input) > 0 then
        TriggerServerEvent('vCore:jobs:depositMoney', tonumber(input))
    end
end

---Récupère les joueurs proches
---@param radius number
---@return table
function GetNearbyPlayers(radius)
    local players = {}
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local targetPed = GetPlayerPed(player)
            local targetCoords = GetEntityCoords(targetPed)
            local distance = #(coords - targetCoords)
            
            if distance <= radius then
                table.insert(players, {
                    id = GetPlayerServerId(player),
                    distance = distance
                })
            end
        end
    end
    
    return players
end

---Récupère un input du joueur
---@param label string
---@param type string
---@return string|nil
function GetPlayerInput(label, type)
    -- Essayer ox_lib input
    local success, result = pcall(function()
        local input = exports.ox_lib:inputDialog(label, {
            {type = type or 'input', label = label, required = true}
        })
        return input and input[1] or nil
    end)
    
    if success and result then
        return result
    end
    
    -- Fallback basique
    DisplayOnscreenKeyboard(1, "FMMC_KEY_TIP8", "", "", "", "", "", 64)
    while UpdateOnscreenKeyboard() == 0 do
        DisableAllControlActions(0)
        Wait(0)
    end
    
    if GetOnscreenKeyboardResult() then
        return GetOnscreenKeyboardResult()
    end
    
    return nil
end

---Enregistre un sous-menu
---@param id string
---@param title string
---@param options table
function RegisterSubMenu(id, title, options)
    -- Essayer ox_lib
    pcall(function()
        exports.ox_lib:registerContext({
            id = id,
            title = title,
            menu = 'boss_menu',
            options = options
        })
    end)
end
