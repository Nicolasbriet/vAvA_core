--[[
    vAvA Core - Module Jobs
    Server - Interactions (Farm, Craft, Process, Sell)
]]

---Crée un point d'interaction
---@param source number
---@param interactionData table
---@return boolean, number|nil
RegisterNetEvent('vCore:jobs:createInteraction', function(interactionData)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    -- Vérifier les permissions admin
    if not IsPlayerAdmin(source) then
        Notify(source, JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    local success, id = pcall(function()
        return MySQL.insert.await([[
            INSERT INTO job_interactions (job_name, type, name, label, position, heading, marker, blip, config, min_grade)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?)
        ]], {
            interactionData.job_name,
            interactionData.type,
            interactionData.name,
            interactionData.label,
            json.encode(interactionData.position),
            interactionData.heading or 0.0,
            json.encode(interactionData.marker or {}),
            json.encode(interactionData.blip or {}),
            json.encode(interactionData.config or {}),
            interactionData.min_grade or 0
        })
    end)
    
    if success and id then
        LoadInteractionsFromDatabase()
        TriggerClientEvent('vCore:jobs:syncInteractions', -1, Interactions)
        Notify(source, JobsConfig.Notifications.interaction_created, 'success')
        
        local job = player:GetJob()
        LogJobAction(interactionData.job_name, player:GetIdentifier(), 'interaction_created',
            ('Point créé: %s (%s)'):format(interactionData.name, interactionData.type))
    end
end)

---Supprime un point d'interaction
---@param source number
---@param interactionId number
RegisterNetEvent('vCore:jobs:deleteInteraction', function(interactionId)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    if not IsPlayerAdmin(source) then
        Notify(source, JobsConfig.Notifications.no_permission, 'error')
        return
    end
    
    local success, affected = pcall(function()
        return MySQL.update.await('DELETE FROM job_interactions WHERE id = ?', {interactionId})
    end)
    
    if success and affected > 0 then
        LoadInteractionsFromDatabase()
        TriggerClientEvent('vCore:jobs:syncInteractions', -1, Interactions)
        Notify(source, JobsConfig.Notifications.interaction_deleted, 'success')
    end
end)

---Traite une action de farm
RegisterNetEvent('vCore:jobs:farmAction', function(interactionId)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    -- Récupérer les items farmables pour cette interaction
    local items = MySQL.query.await('SELECT * FROM job_farm_items WHERE interaction_id = ?', {interactionId})
    
    if not items or #items == 0 then
        Notify(source, JobsConfig.Notifications.farm_failed, 'error')
        return
    end
    
    -- Sélectionner un item aléatoire basé sur les chances
    local totalChance = 0
    for _, item in ipairs(items) do
        totalChance = totalChance + (item.chance or 100)
    end
    
    local random = math.random() * totalChance
    local currentChance = 0
    local selectedItem = nil
    
    for _, item in ipairs(items) do
        currentChance = currentChance + (item.chance or 100)
        if random <= currentChance then
            selectedItem = item
            break
        end
    end
    
    if not selectedItem then
        Notify(source, JobsConfig.Notifications.farm_failed, 'error')
        return
    end
    
    -- Vérifier item requis
    if selectedItem.required_item then
        if not player:HasItem(selectedItem.required_item) then
            Notify(source, JobsConfig.Notifications.no_item, 'error')
            return
        end
        
        if selectedItem.remove_required == 1 then
            player:RemoveItem(selectedItem.required_item, 1)
        end
    end
    
    -- Donner l'item
    local amount = math.random(selectedItem.amount_min or 1, selectedItem.amount_max or 1)
    
    if player:CanCarryItem(selectedItem.item_name, amount) then
        player:AddItem(selectedItem.item_name, amount)
        Notify(source, JobsConfig.Notifications.farm_success:format(amount .. 'x ' .. selectedItem.item_name), 'success')
        
        local job = player:GetJob()
        LogJobAction(job.name, player:GetIdentifier(), 'farm',
            ('Farm: %dx %s'):format(amount, selectedItem.item_name))
    else
        Notify(source, JobsConfig.Notifications.inventory_full, 'error')
    end
end)

---Traite une action de craft
RegisterNetEvent('vCore:jobs:craftAction', function(interactionId, recipeId)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    -- Récupérer la recette
    local recipe = MySQL.single.await('SELECT * FROM job_craft_recipes WHERE id = ? AND interaction_id = ? AND enabled = 1', {
        recipeId, interactionId
    })
    
    if not recipe then
        Notify(source, JobsConfig.Notifications.craft_failed, 'error')
        return
    end
    
    -- Vérifier le grade requis
    local job = player:GetJob()
    if job.grade < recipe.required_grade then
        Notify(source, JobsConfig.Notifications.grade_required, 'error')
        return
    end
    
    -- Vérifier les ingrédients
    local ingredients = json.decode(recipe.ingredients)
    for itemName, amount in pairs(ingredients) do
        if not player:HasItem(itemName, amount) then
            Notify(source, JobsConfig.Notifications.no_item, 'error')
            return
        end
    end
    
    -- Vérifier si peut porter le résultat
    if not player:CanCarryItem(recipe.result_item, recipe.result_amount) then
        Notify(source, JobsConfig.Notifications.inventory_full, 'error')
        return
    end
    
    -- Retirer les ingrédients
    for itemName, amount in pairs(ingredients) do
        player:RemoveItem(itemName, amount)
    end
    
    -- Donner le résultat
    player:AddItem(recipe.result_item, recipe.result_amount)
    Notify(source, JobsConfig.Notifications.craft_success, 'success')
    
    LogJobAction(job.name, player:GetIdentifier(), 'craft',
        ('Craft: %dx %s'):format(recipe.result_amount, recipe.result_item))
end)

---Traite une action de vente
RegisterNetEvent('vCore:jobs:sellAction', function(interactionId, itemName)
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    -- Récupérer l'item vendable
    local sellItem = MySQL.single.await('SELECT * FROM job_sell_items WHERE interaction_id = ? AND item_name = ? AND enabled = 1', {
        interactionId, itemName
    })
    
    if not sellItem then
        Notify(source, JobsConfig.Notifications.sell_failed, 'error')
        return
    end
    
    -- Vérifier si le joueur a l'item
    local itemCount = player:GetItemCount(itemName)
    if itemCount <= 0 then
        Notify(source, JobsConfig.Notifications.no_item, 'error')
        return
    end
    
    -- Calculer le total
    local totalPrice = sellItem.price * itemCount
    
    -- Retirer l'item et donner l'argent
    player:RemoveItem(itemName, itemCount)
    player:AddMoney('cash', totalPrice, 'Vente ' .. itemName)
    
    Notify(source, JobsConfig.Notifications.sell_success:format(totalPrice), 'success')
    
    local job = player:GetJob()
    LogJobAction(job.name, player:GetIdentifier(), 'sell',
        ('Vente: %dx %s pour %s$'):format(itemCount, itemName, totalPrice))
end)

---Récupère les items farmables pour une interaction
RegisterNetEvent('vCore:jobs:getFarmItems', function(interactionId)
    local source = source
    local items = MySQL.query.await('SELECT * FROM job_farm_items WHERE interaction_id = ?', {interactionId})
    TriggerClientEvent('vCore:jobs:receiveFarmItems', source, items or {})
end)

---Récupère les recettes de craft pour une interaction
RegisterNetEvent('vCore:jobs:getCraftRecipes', function(interactionId)
    local source = source
    local recipes = MySQL.query.await('SELECT * FROM job_craft_recipes WHERE interaction_id = ? AND enabled = 1', {interactionId})
    
    if recipes then
        for _, recipe in ipairs(recipes) do
            recipe.ingredients = json.decode(recipe.ingredients)
        end
    end
    
    TriggerClientEvent('vCore:jobs:receiveCraftRecipes', source, recipes or {})
end)

---Récupère les items vendables pour une interaction
RegisterNetEvent('vCore:jobs:getSellItems', function(interactionId)
    local source = source
    local items = MySQL.query.await('SELECT * FROM job_sell_items WHERE interaction_id = ? AND enabled = 1', {interactionId})
    TriggerClientEvent('vCore:jobs:receiveSellItems', source, items or {})
end)

---Récupère les véhicules de job
RegisterNetEvent('vCore:jobs:getVehicles', function()
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    local job = player:GetJob()
    local vehicles = GetJobVehicles(job.name, job.grade)
    
    TriggerClientEvent('vCore:jobs:receiveVehicles', source, vehicles)
end)

---Récupère les tenues de job
RegisterNetEvent('vCore:jobs:getOutfits', function()
    local source = source
    local player = vCore.GetPlayer(source)
    if not player then return end
    
    local job = player:GetJob()
    local ped = GetPlayerPed(source)
    local gender = GetEntityModel(ped) == `mp_f_freemode_01` and 'female' or 'male'
    
    local outfits = GetJobOutfits(job.name, gender, job.grade)
    TriggerClientEvent('vCore:jobs:receiveOutfits', source, outfits)
end)

---Vérifie si un joueur est admin
---@param source number
---@return boolean
function IsPlayerAdmin(source)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    local group = player:GetGroup()
    
    for _, adminGroup in ipairs(JobsConfig.AdminGroups) do
        if group == adminGroup then
            return true
        end
    end
    
    return false
end

exports('IsPlayerAdmin', IsPlayerAdmin)
