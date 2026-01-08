--[[
    vAvA_inventory - Liste des items
    Définition des items disponibles
]]

Items = {
    -- ═══════════════════════════════════════════════════════════════════
    -- CONSOMMABLES
    -- ═══════════════════════════════════════════════════════════════════
    
    bread = {
        name = 'bread',
        label = 'Pain',
        weight = 0.2,
        stackable = true,
        maxStack = 50,
        description = 'Un délicieux pain frais',
        usable = true
    },
    
    water = {
        name = 'water',
        label = 'Bouteille d\'eau',
        weight = 0.3,
        stackable = true,
        maxStack = 30,
        description = 'De l\'eau fraîche',
        usable = true
    },
    
    burger = {
        name = 'burger',
        label = 'Burger',
        weight = 0.4,
        stackable = true,
        maxStack = 20,
        description = 'Un burger juteux',
        usable = true
    },
    
    sandwich = {
        name = 'sandwich',
        label = 'Sandwich',
        weight = 0.3,
        stackable = true,
        maxStack = 30,
        description = 'Un sandwich club',
        usable = true
    },
    
    cola = {
        name = 'cola',
        label = 'eCola',
        weight = 0.3,
        stackable = true,
        maxStack = 30,
        description = 'Boisson gazeuse rafraîchissante',
        usable = true
    },
    
    coffee = {
        name = 'coffee',
        label = 'Café',
        weight = 0.2,
        stackable = true,
        maxStack = 20,
        description = 'Café bien chaud',
        usable = true
    },
    
    donut = {
        name = 'donut',
        label = 'Donut',
        weight = 0.1,
        stackable = true,
        maxStack = 50,
        description = 'Donut glacé',
        usable = true
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- MÉDICAL
    -- ═══════════════════════════════════════════════════════════════════
    
    bandage = {
        name = 'bandage',
        label = 'Bandage',
        weight = 0.1,
        stackable = true,
        maxStack = 30,
        description = 'Bandage de premiers soins',
        usable = true
    },
    
    medkit = {
        name = 'medkit',
        label = 'Trousse de soins',
        weight = 1.0,
        stackable = true,
        maxStack = 5,
        description = 'Trousse de premiers soins complète',
        usable = true
    },
    
    painkiller = {
        name = 'painkiller',
        label = 'Anti-douleur',
        weight = 0.1,
        stackable = true,
        maxStack = 50,
        description = 'Soulage la douleur',
        usable = true
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- OUTILS
    -- ═══════════════════════════════════════════════════════════════════
    
    lockpick = {
        name = 'lockpick',
        label = 'Crochet',
        weight = 0.1,
        stackable = true,
        maxStack = 20,
        description = 'Pour ouvrir des serrures',
        usable = true
    },
    
    repairkit = {
        name = 'repairkit',
        label = 'Kit de réparation',
        weight = 3.0,
        stackable = true,
        maxStack = 5,
        description = 'Pour réparer les véhicules',
        usable = true
    },
    
    flashlight = {
        name = 'flashlight',
        label = 'Lampe torche',
        weight = 0.5,
        stackable = false,
        description = 'Éclaire dans l\'obscurité',
        usable = true
    },
    
    rope = {
        name = 'rope',
        label = 'Corde',
        weight = 1.0,
        stackable = true,
        maxStack = 10,
        description = 'Corde solide',
        usable = false
    },
    
    ductape = {
        name = 'ductape',
        label = 'Ruban adhésif',
        weight = 0.2,
        stackable = true,
        maxStack = 30,
        description = 'Résout tous les problèmes',
        usable = false
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- ÉLECTRONIQUE
    -- ═══════════════════════════════════════════════════════════════════
    
    phone = {
        name = 'phone',
        label = 'Téléphone',
        weight = 0.2,
        stackable = false,
        description = 'Téléphone portable',
        usable = true
    },
    
    radio = {
        name = 'radio',
        label = 'Radio',
        weight = 0.5,
        stackable = false,
        description = 'Radio portative',
        usable = true
    },
    
    gps = {
        name = 'gps',
        label = 'GPS',
        weight = 0.2,
        stackable = false,
        description = 'Système de navigation',
        usable = true
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- DIVERS
    -- ═══════════════════════════════════════════════════════════════════
    
    money = {
        name = 'money',
        label = 'Argent liquide',
        weight = 0.0,
        stackable = true,
        maxStack = 999999,
        description = 'Billets de banque',
        usable = false
    },
    
    id_card = {
        name = 'id_card',
        label = 'Carte d\'identité',
        weight = 0.0,
        stackable = false,
        description = 'Pièce d\'identité officielle',
        usable = true
    },
    
    driver_license = {
        name = 'driver_license',
        label = 'Permis de conduire',
        weight = 0.0,
        stackable = false,
        description = 'Permis de conduire valide',
        usable = true
    },
    
    weapon_license = {
        name = 'weapon_license',
        label = 'Permis port d\'arme',
        weight = 0.0,
        stackable = false,
        description = 'Permis de port d\'arme',
        usable = true
    },

    -- ═══════════════════════════════════════════════════════════════════
    -- VÉHICULES
    -- ═══════════════════════════════════════════════════════════════════
    
    car_keys = {
        name = 'car_keys',
        label = 'Clés de voiture',
        weight = 0.1,
        stackable = false,
        description = 'Clés de véhicule',
        usable = true
    },
    
    fuel_can = {
        name = 'fuel_can',
        label = 'Jerrycan',
        weight = 5.0,
        stackable = true,
        maxStack = 5,
        description = 'Bidon d\'essence',
        usable = true
    },
    
    nitro = {
        name = 'nitro',
        label = 'Nitro',
        weight = 3.0,
        stackable = true,
        maxStack = 3,
        description = 'Bouteille de nitro',
        usable = true
    }
}

-- Export pour accès externe
function GetItem(itemName)
    return Items[string.lower(itemName)]
end

function GetItemLabel(itemName)
    local item = Items[string.lower(itemName)]
    return item and item.label or itemName
end
