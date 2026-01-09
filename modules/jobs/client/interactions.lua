--[[
    vAvA Core - Module Jobs
    Client - Interactions (Farm, Craft, Process, Sell)
]]

---Démarre une action de farm
---@param interaction table
function StartFarmAction(interaction)
    local ped = PlayerPedId()
    local animConfig = interaction.config.animation or JobsConfig.DefaultAnimations.farm
    local time = interaction.config.time or 5000
    
    -- Charger l'animation
    if animConfig and animConfig.dict then
        RequestAnimDict(animConfig.dict)
        while not HasAnimDictLoaded(animConfig.dict) do
            Wait(10)
        end
        
        TaskPlayAnim(ped, animConfig.dict, animConfig.anim, 8.0, -8.0, -1, animConfig.flag or 1, 0, false, false, false)
    end
    
    -- Freeze le joueur
    FreezeEntityPosition(ped, true)
    
    -- Barre de progression
    local success = ProgressBar(time, 'Récolte en cours...')
    
    -- Nettoyage
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    
    if success then
        TriggerServerEvent('vCore:jobs:farmAction', interaction.id)
    else
        Notify(JobsConfig.Notifications.farm_failed, 'error')
    end
end

---Ouvre le menu de craft
---@param interaction table
function OpenCraftMenu(interaction)
    TriggerServerEvent('vCore:jobs:getCraftRecipes', interaction.id)
end

RegisterNetEvent('vCore:jobs:receiveCraftRecipes', function(recipes)
    if not recipes or #recipes == 0 then
        Notify('Aucune recette disponible', 'info')
        return
    end
    
    local menuOptions = {}
    
    for _, recipe in ipairs(recipes) do
        -- Construire la liste des ingrédients
        local ingredientsText = ''
        for itemName, amount in pairs(recipe.ingredients) do
            ingredientsText = ingredientsText .. amount .. 'x ' .. itemName .. ', '
        end
        ingredientsText = ingredientsText:sub(1, -3) -- Enlever la dernière virgule
        
        table.insert(menuOptions, {
            title = recipe.label,
            description = 'Ingrédients: ' .. ingredientsText,
            icon = 'fas fa-hammer',
            onSelect = function()
                StartCraftAction(recipe)
            end
        })
    end
    
    -- Ouvrir le menu
    OpenMenu('craft_menu', 'Fabrication', menuOptions)
end)

---Démarre une action de craft
---@param recipe table
function StartCraftAction(recipe)
    local ped = PlayerPedId()
    local animConfig = recipe.animation or JobsConfig.DefaultAnimations.craft
    local time = recipe.time or 10000
    
    -- Charger l'animation
    if animConfig and animConfig.dict then
        RequestAnimDict(animConfig.dict)
        while not HasAnimDictLoaded(animConfig.dict) do
            Wait(10)
        end
        
        TaskPlayAnim(ped, animConfig.dict, animConfig.anim, 8.0, -8.0, -1, animConfig.flag or 49, 0, false, false, false)
    end
    
    -- Freeze le joueur
    FreezeEntityPosition(ped, true)
    
    -- Barre de progression
    local success = ProgressBar(time, 'Fabrication en cours...')
    
    -- Nettoyage
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    
    if success then
        TriggerServerEvent('vCore:jobs:craftAction', recipe.interaction_id, recipe.id)
    else
        Notify(JobsConfig.Notifications.craft_failed, 'error')
    end
end

---Démarre une action de process
---@param interaction table
function StartProcessAction(interaction)
    local ped = PlayerPedId()
    local animConfig = interaction.config.animation or JobsConfig.DefaultAnimations.process
    local time = interaction.config.time or 8000
    
    -- Charger l'animation
    if animConfig and animConfig.dict then
        RequestAnimDict(animConfig.dict)
        while not HasAnimDictLoaded(animConfig.dict) do
            Wait(10)
        end
        
        TaskPlayAnim(ped, animConfig.dict, animConfig.anim, 8.0, -8.0, -1, animConfig.flag or 49, 0, false, false, false)
    end
    
    -- Freeze le joueur
    FreezeEntityPosition(ped, true)
    
    -- Barre de progression
    local success = ProgressBar(time, 'Traitement en cours...')
    
    -- Nettoyage
    FreezeEntityPosition(ped, false)
    ClearPedTasks(ped)
    
    if success then
        TriggerServerEvent('vCore:jobs:processAction', interaction.id)
    else
        Notify(JobsConfig.Notifications.process_failed, 'error')
    end
end

---Ouvre le menu de vente
---@param interaction table
function OpenSellMenu(interaction)
    TriggerServerEvent('vCore:jobs:getSellItems', interaction.id)
end

RegisterNetEvent('vCore:jobs:receiveSellItems', function(items)
    if not items or #items == 0 then
        Notify('Aucun item à vendre', 'info')
        return
    end
    
    local menuOptions = {}
    
    for _, item in ipairs(items) do
        table.insert(menuOptions, {
            title = item.label or item.item_name,
            description = 'Prix: ' .. item.price .. '$',
            icon = 'fas fa-dollar-sign',
            onSelect = function()
                TriggerServerEvent('vCore:jobs:sellAction', item.interaction_id, item.item_name)
            end
        })
    end
    
    -- Ouvrir le menu
    OpenMenu('sell_menu', 'Vendre des items', menuOptions)
end)

---Ouvre le stockage
---@param interaction table
function OpenStorage(interaction)
    local stashName = interaction.config.stash_name or ('job_storage_' .. CurrentJob.name)
    local maxWeight = interaction.config.max_weight or 500000
    local maxSlots = interaction.config.max_slots or 100
    
    -- Utiliser ox_inventory si disponible
    local success = pcall(function()
        exports.ox_inventory:openInventory('stash', {
            id = stashName,
            maxWeight = maxWeight,
            slots = maxSlots
        })
    end)
    
    if not success then
        -- Fallback vers un autre système d'inventaire
        TriggerEvent('vCore:openStorage', stashName, maxWeight, maxSlots)
    end
end

---Barre de progression
---@param time number
---@param label string
---@return boolean
function ProgressBar(time, label)
    local success = false
    
    -- Essayer ox_lib progressbar
    local oxSuccess = pcall(function()
        success = exports.ox_lib:progressBar({
            duration = time,
            label = label,
            useWhileDead = false,
            canCancel = true,
            disable = {
                move = true,
                car = true,
                combat = true
            }
        })
    end)
    
    if not oxSuccess then
        -- Fallback simple
        local startTime = GetGameTimer()
        while GetGameTimer() - startTime < time do
            Wait(100)
            
            -- Afficher un texte basique
            DrawText2D(0.5, 0.9, label, 0.4)
            
            -- Vérifier annulation
            if IsControlJustReleased(0, 73) then -- X
                return false
            end
        end
        success = true
    end
    
    return success
end

---Affiche du texte 2D
---@param x number
---@param y number
---@param text string
---@param scale number
function DrawText2D(x, y, text, scale)
    SetTextFont(4)
    SetTextProportional(0)
    SetTextScale(scale, scale)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow(0, 0, 0, 0, 255)
    SetTextEdge(2, 0, 0, 0, 255)
    SetTextDropShadow()
    SetTextOutline()
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(x, y)
end

---Ouvre un menu générique
---@param id string
---@param title string
---@param options table
function OpenMenu(id, title, options)
    -- Essayer ox_lib context menu
    local oxSuccess = pcall(function()
        exports.ox_lib:registerContext({
            id = id,
            title = title,
            options = options
        })
        exports.ox_lib:showContext(id)
    end)
    
    if not oxSuccess then
        -- Fallback vers NUI custom ou autre système de menu
        SendNUIMessage({
            action = 'openMenu',
            id = id,
            title = title,
            options = options
        })
        SetNuiFocus(true, true)
        IsNUIOpen = true
    end
end

---Ferme le NUI
RegisterNUICallback('closeMenu', function(data, cb)
    SetNuiFocus(false, false)
    IsNUIOpen = false
    cb('ok')
end)

RegisterNUICallback('selectOption', function(data, cb)
    if data.callback then
        -- Exécuter le callback
        local func = load('return ' .. data.callback)()
        if type(func) == 'function' then
            func()
        end
    end
    cb('ok')
end)
