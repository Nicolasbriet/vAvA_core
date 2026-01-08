--[[
    vAvA Core - Module JobShop
    Configuration
]]

JobShopConfig = {}

-- Debug mode
JobShopConfig.Debug = false

-- Groupes admin
JobShopConfig.AdminGroups = {'admin', 'god', 'superadmin'}

-- Modèle du PNJ vendeur
JobShopConfig.PedModel = 'a_m_m_business_01'

-- Limites
JobShopConfig.MaxItemsPerShop = 50
JobShopConfig.MaxStockPerItem = 999

-- Distance d'interaction
JobShopConfig.InteractionDistance = 2.5

-- Type de devise pour les achats
JobShopConfig.CurrencyType = 'cash' -- 'cash' ou 'bank'

-- Configuration des blips
JobShopConfig.Blip = {
    sprite = 52,
    color = 2,
    scale = 0.6,
    shortRange = true
}

-- Messages de notification
JobShopConfig.Notifications = {
    shop_created = 'Boutique créée avec succès',
    shop_deleted = 'Boutique supprimée avec succès',
    item_added = 'Article ajouté au stock',
    item_bought = 'Achat effectué avec succès',
    insufficient_funds = 'Fonds insuffisants',
    insufficient_stock = 'Stock insuffisant',
    no_permission = 'Vous n\'avez pas la permission',
    money_withdrawn = 'Argent retiré du coffre',
    not_boss = 'Seul le patron peut faire cela',
    not_employee = 'Vous ne travaillez pas pour ce job',
    shop_not_found = 'Boutique introuvable',
    item_not_found = 'Article introuvable',
    invalid_amount = 'Montant invalide',
    no_items = 'Aucun article à approvisionner',
    stock_added = 'Stock ajouté avec succès',
    price_updated = 'Prix modifié avec succès'
}

-- Configuration du menu admin
JobShopConfig.AdminMenu = {
    creation_timeout = 30000,
    marker_color = {r = 0, g = 255, b = 0, a = 100},
    marker_size = {x = 1.5, y = 1.5, z = 1.0}
}

-- Boutiques par défaut (créées au premier démarrage)
JobShopConfig.DefaultShops = {
    -- Exemple:
    -- {
    --     name = "Boulangerie Central",
    --     job = "baker",
    --     boss_grade = 3,
    --     position = vector4(100.0, 200.0, 30.0, 180.0)
    -- }
}

-- Items par défaut pour les nouvelles boutiques
JobShopConfig.DefaultItems = {
    -- {item_name = "bread", price = 5, stock = 100}
}
