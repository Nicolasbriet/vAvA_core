--[[
    vAvA Core - Module Jobs
    Exemples d'utilisation et de configuration
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- EXEMPLE 1: CRÉER UN NOUVEAU JOB (BOULANGERIE)
-- ═══════════════════════════════════════════════════════════════════════════

--[[
    À exécuter via une commande admin ou event serveur
]]

RegisterCommand('createbaker', function(source, args, rawCommand)
    -- Vérifier les permissions admin
    TriggerServerEvent('vCore:jobs:createJob', {
        name = 'baker',
        label = 'Boulangerie',
        icon = 'bread-slice',
        description = 'Préparez du pain frais et des pâtisseries délicieuses',
        type = 'custom',
        default_salary = 30,
        whitelisted = false,
        society_account = true,
        blip = {
            sprite = 106,
            color = 5,
            scale = 0.7,
            label = 'Boulangerie'
        },
        grades = {
            {
                grade = 0,
                name = 'apprentice',
                label = 'Apprenti Boulanger',
                salary = 20,
                permissions = {}
            },
            {
                grade = 1,
                name = 'baker',
                label = 'Boulanger',
                salary = 40,
                permissions = {'craft', 'farm'}
            },
            {
                grade = 2,
                name = 'master',
                label = 'Maître Boulanger',
                salary = 55,
                permissions = {'craft', 'farm', 'hire'}
            },
            {
                grade = 3,
                name = 'boss',
                label = 'Patron',
                salary = 70,
                permissions = {'craft', 'farm', 'hire', 'fire', 'manage', 'withdraw'}
            }
        }
    })
end, true)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXEMPLE 2: CRÉER DES POINTS D'INTERACTION POUR LA BOULANGERIE
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('setupbaker', function(source, args, rawCommand)
    -- Point de prise de service
    TriggerServerEvent('vCore:jobs:createInteraction', {
        job_name = 'baker',
        type = 'duty',
        name = 'baker_duty',
        label = 'Prise de service',
        position = {x = -1194.53, y = -891.29, z = 13.98},
        heading = 123.45,
        min_grade = 0
    })
    
    -- Vestiaire
    TriggerServerEvent('vCore:jobs:createInteraction', {
        job_name = 'baker',
        type = 'wardrobe',
        name = 'baker_wardrobe',
        label = 'Vestiaire',
        position = {x = -1196.53, y = -891.29, z = 13.98},
        heading = 123.45,
        min_grade = 0
    })
    
    -- Point de farm pour la farine
    TriggerServerEvent('vCore:jobs:createInteraction', {
        job_name = 'baker',
        type = 'farm',
        name = 'flour_harvest',
        label = 'Récolter de la farine',
        position = {x = -1200.53, y = -891.29, z = 13.98},
        heading = 123.45,
        min_grade = 0,
        config = {
            time = 5000,
            animation = {
                dict = 'amb@world_human_gardener_plant@male@base',
                anim = 'base',
                flag = 1
            }
        }
    })
    
    -- Point de craft pour le pain
    TriggerServerEvent('vCore:jobs:createInteraction', {
        job_name = 'baker',
        type = 'craft',
        name = 'bread_craft',
        label = 'Four à pain',
        position = {x = -1198.53, y = -891.29, z = 13.98},
        heading = 123.45,
        min_grade = 1,
        config = {
            time = 10000,
            animation = {
                dict = 'anim@amb@clubhouse@tutorial@bkr_tut_ig3@',
                anim = 'machinic_loop_mechandplayer',
                flag = 49
            }
        }
    })
    
    -- Point de vente
    TriggerServerEvent('vCore:jobs:createInteraction', {
        job_name = 'baker',
        type = 'sell',
        name = 'bread_sell',
        label = 'Vendre du pain',
        position = {x = -1202.53, y = -891.29, z = 13.98},
        heading = 123.45,
        min_grade = 0
    })
    
    -- Coffre
    TriggerServerEvent('vCore:jobs:createInteraction', {
        job_name = 'baker',
        type = 'storage',
        name = 'baker_storage',
        label = 'Coffre',
        position = {x = -1197.53, y = -893.29, z = 13.98},
        heading = 123.45,
        min_grade = 0,
        config = {
            stash_name = 'baker_storage',
            max_weight = 500000,
            max_slots = 100
        }
    })
    
    -- Menu patron
    TriggerServerEvent('vCore:jobs:createInteraction', {
        job_name = 'baker',
        type = 'boss',
        name = 'baker_boss',
        label = 'Menu Patron',
        position = {x = -1195.53, y = -895.29, z = 13.98},
        heading = 123.45,
        min_grade = 3
    })
end, true)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXEMPLE 3: AJOUTER DES ITEMS ET RECETTES
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('setupbakeritems', function(source, args, rawCommand)
    local flourInteractionId = 10 -- ID du point de farm (à adapter)
    local craftInteractionId = 11 -- ID du point de craft (à adapter)
    local sellInteractionId = 12 -- ID du point de vente (à adapter)
    
    -- Items farmables
    TriggerServerEvent('vCore:jobs:addFarmItem', flourInteractionId, {
        item_name = 'wheat',
        amount_min = 2,
        amount_max = 4,
        chance = 100,
        time = 5000
    })
    
    TriggerServerEvent('vCore:jobs:addFarmItem', flourInteractionId, {
        item_name = 'water_bottle',
        amount_min = 1,
        amount_max = 2,
        chance = 50,
        time = 3000
    })
    
    -- Recettes de craft
    TriggerServerEvent('vCore:jobs:addCraftRecipe', craftInteractionId, {
        name = 'bread',
        label = 'Pain',
        result_item = 'bread',
        result_amount = 1,
        ingredients = {
            wheat = 3,
            water_bottle = 1
        },
        time = 10000,
        required_grade = 1
    })
    
    TriggerServerEvent('vCore:jobs:addCraftRecipe', craftInteractionId, {
        name = 'croissant',
        label = 'Croissant',
        result_item = 'croissant',
        result_amount = 2,
        ingredients = {
            wheat = 2,
            butter = 1
        },
        time = 12000,
        required_grade = 2
    })
    
    -- Items vendables
    TriggerServerEvent('vCore:jobs:addSellItem', sellInteractionId, {
        item_name = 'bread',
        price = 5,
        label = 'Pain'
    })
    
    TriggerServerEvent('vCore:jobs:addSellItem', sellInteractionId, {
        item_name = 'croissant',
        price = 8,
        label = 'Croissant'
    })
end, true)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXEMPLE 4: AJOUTER DES VÉHICULES ET TENUES
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('setupbakervehicles', function(source, args, rawCommand)
    -- Véhicule de livraison
    TriggerServerEvent('vCore:jobs:addVehicle', 'baker', {
        category = 'delivery',
        model = 'boxville',
        label = 'Camion de livraison',
        price = 0,
        min_grade = 1,
        livery = nil,
        extras = {}
    })
    
    -- Scooter de livraison
    TriggerServerEvent('vCore:jobs:addVehicle', 'baker', {
        category = 'delivery',
        model = 'faggio',
        label = 'Scooter de livraison',
        price = 0,
        min_grade = 0,
        livery = nil,
        extras = {}
    })
end, true)

RegisterCommand('setupbakeroutfits', function(source, args, rawCommand)
    -- Tenue homme - Apprenti
    TriggerServerEvent('vCore:jobs:addOutfit', 'baker', {
        gender = 'male',
        grade = 0,
        label = 'Tenue Apprenti',
        outfit = {
            ['3'] = {drawable = 4, texture = 0}, -- Torse
            ['4'] = {drawable = 10, texture = 0}, -- Pantalon
            ['6'] = {drawable = 10, texture = 0}, -- Chaussures
            ['8'] = {drawable = 15, texture = 0}, -- T-shirt
            ['11'] = {drawable = 10, texture = 0} -- Veste
        }
    })
    
    -- Tenue femme - Apprenti
    TriggerServerEvent('vCore:jobs:addOutfit', 'baker', {
        gender = 'female',
        grade = 0,
        label = 'Tenue Apprenti',
        outfit = {
            ['3'] = {drawable = 3, texture = 0},
            ['4'] = {drawable = 10, texture = 0},
            ['6'] = {drawable = 10, texture = 0},
            ['8'] = {drawable = 15, texture = 0},
            ['11'] = {drawable = 10, texture = 0}
        }
    })
    
    -- Tenue homme - Patron
    TriggerServerEvent('vCore:jobs:addOutfit', 'baker', {
        gender = 'male',
        grade = 3,
        label = 'Tenue Chef',
        outfit = {
            ['3'] = {drawable = 4, texture = 0},
            ['4'] = {drawable = 28, texture = 0},
            ['6'] = {drawable = 10, texture = 0},
            ['8'] = {drawable = 15, texture = 0},
            ['11'] = {drawable = 31, texture = 0}
        }
    })
end, true)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXEMPLE 5: UTILISER LES EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Côté CLIENT
RegisterCommand('checkjob', function()
    local job = exports['jobs']:GetCurrentJob()
    print('Job actuel:', job.name)
    print('Grade:', job.grade)
    print('En service:', exports['jobs']:IsOnDuty())
end, false)

-- Côté SERVER
RegisterCommand('givejob', function(source, args, rawCommand)
    if not args[1] or not args[2] or not args[3] then
        print('Usage: /givejob [id] [job] [grade]')
        return
    end
    
    local targetId = tonumber(args[1])
    local jobName = args[2]
    local grade = tonumber(args[3])
    
    exports['jobs']:SetPlayerJob(targetId, jobName, grade)
end, true)

-- Vérifier une permission
RegisterServerEvent('myresource:checkPermission', function()
    local source = source
    
    if exports['jobs']:HasJobPermission(source, 'revive') then
        print('Le joueur peut réanimer')
    end
end)

-- Gérer l'argent société
RegisterCommand('societymoney', function(source, args, rawCommand)
    local money = exports['jobs']:GetSocietyAccount('baker')
    print('Argent société baker:', money)
    
    -- Ajouter de l'argent
    exports['jobs']:AddSocietyMoney('baker', 1000)
    
    -- Retirer de l'argent
    exports['jobs']:RemoveSocietyMoney('baker', 500)
end, true)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXEMPLE 6: EVENT CUSTOM POUR INTERACTION SPÉCIALE
-- ═══════════════════════════════════════════════════════════════════════════

-- Créer une interaction custom
RegisterCommand('custominteraction', function(source, args, rawCommand)
    TriggerServerEvent('vCore:jobs:createInteraction', {
        job_name = 'baker',
        type = 'custom',
        name = 'special_oven',
        label = 'Four Spécial',
        position = {x = -1199.53, y = -892.29, z = 13.98},
        heading = 123.45,
        min_grade = 2,
        config = {
            custom_event = 'baker:useSpecialOven'
        }
    })
end, true)

-- Gérer l'event custom (CLIENT)
RegisterNetEvent('vCore:jobs:customInteraction', function(interaction)
    if interaction.name == 'special_oven' then
        -- Logique personnalisée
        local ped = PlayerPedId()
        TaskStartScenarioInPlace(ped, 'WORLD_HUMAN_STAND_FIRE', 0, true)
        
        Wait(5000)
        
        ClearPedTasks(ped)
        TriggerServerEvent('baker:craftSpecial')
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXEMPLE 7: INTÉGRATION AVEC JOBSHOP
-- ═══════════════════════════════════════════════════════════════════════════

-- Créer un point shop qui ouvre le jobshop
RegisterCommand('bakershop', function(source, args, rawCommand)
    TriggerServerEvent('vCore:jobs:createInteraction', {
        job_name = 'baker',
        type = 'shop',
        name = 'baker_shop',
        label = 'Boutique',
        position = {x = -1203.53, y = -891.29, z = 13.98},
        heading = 123.45,
        min_grade = 0,
        config = {
            shop_name = 'Boulangerie Centrale',
            items = {
                {item_name = 'bread', price = 5, stock = 100},
                {item_name = 'croissant', price = 8, stock = 50}
            }
        }
    })
end, true)

-- Gérer l'ouverture du shop (CLIENT - dans interactions.lua)
function OpenShopMenu(interaction)
    -- Intégration avec le module jobshop
    if interaction.config and interaction.config.shop_name then
        TriggerServerEvent('vCore:jobshop:openShop', interaction.config.shop_name)
    end
end
