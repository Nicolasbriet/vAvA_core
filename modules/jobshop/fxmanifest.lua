--[[
    vAvA Core - Module JobShop
    Système de boutiques pour jobs avec gestion admin/patron
    
    Exports Client:
    - OpenJobShop(shopId): Ouvrir une boutique
    - OpenBossMenu(shopId): Ouvrir le menu patron
    - OpenStockMenu(shopId): Ouvrir le menu approvisionnement
    
    Exports Serveur:
    - GetShops(): Récupérer toutes les boutiques
    - GetShopData(shopId): Récupérer les données d'une boutique
    - CreateShop(data): Créer une nouvelle boutique
    - DeleteShop(shopId): Supprimer une boutique
    - AddShopItem(shopId, itemName, price, stock): Ajouter un item
    - UpdateItemPrice(shopId, itemName, price): Modifier le prix
    - AddStock(shopId, itemName, quantity): Ajouter du stock
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vAvA_core_jobshop'
description 'Module JobShop - Boutiques pour jobs avec gestion admin/patron'
version '1.0.0'
author 'vAvA'

-- Dépendances
dependencies {
    'vAvA_core',
    'oxmysql'
}

-- Scripts partagés
shared_scripts {
    'config.lua'
}

-- Scripts client
client_scripts {
    'client/main.lua'
}

-- Scripts serveur
server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/main.lua'
}

-- Interface NUI
ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/style.css',
    'html/js/app.js'
}
