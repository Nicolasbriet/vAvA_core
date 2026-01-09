--[[
    vAvA Core - Module JobShop
    Server-side avec intégration economy
]]

local vCore = nil
local JobShops = {}

-- Vérifier si le module economy est chargé
local EconomyEnabled = false

-- Initialisation du framework
CreateThread(function()
    -- Essayer de récupérer vCore
    TriggerEvent('vCore:getSharedObject', function(obj) vCore = obj end)
    
    if not vCore then
        -- Fallback sur l'export
        local success, result = pcall(function()
            return exports['vAvA_core']:GetCoreObject()
        end)
        if success then
            vCore = result
        end
    end
    
    Wait(1000)
    CreateTables()
    Wait(500)
    LoadAllShops()
    
    -- Vérifier economy après l'init
    Wait(2000)
    if GetResourceState('vAvA_economy') == 'started' then
        EconomyEnabled = true
        print('^2[vCore:JobShop] Module economy détecté et activé^0')
    else
        print('^3[vCore:JobShop] Module economy non trouvé - Prix fixes utilisés^0')
    end
end)

---Obtenir le prix d'un item via le système economy
---@param itemName string
---@param shopId number
---@param quantity number
---@return number
local function GetItemPrice(itemName, shopId, quantity)
    if not EconomyEnabled then
        -- Prix fixe si economy non disponible (retourner le prix BD)
        return nil  -- Utiliser le prix de la BD
    end
    
    -- Déterminer le shop multiplier
    local shop = JobShops[shopId]
    local shopType = shop and shop.job or 'general'
    
    -- Utiliser le système economy
    return exports['vAvA_economy']:GetPrice(itemName, shopType, quantity or 1)
end

---Appliquer une taxe via le système economy
---@param amount number
---@return number
local function ApplyTax(amount)
    if not EconomyEnabled then
        -- Pas de taxe si economy non disponible
        return amount
    end
    
    return exports['vAvA_economy']:ApplyTax('achat', amount)
end

---Enregistrer une transaction dans le système economy
---@param transactionType string
---@param itemName string
---@param quantity number
---@param price number
local function RegisterTransaction(transactionType, itemName, quantity, price)
    if not EconomyEnabled then return end
    
    exports['vAvA_economy']:RegisterTransaction(
        transactionType,
        itemName,
        'item',
        quantity,
        price
    )
end

-- ================================
-- FONCTIONS UTILITAIRES
-- ================================

local function GetPlayer(source)
    if vCore and vCore.Functions and vCore.Functions.GetPlayer then
        return vCore.Functions.GetPlayer(source)
    end
    return nil
end

local function Notify(source, message, type)
    if GetResourceState('ox_lib') == 'started' then
        TriggerClientEvent('ox_lib:notify', source, {
            title = 'JobShop',
            description = message,
            type = type or 'info'
        })
    else
        TriggerClientEvent('vCore:notification', source, message, type)
    end
end

local function IsAdmin(source)
    -- Méthode principale: utiliser vCore.IsAdmin (basé sur txAdmin ACE)
    if vCore and vCore.IsAdmin then
        return vCore.IsAdmin(source)
    end
    
    -- Fallback: vérifier directement les ACE
    if IsPlayerAceAllowed(source, 'vava.admin') then return true end
    if IsPlayerAceAllowed(source, 'vava.superadmin') then return true end
    if IsPlayerAceAllowed(source, 'vava.owner') then return true end
    if IsPlayerAceAllowed(source, 'txadmin.operator') then return true end
    
    return false
end

local function IsBoss(Player, job, grade)
    if not Player or not Player.PlayerData or not Player.PlayerData.job then
        return false
    end
    return Player.PlayerData.job.name == job and Player.PlayerData.job.grade.level >= grade
end

local function IsEmployee(Player, job)
    if not Player or not Player.PlayerData or not Player.PlayerData.job then
        return false
    end
    return Player.PlayerData.job.name == job
end

-- ================================
-- CRÉATION AUTOMATIQUE DES TABLES
-- ================================

function CreateTables()
    -- Table des boutiques
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `job_shops` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `name` varchar(50) NOT NULL,
            `job` varchar(50) NOT NULL,
            `boss_grade` int(11) NOT NULL DEFAULT 0,
            `x` float NOT NULL,
            `y` float NOT NULL,
            `z` float NOT NULL,
            `heading` float NOT NULL DEFAULT 0,
            `cash` int(11) NOT NULL DEFAULT 0,
            `created_at` timestamp NOT NULL DEFAULT CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            KEY `idx_job` (`job`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        print('[vAvA Core - JobShop] Table job_shops créée/vérifiée')
    end)
    
    -- Table des items de boutique
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `job_shop_items` (
            `id` int(11) NOT NULL AUTO_INCREMENT,
            `shop_id` int(11) NOT NULL,
            `item_name` varchar(50) NOT NULL,
            `label` varchar(100) DEFAULT NULL,
            `price` int(11) NOT NULL DEFAULT 0,
            `stock` int(11) NOT NULL DEFAULT 0,
            `max_stock` int(11) NOT NULL DEFAULT 100,
            `enabled` tinyint(1) NOT NULL DEFAULT 1,
            PRIMARY KEY (`id`),
            UNIQUE KEY `unique_shop_item` (`shop_id`, `item_name`),
            KEY `idx_shop_id` (`shop_id`),
            CONSTRAINT `fk_shop_items_shop` FOREIGN KEY (`shop_id`) REFERENCES `job_shops` (`id`) ON DELETE CASCADE
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4;
    ]], {}, function()
        print('[vAvA Core - JobShop] Table job_shop_items créée/vérifiée')
    end)
end

-- ================================
-- CHARGEMENT DES BOUTIQUES
-- ================================

function LoadAllShops()
    MySQL.Async.fetchAll('SELECT * FROM job_shops', {}, function(shops)
        JobShops = {}
        if shops then
            for _, shop in pairs(shops) do
                JobShops[shop.id] = shop
            end
            print(('[vAvA Core - JobShop] %d boutique(s) chargée(s)'):format(#shops))
        end
        
        -- Synchroniser avec tous les clients
        TriggerClientEvent('vCore:jobshop:syncShops', -1, JobShops)
    end)
end

-- ================================
-- CALLBACKS
-- ================================

if vCore and vCore.Functions and vCore.Functions.CreateCallback then
    vCore.Functions.CreateCallback('vCore:jobshop:getShops', function(source, cb)
        cb(JobShops)
    end)
    
    vCore.Functions.CreateCallback('vCore:jobshop:getPlayerItems', function(source, cb, shopId)
        local Player = GetPlayer(source)
        if not Player or not JobShops[shopId] then
            cb({})
            return
        end
        
        -- Récupérer les items de la boutique
        MySQL.Async.fetchAll('SELECT item_name, stock FROM job_shop_items WHERE shop_id = @shop_id', {
            ['@shop_id'] = shopId
        }, function(shopItems)
            local availableItems = {}
            local playerItems = Player.PlayerData.items or {}
            
            -- Pour chaque item de la boutique, vérifier si le joueur en possède
            for _, shopItem in pairs(shopItems) do
                for _, playerItem in pairs(playerItems) do
                    if playerItem.name == shopItem.item_name and playerItem.amount > 0 then
                        table.insert(availableItems, {
                            name = shopItem.item_name,
                            playerAmount = playerItem.amount,
                            shopStock = shopItem.stock
                        })
                        break
                    end
                end
            end
            
            cb(availableItems)
        end)
    end)
end

-- Fallback callback système
RegisterNetEvent('vCore:jobshop:requestShops', function()
    local src = source
    TriggerClientEvent('vCore:jobshop:receiveShops', src, JobShops)
end)

-- ================================
-- GESTION DES BOUTIQUES
-- ================================

RegisterNetEvent('vCore:jobshop:createShop', function(data)
    local src = source
    
    if not IsAdmin(src) then
        Notify(src, JobShopConfig.Notifications.no_permission, 'error')
        return
    end
    
    MySQL.Async.insert('INSERT INTO job_shops (name, job, boss_grade, x, y, z, heading, cash) VALUES (@name, @job, @boss_grade, @x, @y, @z, @heading, 0)', {
        ['@name'] = data.name,
        ['@job'] = data.job,
        ['@boss_grade'] = data.boss_grade or 0,
        ['@x'] = data.coords.x,
        ['@y'] = data.coords.y,
        ['@z'] = data.coords.z,
        ['@heading'] = data.coords.w or 0.0
    }, function(id)
        if id then
            JobShops[id] = {
                id = id,
                name = data.name,
                job = data.job,
                boss_grade = data.boss_grade or 0,
                x = data.coords.x,
                y = data.coords.y,
                z = data.coords.z,
                heading = data.coords.w or 0.0,
                cash = 0
            }
            
            Notify(src, JobShopConfig.Notifications.shop_created, 'success')
            TriggerClientEvent('vCore:jobshop:syncShops', -1, JobShops)
        else
            Notify(src, 'Erreur lors de la création', 'error')
        end
    end)
end)

RegisterNetEvent('vCore:jobshop:deleteShop', function(shopId)
    local src = source
    
    if not IsAdmin(src) then
        Notify(src, JobShopConfig.Notifications.no_permission, 'error')
        return
    end
    
    if not JobShops[shopId] then
        Notify(src, JobShopConfig.Notifications.shop_not_found, 'error')
        return
    end
    
    MySQL.Async.execute('DELETE FROM job_shops WHERE id = @id', {
        ['@id'] = shopId
    }, function(affectedRows)
        if affectedRows > 0 then
            -- Supprimer aussi les items
            MySQL.Async.execute('DELETE FROM job_shop_items WHERE shop_id = @shop_id', {
                ['@shop_id'] = shopId
            })
            
            JobShops[shopId] = nil
            Notify(src, JobShopConfig.Notifications.shop_deleted, 'success')
            TriggerClientEvent('vCore:jobshop:syncShops', -1, JobShops)
        end
    end)
end)

-- ================================
-- GESTION BOUTIQUE (CLIENT)
-- ================================

RegisterNetEvent('vCore:jobshop:getShopData', function(shopId)
    local src = source
    
    if not JobShops[shopId] then
        Notify(src, JobShopConfig.Notifications.shop_not_found, 'error')
        return
    end
    
    MySQL.Async.fetchAll('SELECT * FROM job_shop_items WHERE shop_id = @shop_id AND enabled = 1', {
        ['@shop_id'] = shopId
    }, function(items)
        TriggerClientEvent('vCore:jobshop:openShop', src, {
            shop = JobShops[shopId],
            items = items or {}
        })
    end)
end)

RegisterNetEvent('vCore:jobshop:buyItem', function(shopId, itemName, quantity)
    local src = source
    local Player = GetPlayer(src)
    
    if not Player then return end
    if not JobShops[shopId] then return end
    
    quantity = tonumber(quantity) or 1
    if quantity < 1 then
        Notify(src, JobShopConfig.Notifications.invalid_amount, 'error')
        return
    end
    
    MySQL.Async.fetchSingle('SELECT * FROM job_shop_items WHERE shop_id = @shop_id AND item_name = @item_name AND enabled = 1', {
        ['@shop_id'] = shopId,
        ['@item_name'] = itemName
    }, function(item)
        if not item then
            Notify(src, JobShopConfig.Notifications.item_not_found, 'error')
            return
        end
        
        if item.stock < quantity then
            Notify(src, JobShopConfig.Notifications.insufficient_stock, 'error')
            return
        end
        
        -- Utiliser le système economy si disponible, sinon prix de la BD
        local basePrice = GetItemPrice(itemName, shopId, quantity)
        if not basePrice then
            basePrice = item.price * quantity
        end
        
        -- Appliquer la taxe
        local totalPrice = ApplyTax(basePrice)
        local currency = JobShopConfig.CurrencyType
        
        if Player.Functions.GetMoney(currency) < totalPrice then
            Notify(src, JobShopConfig.Notifications.insufficient_funds, 'error')
            return
        end
        
        if Player.Functions.RemoveMoney(currency, totalPrice) then
            Player.Functions.AddItem(itemName, quantity)
            
            -- Mettre à jour le stock
            MySQL.Async.execute('UPDATE job_shop_items SET stock = stock - @quantity WHERE shop_id = @shop_id AND item_name = @item_name', {
                ['@quantity'] = quantity,
                ['@shop_id'] = shopId,
                ['@item_name'] = itemName
            })
            
            -- Ajouter à la caisse
            MySQL.Async.execute('UPDATE job_shops SET cash = cash + @amount WHERE id = @id', {
                ['@amount'] = totalPrice,
                ['@id'] = shopId
            })
            
            JobShops[shopId].cash = (JobShops[shopId].cash or 0) + totalPrice
            
            Notify(src, JobShopConfig.Notifications.item_bought .. ' ($' .. totalPrice .. ')', 'success')
            
            -- Enregistrer la transaction dans economy (si disponible)
            RegisterTransaction('achat', itemName, quantity, totalPrice)
            
            -- Rafraîchir l'affichage
            TriggerEvent('vCore:jobshop:getShopData', shopId)
        end
    end)
end)

-- ================================
-- GESTION PATRON
-- ================================

RegisterNetEvent('vCore:jobshop:getBossMenu', function(shopId)
    local src = source
    local Player = GetPlayer(src)
    
    if not Player or not JobShops[shopId] then return end
    
    local shop = JobShops[shopId]
    
    if not IsBoss(Player, shop.job, shop.boss_grade) then
        Notify(src, JobShopConfig.Notifications.not_boss, 'error')
        return
    end
    
    MySQL.Async.fetchAll('SELECT * FROM job_shop_items WHERE shop_id = @shop_id', {
        ['@shop_id'] = shopId
    }, function(items)
        TriggerClientEvent('vCore:jobshop:openBossMenu', src, {
            shop = shop,
            items = items or {}
        })
    end)
end)

RegisterNetEvent('vCore:jobshop:setItemPrice', function(shopId, itemName, price)
    local src = source
    local Player = GetPlayer(src)
    
    if not Player or not JobShops[shopId] then return end
    
    local shop = JobShops[shopId]
    
    if not IsBoss(Player, shop.job, shop.boss_grade) then
        Notify(src, JobShopConfig.Notifications.not_boss, 'error')
        return
    end
    
    price = tonumber(price) or 0
    if price < 0 then
        Notify(src, JobShopConfig.Notifications.invalid_amount, 'error')
        return
    end
    
    MySQL.Async.execute('UPDATE job_shop_items SET price = @price WHERE shop_id = @shop_id AND item_name = @item_name', {
        ['@price'] = price,
        ['@shop_id'] = shopId,
        ['@item_name'] = itemName
    }, function(affectedRows)
        if affectedRows > 0 then
            Notify(src, JobShopConfig.Notifications.price_updated, 'success')
            TriggerEvent('vCore:jobshop:getBossMenu', shopId)
        end
    end)
end)

RegisterNetEvent('vCore:jobshop:addItem', function(shopId, itemName, price, stock)
    local src = source
    local Player = GetPlayer(src)
    
    if not Player or not JobShops[shopId] then return end
    
    local shop = JobShops[shopId]
    
    if not IsBoss(Player, shop.job, shop.boss_grade) then
        Notify(src, JobShopConfig.Notifications.not_boss, 'error')
        return
    end
    
    -- Vérifier si l'item existe déjà
    MySQL.Async.fetchSingle('SELECT * FROM job_shop_items WHERE shop_id = @shop_id AND item_name = @item_name', {
        ['@shop_id'] = shopId,
        ['@item_name'] = itemName
    }, function(existing)
        if existing then
            -- Mettre à jour
            MySQL.Async.execute('UPDATE job_shop_items SET price = @price, stock = stock + @stock, enabled = 1 WHERE shop_id = @shop_id AND item_name = @item_name', {
                ['@price'] = price,
                ['@stock'] = stock,
                ['@shop_id'] = shopId,
                ['@item_name'] = itemName
            })
        else
            -- Insérer
            MySQL.Async.insert('INSERT INTO job_shop_items (shop_id, item_name, price, stock, enabled) VALUES (@shop_id, @item_name, @price, @stock, 1)', {
                ['@shop_id'] = shopId,
                ['@item_name'] = itemName,
                ['@price'] = price,
                ['@stock'] = stock
            })
        end
        
        Notify(src, JobShopConfig.Notifications.item_added, 'success')
        TriggerEvent('vCore:jobshop:getBossMenu', shopId)
    end)
end)

RegisterNetEvent('vCore:jobshop:toggleItem', function(shopId, itemName, enabled)
    local src = source
    local Player = GetPlayer(src)
    
    if not Player or not JobShops[shopId] then return end
    
    local shop = JobShops[shopId]
    
    if not IsBoss(Player, shop.job, shop.boss_grade) then
        Notify(src, JobShopConfig.Notifications.not_boss, 'error')
        return
    end
    
    MySQL.Async.execute('UPDATE job_shop_items SET enabled = @enabled WHERE shop_id = @shop_id AND item_name = @item_name', {
        ['@enabled'] = enabled and 1 or 0,
        ['@shop_id'] = shopId,
        ['@item_name'] = itemName
    })
    
    TriggerEvent('vCore:jobshop:getBossMenu', shopId)
end)

RegisterNetEvent('vCore:jobshop:withdrawMoney', function(shopId, amount)
    local src = source
    local Player = GetPlayer(src)
    
    if not Player or not JobShops[shopId] then return end
    
    local shop = JobShops[shopId]
    
    if not IsBoss(Player, shop.job, shop.boss_grade) then
        Notify(src, JobShopConfig.Notifications.not_boss, 'error')
        return
    end
    
    amount = tonumber(amount) or 0
    if amount <= 0 then
        Notify(src, JobShopConfig.Notifications.invalid_amount, 'error')
        return
    end
    
    -- Retirer avec vérification atomique
    MySQL.Async.execute('UPDATE job_shops SET cash = cash - @amount WHERE id = @id AND cash >= @amount', {
        ['@amount'] = amount,
        ['@id'] = shopId
    }, function(affectedRows)
        if affectedRows and affectedRows > 0 then
            Player.Functions.AddMoney('cash', amount)
            
            -- Mettre à jour le cache
            MySQL.Async.fetchSingle('SELECT cash FROM job_shops WHERE id = @id', {
                ['@id'] = shopId
            }, function(shopData)
                if shopData then
                    JobShops[shopId].cash = shopData.cash
                end
            end)
            
            Notify(src, JobShopConfig.Notifications.money_withdrawn, 'success')
            TriggerEvent('vCore:jobshop:getBossMenu', shopId)
        else
            Notify(src, JobShopConfig.Notifications.insufficient_funds, 'error')
        end
    end)
end)

-- ================================
-- GESTION STOCK (EMPLOYÉ)
-- ================================

RegisterNetEvent('vCore:jobshop:addStock', function(shopId, itemName, quantity)
    local src = source
    local Player = GetPlayer(src)
    
    if not Player or not JobShops[shopId] then return end
    
    local shop = JobShops[shopId]
    
    if not IsEmployee(Player, shop.job) then
        Notify(src, JobShopConfig.Notifications.not_employee, 'error')
        return
    end
    
    quantity = tonumber(quantity) or 0
    if quantity <= 0 then
        Notify(src, JobShopConfig.Notifications.invalid_amount, 'error')
        return
    end
    
    -- Vérifier que le joueur a l'item
    local hasItem = false
    local playerItems = Player.PlayerData.items or {}
    for _, item in pairs(playerItems) do
        if item.name == itemName and item.amount >= quantity then
            hasItem = true
            break
        end
    end
    
    if not hasItem then
        Notify(src, 'Vous n\'avez pas assez de cet item', 'error')
        return
    end
    
    -- Retirer l'item du joueur
    if Player.Functions.RemoveItem(itemName, quantity) then
        -- Ajouter au stock
        MySQL.Async.execute('UPDATE job_shop_items SET stock = stock + @quantity WHERE shop_id = @shop_id AND item_name = @item_name', {
            ['@quantity'] = quantity,
            ['@shop_id'] = shopId,
            ['@item_name'] = itemName
        }, function(affectedRows)
            if affectedRows > 0 then
                Notify(src, JobShopConfig.Notifications.stock_added, 'success')
            end
        end)
    end
end)

-- ================================
-- EXPORTS SERVEUR
-- ================================

exports('GetShops', function()
    return JobShops
end)

exports('GetShopData', function(shopId)
    return JobShops[shopId]
end)

exports('CreateShop', function(data)
    TriggerEvent('vCore:jobshop:createShop', data)
end)

exports('DeleteShop', function(shopId)
    TriggerEvent('vCore:jobshop:deleteShop', shopId)
end)

exports('AddShopItem', function(shopId, itemName, price, stock)
    MySQL.Async.execute('INSERT INTO job_shop_items (shop_id, item_name, price, stock, enabled) VALUES (@shop_id, @item_name, @price, @stock, 1) ON DUPLICATE KEY UPDATE price = @price, stock = stock + @stock', {
        ['@shop_id'] = shopId,
        ['@item_name'] = itemName,
        ['@price'] = price,
        ['@stock'] = stock
    })
end)

exports('UpdateItemPrice', function(shopId, itemName, price)
    MySQL.Async.execute('UPDATE job_shop_items SET price = @price WHERE shop_id = @shop_id AND item_name = @item_name', {
        ['@price'] = price,
        ['@shop_id'] = shopId,
        ['@item_name'] = itemName
    })
end)

exports('AddStock', function(shopId, itemName, quantity)
    MySQL.Async.execute('UPDATE job_shop_items SET stock = stock + @quantity WHERE shop_id = @shop_id AND item_name = @item_name', {
        ['@quantity'] = quantity,
        ['@shop_id'] = shopId,
        ['@item_name'] = itemName
    })
end)

-- ================================
-- COMMANDES ADMIN
-- ================================

RegisterCommand('jobshopadmin', function(source, args)
    local src = source
    
    if not IsAdmin(src) then
        Notify(src, JobShopConfig.Notifications.no_permission, 'error')
        return
    end
    
    TriggerClientEvent('vCore:jobshop:openAdminMenu', src, JobShops)
end, false)

RegisterCommand('jobshoplist', function(source, args)
    local src = source
    
    if not IsAdmin(src) then
        Notify(src, JobShopConfig.Notifications.no_permission, 'error')
        return
    end
    
    if not JobShops or next(JobShops) == nil then
        Notify(src, 'Aucune boutique trouvée', 'info')
        return
    end
    
    for shopId, shop in pairs(JobShops) do
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 255, 0},
            args = {"[JobShop]", string.format("ID: %d | %s | Job: %s | Caisse: $%d", shop.id, shop.name, shop.job, shop.cash or 0)}
        })
    end
end, false)

-- Event de reload
AddEventHandler('onResourceStart', function(resourceName)
    if GetCurrentResourceName() == resourceName then
        Wait(2000)
        LoadAllShops()
    end
end)
