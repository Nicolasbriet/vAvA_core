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
-- FONCTIONS UTILITAIRES
-- ═══════════════════════════════════════════════════════════════════════════

local function GetPlayerIdentifier(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in pairs(identifiers) do
        if string.find(id, "license:") then
            return id
        end
    end
    return nil
end

local function GetPlayerLicense(source)
    local identifiers = GetPlayerIdentifiers(source)
    for _, id in pairs(identifiers) do
        if string.find(id, "license:") then
            return string.gsub(id, "license:", "")
        end
    end
    return nil
end

-- ═══════════════════════════════════════════════════════════════════════════
-- BASE DE DONNÉES
-- ═══════════════════════════════════════════════════════════════════════════

local function CreateTables()
    -- Ajouter les colonnes manquantes à la table characters si elles n'existent pas
    MySQL.Async.execute([[
        ALTER TABLE `characters` 
        ADD COLUMN IF NOT EXISTS `nationality` VARCHAR(50) DEFAULT 'Française' AFTER `gender`,
        ADD COLUMN IF NOT EXISTS `story` TEXT DEFAULT NULL AFTER `nationality`,
        ADD COLUMN IF NOT EXISTS `skin_data` LONGTEXT DEFAULT NULL AFTER `story`,
        ADD COLUMN IF NOT EXISTS `clothes_data` LONGTEXT DEFAULT NULL AFTER `skin_data`;
    ]], {}, function(success)
        if success then
            print('^2[vAvA Creator]^0 Colonnes créateur vérifiées/ajoutées dans characters')
        else
            -- Si ADD COLUMN IF NOT EXISTS n'est pas supporté, essayer individuellement
            MySQL.Async.execute([[
                SELECT COUNT(*) as col_exists 
                FROM information_schema.COLUMNS 
                WHERE TABLE_SCHEMA = DATABASE() 
                AND TABLE_NAME = 'characters' 
                AND COLUMN_NAME = 'nationality'
            ]], {}, function(result)
                if result and result[1] and result[1].col_exists == 0 then
                    MySQL.Async.execute("ALTER TABLE `characters` ADD COLUMN `nationality` VARCHAR(50) DEFAULT 'Française' AFTER `gender`", {})
                end
            end)
            
            MySQL.Async.execute([[
                SELECT COUNT(*) as col_exists 
                FROM information_schema.COLUMNS 
                WHERE TABLE_SCHEMA = DATABASE() 
                AND TABLE_NAME = 'characters' 
                AND COLUMN_NAME = 'story'
            ]], {}, function(result)
                if result and result[1] and result[1].col_exists == 0 then
                    MySQL.Async.execute("ALTER TABLE `characters` ADD COLUMN `story` TEXT DEFAULT NULL AFTER `nationality`", {})
                end
            end)
            
            MySQL.Async.execute([[
                SELECT COUNT(*) as col_exists 
                FROM information_schema.COLUMNS 
                WHERE TABLE_SCHEMA = DATABASE() 
                AND TABLE_NAME = 'characters' 
                AND COLUMN_NAME = 'skin_data'
            ]], {}, function(result)
                if result and result[1] and result[1].col_exists == 0 then
                    MySQL.Async.execute("ALTER TABLE `characters` ADD COLUMN `skin_data` LONGTEXT DEFAULT NULL AFTER `story`", {})
                end
            end)
            
            MySQL.Async.execute([[
                SELECT COUNT(*) as col_exists 
                FROM information_schema.COLUMNS 
                WHERE TABLE_SCHEMA = DATABASE() 
                AND TABLE_NAME = 'characters' 
                AND COLUMN_NAME = 'clothes_data'
            ]], {}, function(result)
                if result and result[1] and result[1].col_exists == 0 then
                    MySQL.Async.execute("ALTER TABLE `characters` ADD COLUMN `clothes_data` LONGTEXT DEFAULT NULL AFTER `skin_data`", {})
                    print('^2[vAvA Creator]^0 Colonnes créateur ajoutées à la table characters')
                end
            end)
        end
    end)
end

-- Créer les tables au démarrage
CreateThread(function()
    Wait(2000) -- Attendre que oxmysql soit prêt
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

-- Vérifier combien de personnages le joueur a
vCore.RegisterServerCallback('vava_creator:checkSlot', function(source, cb, player, slot)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        cb({ available = false })
        return
    end
    
    MySQL.Async.fetchScalar([[
        SELECT COUNT(*) FROM characters 
        WHERE identifier = ?
    ]], { identifier }, function(count)
        cb({ available = count < Config.Creator.MaxCharacters })
    end)
end)

-- Créer un nouveau personnage
vCore.RegisterServerCallback('vava_creator:createCharacter', function(source, cb, player, data)
    local identifier = GetPlayerIdentifier(source)
    if not identifier then
        cb({ success = false, error = 'Identifier introuvable' })
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
    
    -- Vérifier le nombre de personnages existants
    MySQL.Async.fetchScalar([[
        SELECT COUNT(*) FROM characters 
        WHERE identifier = ?
    ]], { identifier }, function(count)
        if count >= Config.Creator.MaxCharacters then
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
            (identifier, firstname, lastname, dob, gender, nationality, story, skin_data, clothes_data, position, money, job, last_played)
            VALUES (?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, ?, NOW())
        ]], {
            identifier,
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
                if vCore.Log then
                    vCore.Log('character', playerLicense, string.format(
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

-- Charger un personnage (callback obsolète - utiliser vCore:loadPlayer à la place)
-- Ce callback est gardé pour compatibilité mais redirige vers le système core
vCore.RegisterServerCallback('vava_creator:loadCharacter', function(source, cb, player, charId)
    local license = GetPlayerLicense(source)
    if not license then
        cb({ success = false, error = 'License introuvable' })
        return
    end
    
    -- Utiliser la table characters (correcte) au lieu de vava_characters
    MySQL.Async.fetchAll([[
        SELECT * FROM characters 
        WHERE id = ? AND identifier = ?
    ]], { charId, license }, function(results)
        if #results == 0 then
            cb({ success = false, error = 'Personnage introuvable' })
            return
        end
        
        local char = results[1]
        
        -- Mettre à jour last_played
        MySQL.Async.execute([[
            UPDATE characters SET last_played = NOW() WHERE id = ?
        ]], { charId })
        
        -- Construire les données du personnage
        local characterData = {
            id = char.id,
            citizenid = char.id, -- Pour compatibilité
            license = char.identifier,
            slot = char.id,
            firstname = char.firstname,
            lastname = char.lastname,
            fullname = char.firstname .. ' ' .. char.lastname,
            age = char.dob, -- Calculer l'âge depuis dob si nécessaire
            gender = char.gender,
            nationality = 'Américain',
            story = '',
            skin = char.skin_data and json.decode(char.skin_data) or nil,
            clothes = char.clothes_data and json.decode(char.clothes_data) or nil,
            position = char.position and json.decode(char.position) or nil,
            money = char.money and json.decode(char.money) or { cash = 0, bank = 0 },
            job = char.job and json.decode(char.job) or { name = 'unemployed', label = 'Chômeur', grade = 0 },
            gang = char.gang and json.decode(char.gang) or nil,
            metadata = char.metadata and json.decode(char.metadata) or {},
            inventory = char.inventory and json.decode(char.inventory) or {}
        }
        
        -- Charger via le système core (plutôt que d'enregistrer manuellement)
        TriggerEvent('vCore:loadPlayer', source, char.id)
        
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
            if vCore.Log then
                vCore.Log('character', playerLicense, string.format(
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
