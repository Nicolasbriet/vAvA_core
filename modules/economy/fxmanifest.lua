-- ══════════════════════════════════════════════════════════════════════════════
-- vAvA_core - Module Economy
-- Système d'économie automatique, centralisé et auto-adaptatif
-- Version: 1.0.0
-- ══════════════════════════════════════════════════════════════════════════════

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'vAvA'
description 'Système économique automatique et auto-adaptatif pour vAvA_core'
version '1.0.0'

-- ══════════════════════════════════════════════════════════════════════════════
-- Dépendances
-- ══════════════════════════════════════════════════════════════════════════════

dependencies {
    'vAvA_core',
    'oxmysql'
}

-- ══════════════════════════════════════════════════════════════════════════════
-- Fichiers partagés
-- ══════════════════════════════════════════════════════════════════════════════

shared_scripts {
    '@vAvA_core/shared/utils.lua',
    'locales/*.lua',
    'config/*.lua',
    'shared/*.lua'
}

-- ══════════════════════════════════════════════════════════════════════════════
-- Fichiers serveur
-- ══════════════════════════════════════════════════════════════════════════════

server_scripts {
    '@oxmysql/lib/MySQL.lua',
    'server/*.lua'
}

-- ══════════════════════════════════════════════════════════════════════════════
-- Fichiers client
-- ══════════════════════════════════════════════════════════════════════════════

client_scripts {
    'client/*.lua'
}

-- ══════════════════════════════════════════════════════════════════════════════
-- Fichiers UI
-- ══════════════════════════════════════════════════════════════════════════════

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js'
}

-- ══════════════════════════════════════════════════════════════════════════════
-- Exports Server
-- ══════════════════════════════════════════════════════════════════════════════

exports {
    'GetPrice',
    'GetSalary',
    'GetShopMultiplier',
    'ApplyTax',
    'RecalculateEconomy',
    'GetItemRarity',
    'GetFinalPrice',
    'GetEconomyState',
    'SetBaseMultiplier',
    'SetTax',
    'GetInflation'
}

server_exports {
    'GetPrice',
    'GetSalary',
    'GetShopMultiplier',
    'ApplyTax',
    'RecalculateEconomy',
    'GetItemRarity',
    'GetFinalPrice',
    'GetEconomyState',
    'SetBaseMultiplier',
    'SetTax',
    'GetInflation',
    'UpdateItemPrice',
    'UpdateJobSalary',
    'GetEconomyLogs',
    'ResetEconomy'
}
