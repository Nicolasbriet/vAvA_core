--[[
    vAvA_inventory - Configuration
]]

InventoryConfig = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- GÉNÉRAL
-- ═══════════════════════════════════════════════════════════════════════════

InventoryConfig.OpenKey = 'F2'                    -- Touche pour ouvrir l'inventaire
InventoryConfig.OpenCommand = 'inventory'         -- Commande /inventory

-- Slots et poids
InventoryConfig.MaxSlots = 50                     -- Nombre de slots max
InventoryConfig.MaxWeight = 120000                -- Poids max en grammes (120kg)

-- ═══════════════════════════════════════════════════════════════════════════
-- HOTBAR (Raccourcis 1-5)
-- ═══════════════════════════════════════════════════════════════════════════

InventoryConfig.Hotbar = {
    enabled = true,
    slots = 5,                                    -- Nombre de slots hotbar
    keys = {'1', '2', '3', '4', '5'}             -- Touches associées
}

-- ═══════════════════════════════════════════════════════════════════════════
-- ARMES
-- ═══════════════════════════════════════════════════════════════════════════

InventoryConfig.Weapons = {
    disableWeaponWheel = true,                    -- Désactiver la roue des armes GTA
    requireAmmo = true,                           -- Nécessite des munitions
    dropOnDeath = false,                          -- Drop les armes à la mort
    
    -- Animation équiper arme
    equipAnimations = {
        pistol = { dict = "reaction@intimidation@1h", anim = "intro", duration = 500 },
        rifle = { dict = "reaction@intimidation@1h", anim = "intro", duration = 800 },
        default = { dict = "reaction@intimidation@1h", anim = "intro", duration = 600 }
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- TYPES DE MUNITIONS
-- ═══════════════════════════════════════════════════════════════════════════

InventoryConfig.AmmoTypes = {
    -- Pistolets
    ['AMMO_PISTOL'] = {
        label = 'Munitions Pistolet',
        weapons = {
            'WEAPON_PISTOL', 'WEAPON_PISTOL_MK2', 'WEAPON_COMBATPISTOL',
            'WEAPON_APPISTOL', 'WEAPON_STUNGUN', 'WEAPON_PISTOL50',
            'WEAPON_SNSPISTOL', 'WEAPON_SNSPISTOL_MK2', 'WEAPON_HEAVYPISTOL',
            'WEAPON_VINTAGEPISTOL', 'WEAPON_FLAREGUN', 'WEAPON_MARKSMANPISTOL',
            'WEAPON_REVOLVER', 'WEAPON_REVOLVER_MK2', 'WEAPON_DOUBLEACTION',
            'WEAPON_RAYPISTOL', 'WEAPON_CERAMICPISTOL', 'WEAPON_NAVYREVOLVER',
            'WEAPON_GADGETPISTOL', 'WEAPON_PISTOLXM3'
        }
    },
    
    -- SMG
    ['AMMO_SMG'] = {
        label = 'Munitions SMG',
        weapons = {
            'WEAPON_MICROSMG', 'WEAPON_SMG', 'WEAPON_SMG_MK2',
            'WEAPON_ASSAULTSMG', 'WEAPON_COMBATPDW', 'WEAPON_MACHINEPISTOL',
            'WEAPON_MINISMG', 'WEAPON_RAYCARBINE'
        }
    },
    
    -- Fusils d'assaut
    ['AMMO_RIFLE'] = {
        label = 'Munitions Fusil',
        weapons = {
            'WEAPON_ASSAULTRIFLE', 'WEAPON_ASSAULTRIFLE_MK2', 'WEAPON_CARBINERIFLE',
            'WEAPON_CARBINERIFLE_MK2', 'WEAPON_ADVANCEDRIFLE', 'WEAPON_SPECIALCARBINE',
            'WEAPON_SPECIALCARBINE_MK2', 'WEAPON_BULLPUPRIFLE', 'WEAPON_BULLPUPRIFLE_MK2',
            'WEAPON_COMPACTRIFLE', 'WEAPON_MILITARYRIFLE', 'WEAPON_HEAVYRIFLE',
            'WEAPON_TACTICALRIFLE'
        }
    },
    
    -- Shotguns
    ['AMMO_SHOTGUN'] = {
        label = 'Munitions Shotgun',
        weapons = {
            'WEAPON_PUMPSHOTGUN', 'WEAPON_PUMPSHOTGUN_MK2', 'WEAPON_SAWNOFFSHOTGUN',
            'WEAPON_ASSAULTSHOTGUN', 'WEAPON_BULLPUPSHOTGUN', 'WEAPON_MUSKET',
            'WEAPON_HEAVYSHOTGUN', 'WEAPON_DBSHOTGUN', 'WEAPON_AUTOSHOTGUN',
            'WEAPON_COMBATSHOTGUN'
        }
    },
    
    -- Sniper
    ['AMMO_SNIPER'] = {
        label = 'Munitions Sniper',
        weapons = {
            'WEAPON_SNIPERRIFLE', 'WEAPON_HEAVYSNIPER', 'WEAPON_HEAVYSNIPER_MK2',
            'WEAPON_MARKSMANRIFLE', 'WEAPON_MARKSMANRIFLE_MK2', 'WEAPON_PRECISIONRIFLE'
        }
    },
    
    -- MG
    ['AMMO_MG'] = {
        label = 'Munitions Mitrailleuse',
        weapons = {
            'WEAPON_MG', 'WEAPON_COMBATMG', 'WEAPON_COMBATMG_MK2', 'WEAPON_GUSENBERG'
        }
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- DÉFINITION DES ARMES
-- ═══════════════════════════════════════════════════════════════════════════

InventoryConfig.WeaponsList = {
    -- Melee
    ['weapon_knife'] = { label = 'Couteau', weight = 500, ammo = nil, category = 'melee' },
    ['weapon_bat'] = { label = 'Batte de baseball', weight = 1000, ammo = nil, category = 'melee' },
    ['weapon_crowbar'] = { label = 'Pied de biche', weight = 1500, ammo = nil, category = 'melee' },
    ['weapon_flashlight'] = { label = 'Lampe torche', weight = 500, ammo = nil, category = 'melee' },
    ['weapon_nightstick'] = { label = 'Matraque', weight = 800, ammo = nil, category = 'melee' },
    ['weapon_hammer'] = { label = 'Marteau', weight = 1000, ammo = nil, category = 'melee' },
    ['weapon_hatchet'] = { label = 'Hachette', weight = 1200, ammo = nil, category = 'melee' },
    ['weapon_machete'] = { label = 'Machette', weight = 1500, ammo = nil, category = 'melee' },
    ['weapon_switchblade'] = { label = 'Couteau papillon', weight = 300, ammo = nil, category = 'melee' },
    
    -- Pistolets
    ['weapon_pistol'] = { label = 'Pistol', weight = 1000, ammo = 'AMMO_PISTOL', category = 'pistol' },
    ['weapon_pistol_mk2'] = { label = 'Pistol MK2', weight = 1100, ammo = 'AMMO_PISTOL', category = 'pistol' },
    ['weapon_combatpistol'] = { label = 'Combat Pistol', weight = 1100, ammo = 'AMMO_PISTOL', category = 'pistol' },
    ['weapon_appistol'] = { label = 'AP Pistol', weight = 1200, ammo = 'AMMO_PISTOL', category = 'pistol' },
    ['weapon_pistol50'] = { label = 'Pistol .50', weight = 1500, ammo = 'AMMO_PISTOL', category = 'pistol' },
    ['weapon_heavypistol'] = { label = 'Heavy Pistol', weight = 1400, ammo = 'AMMO_PISTOL', category = 'pistol' },
    ['weapon_vintagepistol'] = { label = 'Vintage Pistol', weight = 1200, ammo = 'AMMO_PISTOL', category = 'pistol' },
    ['weapon_snspistol'] = { label = 'SNS Pistol', weight = 800, ammo = 'AMMO_PISTOL', category = 'pistol' },
    ['weapon_snspistol_mk2'] = { label = 'SNS Pistol MK2', weight = 900, ammo = 'AMMO_PISTOL', category = 'pistol' },
    ['weapon_revolver'] = { label = 'Revolver', weight = 1600, ammo = 'AMMO_PISTOL', category = 'pistol' },
    ['weapon_revolver_mk2'] = { label = 'Revolver MK2', weight = 1700, ammo = 'AMMO_PISTOL', category = 'pistol' },
    ['weapon_doubleaction'] = { label = 'Double Action', weight = 1400, ammo = 'AMMO_PISTOL', category = 'pistol' },
    ['weapon_ceramicpistol'] = { label = 'Ceramic Pistol', weight = 900, ammo = 'AMMO_PISTOL', category = 'pistol' },
    
    -- SMG
    ['weapon_microsmg'] = { label = 'Micro SMG', weight = 2000, ammo = 'AMMO_SMG', category = 'smg' },
    ['weapon_smg'] = { label = 'SMG', weight = 2500, ammo = 'AMMO_SMG', category = 'smg' },
    ['weapon_smg_mk2'] = { label = 'SMG MK2', weight = 2600, ammo = 'AMMO_SMG', category = 'smg' },
    ['weapon_assaultsmg'] = { label = 'Assault SMG', weight = 2800, ammo = 'AMMO_SMG', category = 'smg' },
    ['weapon_combatpdw'] = { label = 'Combat PDW', weight = 2700, ammo = 'AMMO_SMG', category = 'smg' },
    ['weapon_machinepistol'] = { label = 'Machine Pistol', weight = 1800, ammo = 'AMMO_SMG', category = 'smg' },
    ['weapon_minismg'] = { label = 'Mini SMG', weight = 2200, ammo = 'AMMO_SMG', category = 'smg' },
    
    -- Fusils
    ['weapon_assaultrifle'] = { label = 'Assault Rifle', weight = 4000, ammo = 'AMMO_RIFLE', category = 'rifle' },
    ['weapon_assaultrifle_mk2'] = { label = 'Assault Rifle MK2', weight = 4200, ammo = 'AMMO_RIFLE', category = 'rifle' },
    ['weapon_carbinerifle'] = { label = 'Carbine Rifle', weight = 3800, ammo = 'AMMO_RIFLE', category = 'rifle' },
    ['weapon_carbinerifle_mk2'] = { label = 'Carbine Rifle MK2', weight = 4000, ammo = 'AMMO_RIFLE', category = 'rifle' },
    ['weapon_advancedrifle'] = { label = 'Advanced Rifle', weight = 4500, ammo = 'AMMO_RIFLE', category = 'rifle' },
    ['weapon_specialcarbine'] = { label = 'Special Carbine', weight = 4200, ammo = 'AMMO_RIFLE', category = 'rifle' },
    ['weapon_specialcarbine_mk2'] = { label = 'Special Carbine MK2', weight = 4400, ammo = 'AMMO_RIFLE', category = 'rifle' },
    ['weapon_bullpuprifle'] = { label = 'Bullpup Rifle', weight = 3900, ammo = 'AMMO_RIFLE', category = 'rifle' },
    ['weapon_bullpuprifle_mk2'] = { label = 'Bullpup Rifle MK2', weight = 4100, ammo = 'AMMO_RIFLE', category = 'rifle' },
    ['weapon_compactrifle'] = { label = 'Compact Rifle', weight = 3500, ammo = 'AMMO_RIFLE', category = 'rifle' },
    ['weapon_militaryrifle'] = { label = 'Military Rifle', weight = 4800, ammo = 'AMMO_RIFLE', category = 'rifle' },
    
    -- Shotguns
    ['weapon_pumpshotgun'] = { label = 'Pump Shotgun', weight = 3500, ammo = 'AMMO_SHOTGUN', category = 'shotgun' },
    ['weapon_pumpshotgun_mk2'] = { label = 'Pump Shotgun MK2', weight = 3700, ammo = 'AMMO_SHOTGUN', category = 'shotgun' },
    ['weapon_sawnoffshotgun'] = { label = 'Sawed-Off Shotgun', weight = 2800, ammo = 'AMMO_SHOTGUN', category = 'shotgun' },
    ['weapon_assaultshotgun'] = { label = 'Assault Shotgun', weight = 4000, ammo = 'AMMO_SHOTGUN', category = 'shotgun' },
    ['weapon_bullpupshotgun'] = { label = 'Bullpup Shotgun', weight = 3800, ammo = 'AMMO_SHOTGUN', category = 'shotgun' },
    ['weapon_heavyshotgun'] = { label = 'Heavy Shotgun', weight = 4200, ammo = 'AMMO_SHOTGUN', category = 'shotgun' },
    ['weapon_dbshotgun'] = { label = 'Double Barrel Shotgun', weight = 3200, ammo = 'AMMO_SHOTGUN', category = 'shotgun' },
    ['weapon_autoshotgun'] = { label = 'Auto Shotgun', weight = 4500, ammo = 'AMMO_SHOTGUN', category = 'shotgun' },
    ['weapon_combatshotgun'] = { label = 'Combat Shotgun', weight = 4300, ammo = 'AMMO_SHOTGUN', category = 'shotgun' },
    
    -- Snipers
    ['weapon_sniperrifle'] = { label = 'Sniper Rifle', weight = 5000, ammo = 'AMMO_SNIPER', category = 'sniper' },
    ['weapon_heavysniper'] = { label = 'Heavy Sniper', weight = 6000, ammo = 'AMMO_SNIPER', category = 'sniper' },
    ['weapon_heavysniper_mk2'] = { label = 'Heavy Sniper MK2', weight = 6200, ammo = 'AMMO_SNIPER', category = 'sniper' },
    ['weapon_marksmanrifle'] = { label = 'Marksman Rifle', weight = 4800, ammo = 'AMMO_SNIPER', category = 'sniper' },
    ['weapon_marksmanrifle_mk2'] = { label = 'Marksman Rifle MK2', weight = 5000, ammo = 'AMMO_SNIPER', category = 'sniper' },
    
    -- MG
    ['weapon_mg'] = { label = 'MG', weight = 8000, ammo = 'AMMO_MG', category = 'mg' },
    ['weapon_combatmg'] = { label = 'Combat MG', weight = 8500, ammo = 'AMMO_MG', category = 'mg' },
    ['weapon_combatmg_mk2'] = { label = 'Combat MG MK2', weight = 8700, ammo = 'AMMO_MG', category = 'mg' },
    ['weapon_gusenberg'] = { label = 'Gusenberg', weight = 6000, ammo = 'AMMO_MG', category = 'mg' },
    
    -- Throwables
    ['weapon_grenade'] = { label = 'Grenade', weight = 400, ammo = nil, category = 'throwable' },
    ['weapon_bzgas'] = { label = 'Gaz BZ', weight = 400, ammo = nil, category = 'throwable' },
    ['weapon_molotov'] = { label = 'Cocktail Molotov', weight = 500, ammo = nil, category = 'throwable' },
    ['weapon_stickybomb'] = { label = 'Bombe collante', weight = 500, ammo = nil, category = 'throwable' },
    ['weapon_proxmine'] = { label = 'Mine de proximité', weight = 500, ammo = nil, category = 'throwable' },
    ['weapon_snowball'] = { label = 'Boule de neige', weight = 100, ammo = nil, category = 'throwable' },
    ['weapon_pipebomb'] = { label = 'Pipe bomb', weight = 500, ammo = nil, category = 'throwable' },
    ['weapon_smokegrenade'] = { label = 'Grenade fumigène', weight = 400, ammo = nil, category = 'throwable' },
    ['weapon_flare'] = { label = 'Fusée éclairante', weight = 300, ammo = nil, category = 'throwable' },
    
    -- Autre
    ['weapon_stungun'] = { label = 'Taser', weight = 800, ammo = nil, category = 'special' },
    ['weapon_petrolcan'] = { label = 'Jerrycan', weight = 5000, ammo = nil, category = 'special' },
    ['weapon_fireextinguisher'] = { label = 'Extincteur', weight = 3000, ammo = nil, category = 'special' },
    ['weapon_parachute'] = { label = 'Parachute', weight = 4000, ammo = nil, category = 'special' }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- ITEMS DE MUNITIONS
-- ═══════════════════════════════════════════════════════════════════════════

InventoryConfig.AmmoItems = {
    ['ammo_pistol'] = { label = 'Munitions Pistolet', ammoType = 'AMMO_PISTOL', count = 12 },
    ['ammo_smg'] = { label = 'Munitions SMG', ammoType = 'AMMO_SMG', count = 30 },
    ['ammo_rifle'] = { label = 'Munitions Fusil', ammoType = 'AMMO_RIFLE', count = 30 },
    ['ammo_shotgun'] = { label = 'Munitions Shotgun', ammoType = 'AMMO_SHOTGUN', count = 8 },
    ['ammo_sniper'] = { label = 'Munitions Sniper', ammoType = 'AMMO_SNIPER', count = 5 },
    ['ammo_mg'] = { label = 'Munitions Mitrailleuse', ammoType = 'AMMO_MG', count = 50 }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- DROP
-- ═══════════════════════════════════════════════════════════════════════════

InventoryConfig.Drops = {
    enabled = true,
    maxDropDistance = 2.0,                        -- Distance max pour ramasser
    despawnTime = 300,                            -- Temps avant disparition (secondes)
    markerType = 2,                               -- Type de marker
    markerColor = {255, 255, 255, 100}           -- Couleur RGBA
}

-- ═══════════════════════════════════════════════════════════════════════════
-- SHOPS / COFFRES
-- ═══════════════════════════════════════════════════════════════════════════

InventoryConfig.Stashes = {
    defaultSlots = 50,
    defaultWeight = 200000
}
