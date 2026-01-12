--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                   vAvA Creator - Server Main                              ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]--

-- Attendre que vCore soit disponible (bloquant au démarrage)
local vCore = nil
while not vCore do
    vCore = exports['vAvA_core']:GetCoreObject()
    if not vCore then Citizen.Wait(100) end
end

print('^2[vAvA Creator]^0 Module initialisé')

-- ═══════════════════════════════════════════════════════════════════════════
-- BASE DE DONNÉES
-- ═══════════════════════════════════════════════════════════════════════════

local function CreateTables()
    MySQL.Async.execute([[
        CREATE TABLE IF NOT EXISTS `vava_characters` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `citizenid` VARCHAR(50) NOT NULL,
            `license` VARCHAR(100) NOT NULL,
            `slot` INT(11) NOT NULL DEFAULT 1,
            `firstname` VARCHAR(50) NOT NULL,
            `lastname` VARCHAR(50) NOT NULL,
            `age` INT(11) NOT NULL DEFAULT 25,
            `gender` TINYINT(1) NOT NULL DEFAULT 0,
            `nationality` VARCHAR(50) DEFAULT 'Américain',
            `story` TEXT DEFAULT NULL,
            `skin_data` LONGTEXT DEFAULT NULL,
            `clothes_data` LONGTEXT DEFAULT NULL,
            `position` VARCHAR(255) DEFAULT '{"x":-1045.35,"y":-2750.53,"z":21.36,"h":326.72}',
            `money` VARCHAR(255) DEFAULT '{"cash":500,"bank":5000}',
            `job` VARCHAR(100) DEFAULT '{"name":"unemployed","label":"Chômeur","grade":0,"gradeLabel":""}',
            `gang` VARCHAR(255) DEFAULT NULL,
            `metadata` LONGTEXT DEFAULT NULL,
            `inventory` LONGTEXT DEFAULT NULL,
            `created_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP,
            `updated_at` TIMESTAMP DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            `last_played` TIMESTAMP NULL DEFAULT NULL,
            `is_deleted` TINYINT(1) DEFAULT 0,
            PRIMARY KEY (`id`),
            UNIQUE KEY `citizenid` (`citizenid`),
            KEY `license` (`license`),
            KEY `slot` (`license`, `slot`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]], {}, function(success)
        if success then
            print('^2[vAvA Creator]^0 Tables créées/vérifiées')
        end
    end)
end

-- Créer les tables au démarrage
CreateThread(function()
    CreateTables()
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

local function GetPlayerLicense(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in pairs(identifiers) do
        if string.match(id, 'license:') then
            return id
        end
    end
    return nil
end

local function GenerateCitizenId()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789'
    local id = ''
    for i = 1, 8 do
        local rand = math.random(1, #chars)
        id = id .. string.sub(chars, rand, rand)
    end
    return 'VVA' .. id
end

local function IsValidName(name)
    if not name or type(name) ~= 'string' then return false end
    local len = string.len(name)
    if len < Config.Creator.MinNameLength or len > Config.Creator.MaxNameLength then
        return false
    end
    if not string.match(name, "^[%a%s%-']+$") then
        return false
    end
    return true
end

local function IsValidAge(age)
    if not age or type(age) ~= 'number' then return false end
    return age >= Config.Creator.MinAge and age <= Config.Creator.MaxAge
end

local function SanitizeSkinData(skinData)
    if not skinData or type(skinData) ~= 'table' then
        return nil
    end
    
    local sanitized = {}
    for key, value in pairs(skinData) do
        if type(value) == 'number' then
            if string.match(key, 'Opacity') then
                sanitized[key] = math.max(0, math.min(1, value))
            elseif string.match(key, 'Color') or string.match(key, 'hair') or string.match(key, 'beard') then
                sanitized[key] = math.max(-1, math.min(100, math.floor(value)))
            elseif string.match(key, 'Width|Height|Length|Thickness') then
                sanitized[key] = math.max(-1, math.min(1, value))
            else
                sanitized[key] = value
            end
        else
            sanitized[key] = value
        end
    end
    
    return sanitized
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

-- Récupérer les personnages d'un joueur
vCore.RegisterServerCallback('vava_creator:getCharacters', function(source, cb, player)
    local license = GetPlayerLicense(source)
    if not license then
        cb({ success = false, error = 'License introuvable' })
        return
    end
    
    MySQL.Async.fetchAll([[
        SELECT id, identifier, firstname, lastname, dob, gender, 
               job, metadata, last_played
        FROM characters 
        WHERE identifier = ?
        ORDER BY last_played DESC
    ]], { license }, function(results)
        local characters = {}
        for _, row in ipairs(results) do
            local jobData = row.job and json.decode(row.job) or { name = 'unemployed' }
            local metadata = row.metadata and json.decode(row.metadata) or {}
            
            table.insert(characters, {
                id = row.id,
                citizenid = row.id, -- Pour compatibilité
                slot = row.id,
                firstname = row.firstname,
                lastname = row.lastname,
                fullname = row.firstname .. ' ' .. row.lastname,
                age = metadata.age or 25,
                gender = row.gender or 0,
                nationality = metadata.nationality or 'Française',
                skin = metadata.skin or nil,
                clothes = metadata.clothes or nil,
                job = jobData,
                lastPlayed = row.last_played
            })
        end
        
        cb({
            success = true,
            characters = characters,
            maxCharacters = Config.Creator.MaxCharacters,
            canCreate = #characters < Config.Creator.MaxCharacters
        })
    end)
end)

-- Vérifier si un slot est disponible
vCore.RegisterServerCallback('vava_creator:checkSlot', function(source, cb, player, slot)
    local license = GetPlayerLicense(source)
    if not license then
        cb({ available = false })
        return
    end
    
    MySQL.Async.fetchScalar([[
        SELECT COUNT(*) FROM characters 
        WHERE identifier LIKE ? AND slot = ?
    ]], { '%' .. license .. '%', slot }, function(count)
        cb({ available = count == 0 })
    end)
end)

-- Créer un nouveau personnage
vCore.RegisterServerCallback('vava_creator:createCharacter', function(source, cb, player, data)
    local license = GetPlayerLicense(source)
    if not license then
        cb({ success = false, error = 'License introuvable' })
        return
    end
    
    -- Validation des données
    if not IsValidName(data.firstname) then
        cb({ success = false, error = 'Prénom invalide' })
        return
    end
    
    if not IsValidName(data.lastname) then
        cb({ success = false, error = 'Nom invalide' })
        return
    end
    
    if not IsValidAge(data.age) then
        cb({ success = false, error = 'Âge invalide' })
        return
    end
    
    local skinData = SanitizeSkinData(data.skin)
    if not skinData then
        cb({ success = false, error = 'Données de skin invalides' })
        return
    end
    
    -- Générer un CitizenID unique
    local citizenid = GenerateCitizenId()
    
    -- Trouver le premier slot disponible
    MySQL.Async.fetchScalar([[
        SELECT COALESCE(MAX(slot), 0) + 1 FROM characters 
        WHERE identifier = ?
    ]], { identifier }, function(slot)
        if slot > Config.Creator.MaxCharacters then
            cb({ success = false, error = 'Nombre maximum de personnages atteint' })
            return
        end
        
        -- Position par défaut
        local defaultPos = Config.Creator.FirstSpawn
        local position = json.encode({
            x = defaultPos.x,
            y = defaultPos.y,
            z = defaultPos.z,
            h = defaultPos.w
        })
        
        -- Argent par défaut
        local money = json.encode({
            cash = 500,
            bank = 5000
        })
        
        -- Job par défaut
        local job = json.encode({
            name = 'unemployed',
            label = 'Chômeur',
            grade = 0,
            gradeLabel = ''
        })
        
        MySQL.Async.insert([[
            INSERT INTO characters 
            (identifier, slot, firstname, lastname, dob, gender, nationality, story, skin_data, clothes_data, position, money, job, last_played)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ]], {
            identifier,
            slot,
            data.firstname,
            data.lastname,
            data.dob or '1990-01-01',
            data.gender or 0,
            data.nationality or 'Américain',
            data.story or '',
            json.encode(skinData),
            json.encode(data.clothes or {}),
            position,
            money,
            job
        }, function(id)
            if id then
                -- Log la création
                if vCore.Logs then
                    vCore.Logs('character_create', string.format(
                        'Nouveau personnage créé: %s %s (ID: %s) par %s',
                        data.firstname, data.lastname, citizenid, license
                    ), source)
                end
                
                cb({
                    success = true,
                    citizenid = citizenid,
                    slot = slot,
                    message = 'Personnage créé avec succès!'
                })
            else
                cb({ success = false, error = 'Erreur lors de la création' })
            end
        end)
    end)
end)

-- Charger un personnage
vCore.RegisterServerCallback('vava_creator:loadCharacter', function(source, cb, player, citizenid)
    local license = GetPlayerLicense(source)
    if not license then
        cb({ success = false, error = 'License introuvable' })
        return
    end
    
    MySQL.Async.fetchAll([[
        SELECT * FROM vava_characters 
        WHERE citizenid = ? AND license = ? AND is_deleted = 0
    ]], { citizenid, license }, function(results)
        if #results == 0 then
            cb({ success = false, error = 'Personnage introuvable' })
            return
        end
        
        local char = results[1]
        
        -- Mettre à jour last_played
        MySQL.Async.execute([[
            UPDATE vava_characters SET last_played = NOW() WHERE citizenid = ?
        ]], { citizenid })
        
        -- Construire les données du personnage
        local characterData = {
            citizenid = char.citizenid,
            license = char.license,
            slot = char.slot,
            firstname = char.firstname,
            lastname = char.lastname,
            fullname = char.firstname .. ' ' .. char.lastname,
            age = char.age,
            gender = char.gender,
            nationality = char.nationality,
            story = char.story,
            skin = char.skin_data and json.decode(char.skin_data) or nil,
            clothes = char.clothes_data and json.decode(char.clothes_data) or nil,
            position = char.position and json.decode(char.position) or nil,
            money = char.money and json.decode(char.money) or { cash = 0, bank = 0 },
            job = char.job and json.decode(char.job) or { name = 'unemployed', label = 'Chômeur', grade = 0 },
            gang = char.gang and json.decode(char.gang) or nil,
            metadata = char.metadata and json.decode(char.metadata) or {},
            inventory = char.inventory and json.decode(char.inventory) or {}
        }
        
        -- Enregistrer le joueur dans vCore
        if vCore.RegisterPlayer then
            vCore.RegisterPlayer(source, characterData)
        end
        
        -- Trigger l'event de chargement
        TriggerClientEvent('vava_creator:characterLoaded', source, characterData)
        
        cb({
            success = true,
            character = characterData
        })
    end)
end)

-- Supprimer un personnage
vCore.RegisterServerCallback('vava_creator:deleteCharacter', function(source, cb, player, citizenid)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        cb({ success = false, error = 'Identifier introuvable' })
        return
    end
    
    -- Supprimer définitivement le personnage de la table characters
    MySQL.Async.execute([[
        DELETE FROM characters WHERE id = ? AND identifier = ?
    ]], { citizenid, identifier }, function(rowsChanged)
        if rowsChanged > 0 then
            -- Log la suppression
            if vCore.Logs then
                vCore.Logs('character_delete', string.format(
                    'Personnage supprimé: ID %s par %s',
                    citizenid, identifier
                ), source)
            end
            
            cb({ success = true, message = 'Personnage supprimé' })
        else
            cb({ success = false, error = 'Personnage introuvable' })
        end
    end)
end)
        end
    end)
end)

-- Sauvegarder le skin
vCore.RegisterServerCallback('vava_creator:saveSkin', function(source, cb, player, citizenid, skinData)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        cb({ success = false, error = 'Identifier introuvable' })
        return
    end
    
    local sanitizedSkin = SanitizeSkinData(skinData)
    if not sanitizedSkin then
        cb({ success = false, error = 'Données invalides' })
        return
    end
    
    MySQL.Async.execute([[
        UPDATE characters SET skin_data = ? WHERE id = ? AND identifier = ?
    ]], { json.encode(sanitizedSkin), citizenid, identifier }, function(rowsChanged)
        if rowsChanged > 0 then
            cb({ success = true })
        else
            cb({ success = false, error = 'Erreur de sauvegarde' })
        end
    end)
end)

-- Sauvegarder les vêtements
vCore.RegisterServerCallback('vava_creator:saveClothes', function(source, cb, player, citizenid, clothesData)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        cb({ success = false, error = 'Identifier introuvable' })
        return
    end
    
    MySQL.Async.execute([[
        UPDATE characters SET clothes_data = ? WHERE id = ? AND identifier = ?
    ]], { json.encode(clothesData), citizenid, identifier }, function(rowsChanged)
        if rowsChanged > 0 then
            cb({ success = true })
        else
            cb({ success = false, error = 'Erreur de sauvegarde' })
        end
    end)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EVENTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Quand un joueur se connecte
AddEventHandler('playerConnecting', function(name, setKickReason, deferrals)
    local source = source
    deferrals.defer()
    
    Citizen.Wait(0)
    deferrals.update('Vérification du compte...')
    
    local license = GetPlayerLicense(source)
    if not license then
        deferrals.done('Impossible de récupérer votre license. Reconnectez-vous.')
        return
    end
    
    deferrals.done()
end)

-- Quand un joueur spawn (après connexion)
RegisterNetEvent('vava_creator:playerLoaded', function()
    local source = source
    local license = GetPlayerLicense(source)
    
    print('[vAvA_creator] Player loaded:', source, 'License:', license)
    
    -- Vérifier si le joueur a des personnages (utiliser la table 'characters' du core)
    MySQL.Async.fetchAll([[
        SELECT * FROM characters WHERE identifier = ? ORDER BY last_played DESC
    ]], { license }, function(characters)
        local count = #characters
        print('[vAvA_creator] Character count for', license, ':', count)
        
        if count == 0 then
            -- Ouvrir directement le créateur
            print('[vAvA_creator] Opening creator for new player')
            TriggerClientEvent('vava_creator:openCreator', source, true)
        else
            -- Toujours afficher la sélection (même avec 1 seul perso)
            print('[vAvA_creator] Opening character selection')
            TriggerClientEvent('vava_creator:openSelection', source)
        end
    end)
end)

-- Sauvegarder la position du joueur
RegisterNetEvent('vava_creator:savePosition', function(position)
    local source = source
    local player = vCore and vCore.GetPlayer and vCore.GetPlayer(source)
    
    if player and player.PlayerData and player.charId then
        MySQL.Async.execute([[
            UPDATE characters SET position = ? WHERE id = ?
        ]], { json.encode(position), player.charId })
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('OpenCreator', function(source)
    TriggerClientEvent('vava_creator:openCreator', source, false)
end)

exports('OpenSelection', function(source)
    TriggerClientEvent('vava_creator:openSelection', source)
end)

exports('GetCharacterData', function(charId)
    local result = MySQL.Sync.fetchAll([[
        SELECT * FROM characters WHERE id = ?
    ]], { charId })
    
    if #result > 0 then
        local char = result[1]
        return {
            id = char.id,
            firstname = char.firstname,
            lastname = char.lastname,
            skin = char.skin_data and json.decode(char.skin_data) or nil,
            clothes = char.clothes_data and json.decode(char.clothes_data) or nil
        }
    end
    return nil
end)
