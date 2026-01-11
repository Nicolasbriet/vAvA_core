--[[
    vAvA_hud - Module HUD
    Système d'affichage HUD moderne avec status, argent, job et véhicule
    Version: 1.0.0
    Auteur: vAvA
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vAvA_hud'
author 'vAvA'
version '1.0.0'
description 'Module HUD moderne pour vAvA_core'

-- ═══════════════════════════════════════════════════════════════════════════
-- DÉPENDANCES
-- ═══════════════════════════════════════════════════════════════════════════

dependencies {
    'vAvA_core'
}

-- ═══════════════════════════════════════════════════════════════════════════
-- SHARED
-- ═══════════════════════════════════════════════════════════════════════════

shared_scripts {
    'config/config.lua',
    'shared/api.lua'
}

-- ═══════════════════════════════════════════════════════════════════════════
-- CLIENT
-- ═══════════════════════════════════════════════════════════════════════════

client_scripts {
    'client/main.lua'
}

-- ═══════════════════════════════════════════════════════════════════════════
-- NUI
-- ═══════════════════════════════════════════════════════════════════════════

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/css/*.css',
    'html/js/*.js'
}

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Client Exports
exports {
    'ShowHUD',
    'HideHUD',
    'ToggleHUD',
    'IsHUDVisible',
    'UpdateStatus',
    'UpdateMoney',
    'UpdatePlayerInfo',
    'UpdateVehicle',
    'ShowVehicleHud',
    'HideVehicleHud'
}
