--[[
    vAvA_hud - Configuration
    Paramètres du module HUD
]]

HUDConfig = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎮 GÉNÉRAL
-- ═══════════════════════════════════════════════════════════════════════════

HUDConfig.Enabled = true                      -- Activer le HUD

-- ═══════════════════════════════════════════════════════════════════════════
-- 📍 POSITION ET AFFICHAGE
-- ═══════════════════════════════════════════════════════════════════════════

HUDConfig.Position = {
    Status = 'bottom-left',                   -- Position des barres de status
    Money = 'top-right',                      -- Position de l'argent
    PlayerInfo = 'top-left',                  -- Position des infos joueur (ID, job, grade)
    Vehicle = 'bottom-right'                  -- Position du HUD véhicule
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎯 ÉLÉMENTS AFFICHÉS
-- ═══════════════════════════════════════════════════════════════════════════

HUDConfig.Display = {
    -- Status Bars
    Health = true,                            -- Afficher la santé
    Armor = true,                             -- Afficher l'armure
    Hunger = true,                            -- Afficher la faim
    Thirst = true,                            -- Afficher la soif
    Stress = false,                           -- Afficher le stress (désactivé par défaut)
    
    -- Argent
    Money = true,                             -- Afficher l'argent
    Cash = true,                              -- Afficher le cash
    Bank = true,                              -- Afficher la banque
    
    -- Informations Joueur
    PlayerId = true,                          -- Afficher l'ID serveur
    Job = true,                               -- Afficher le job
    Grade = true,                             -- Afficher le grade
    
    -- Véhicule
    Vehicle = true,                           -- Afficher le HUD véhicule
    Speed = true,                             -- Afficher la vitesse
    Fuel = true,                              -- Afficher le carburant
    Engine = true,                            -- Afficher l'état du moteur
    Locked = true,                            -- Afficher l'état du verrou
    Lights = true                             -- Afficher l'état des phares
}

-- ═══════════════════════════════════════════════════════════════════════════
-- ⚙️ PARAMÈTRES
-- ═══════════════════════════════════════════════════════════════════════════

HUDConfig.Settings = {
    -- Mise à jour
    UpdateInterval = 500,                     -- Intervalle de mise à jour en ms (500ms = 0.5s)
    
    -- Minimap
    Minimap = {
        enabled = true,                       -- Activer la minimap
        shape = 'circle',                     -- Forme: 'circle' ou 'square'
        zoom = 1100                           -- Niveau de zoom
    },
    
    -- HUD Natif GTA
    HideNativeHUD = true,                     -- Cacher le HUD natif de GTA
    HideComponents = {
        wantedStars = true,                   -- Cacher les étoiles de recherche
        weaponIcon = true,                    -- Cacher l'icône d'arme
        cash = true,                          -- Cacher l'argent natif
        mpCash = true,                        -- Cacher l'argent MP natif
        vehicleName = true,                   -- Cacher le nom du véhicule
        areaName = true,                      -- Cacher le nom de la zone
        vehicleClass = true,                  -- Cacher la classe du véhicule
        streetName = true                     -- Cacher le nom de la rue
    },
    
    -- Auto-Hide
    AutoHide = {
        enabled = false,                      -- Masquer automatiquement le HUD
        delay = 5000,                         -- Délai avant masquage (ms)
        showOnUpdate = true                   -- Réafficher lors d'une mise à jour
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🎨 STYLE (Charte graphique vAvA)
-- ═══════════════════════════════════════════════════════════════════════════

HUDConfig.Style = {
    -- Couleurs
    Colors = {
        primary = '#FF1E1E',                  -- Rouge Néon (principal)
        primaryDark = '#8B0000',              -- Rouge Foncé
        background = 'rgba(10, 10, 15, 0.20)', -- Fond transparent avec flou
        text = '#FFFFFF',                     -- Blanc
        textMuted = 'rgba(255, 255, 255, 0.6)', -- Blanc atténué
        
        -- Status
        health = '#FF1E1E',                   -- Rouge Néon
        armor = '#3b82f6',                    -- Bleu
        hunger = '#f59e0b',                   -- Orange
        thirst = '#06b6d4',                   -- Cyan
        stress = '#a855f7',                   -- Violet
        
        -- Argent
        cash = '#22c55e',                     -- Vert
        bank = '#3b82f6'                      -- Bleu
    },
    
    -- Typographie
    Fonts = {
        title = 'Orbitron, sans-serif',      -- Police des titres
        text = 'Montserrat, sans-serif'      -- Police du texte
    },
    
    -- Effets
    Effects = {
        blur = 'blur(15px)',                  -- Effet de flou
        glow = true,                          -- Effet de lueur néon
        animations = true                     -- Animations
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🔧 KEYBINDS
-- ═══════════════════════════════════════════════════════════════════════════

HUDConfig.Keybinds = {
    Toggle = {
        enabled = true,                       -- Activer le toggle HUD
        key = 'F7',                           -- Touche pour toggle
        command = '+toggleHUD',               -- Commande associée
        description = 'Afficher/Cacher le HUD' -- Description
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 🐛 DEBUG
-- ═══════════════════════════════════════════════════════════════════════════

HUDConfig.Debug = {
    enabled = false,                          -- Mode debug
    showLogs = false,                         -- Afficher les logs
    showValues = false,                       -- Afficher les valeurs dans la console
    command = 'debughud'                      -- Commande de debug
}

-- ═══════════════════════════════════════════════════════════════════════════
-- 📊 VALEURS PAR DÉFAUT
-- ═══════════════════════════════════════════════════════════════════════════

HUDConfig.Defaults = {
    health = 100,                             -- Santé par défaut
    armor = 0,                                -- Armure par défaut
    hunger = 100,                             -- Faim par défaut
    thirst = 100,                             -- Soif par défaut
    stress = 0,                               -- Stress par défaut
    cash = 0,                                 -- Cash par défaut
    bank = 0,                                 -- Banque par défaut
    playerId = 0,                             -- ID par défaut
    job = 'Sans emploi',                      -- Job par défaut
    grade = '-',                              -- Grade par défaut
    speed = 0,                                -- Vitesse par défaut
    fuel = 100                                -- Carburant par défaut
}
