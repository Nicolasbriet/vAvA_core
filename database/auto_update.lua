--[[
    ╔═══════════════════════════════════════════════════════════════════════════╗
    ║                   vAvA_core - Auto Update System                          ║
    ║          Système de mise à jour automatique depuis GitHub                 ║
    ╚═══════════════════════════════════════════════════════════════════════════╝
]]

vCore = vCore or {}
vCore.AutoUpdate = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION
-- ═══════════════════════════════════════════════════════════════════════════

local CONFIG = {
    githubRepo = 'Nicolasbriet/vAvA_core',
    branch = 'main',
    checkInterval = 3600000,  -- Vérifier toutes les heures (ms)
    versionFile = 'version.json',
    autoUpdate = true,        -- Mise à jour automatique activée
    autoRestart = false,      -- Redémarrage automatique des ressources (désactivé par défaut)
    backupBeforeUpdate = true -- Créer une sauvegarde avant mise à jour
}

-- ═══════════════════════════════════════════════════════════════════════════
-- FICHIERS À PROTÉGER (ne jamais écraser)
-- ═══════════════════════════════════════════════════════════════════════════

local PROTECTED_FILES = {
    -- Fichiers de configuration utilisateur
    'config.lua',
    'config/config.lua',
    'shared/config.lua',
    
    -- Fichiers serveur
    'server.cfg',
    'server.cfg.example',
    
    -- Configurations spécifiques
    'config/economy.lua',
    'config/shops.lua',
    'config/garages.lua',
    'config/jobs.lua',
    'garages.json',
    'config_vehicles.json',
    
    -- Fichiers de connexion
    'mysql_connection.txt',
    
    -- Données utilisateur
    '*.json',  -- Pattern pour tous les JSON de config
}

local PROTECTED_PATTERNS = {
    'config/',      -- Tout le dossier config/
    'server%.cfg',  -- Tous les .cfg
    '%.example$',   -- Tous les .example
    '_config%.lua$' -- Tous les *_config.lua
}

-- ═══════════════════════════════════════════════════════════════════════════
-- VÉRIFIER SI UN FICHIER EST PROTÉGÉ
-- ═══════════════════════════════════════════════════════════════════════════

local function IsFileProtected(filePath)
    -- Normaliser le chemin
    filePath = filePath:gsub('\\', '/')
    local fileName = filePath:match('([^/]+)$') or filePath
    
    -- Vérifier les fichiers exacts
    for _, protectedFile in ipairs(PROTECTED_FILES) do
        if filePath:find(protectedFile, 1, true) or fileName == protectedFile then
            return true
        end
    end
    
    -- Vérifier les patterns
    for _, pattern in ipairs(PROTECTED_PATTERNS) do
        if filePath:match(pattern) or fileName:match(pattern) then
            return true
        end
    end
    
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MAPPING DES MODULES (modules/ → ressources séparées)
-- ═══════════════════════════════════════════════════════════════════════════

local MODULE_MAPPING = {
    ['loadingscreen'] = { resource = 'vAvA_loadingscreen', path = 'modules/loadingscreen' },
    ['creator'] = { resource = 'vAvA_creator', path = 'modules/creator' },
    ['economy'] = { resource = 'vAvA_economy', path = 'modules/economy' },
    ['inventory'] = { resource = 'vAvA_inventory', path = 'modules/inventory' },
    ['chat'] = { resource = 'vAvA_chat', path = 'modules/chat' },
    ['keys'] = { resource = 'vAvA_keys', path = 'modules/keys' },
    ['jobs'] = { resource = 'vAvA_jobs', path = 'modules/jobs' },
    ['concess'] = { resource = 'vAvA_concess', path = 'modules/concess' },
    ['garage'] = { resource = 'vAvA_garage', path = 'modules/garage' },
    ['jobshop'] = { resource = 'vAvA_jobshop', path = 'modules/jobshop' },
    ['persist'] = { resource = 'vAvA_persist', path = 'modules/persist' },
    ['sit'] = { resource = 'vAvA_sit', path = 'modules/sit' },
    ['testbench'] = { resource = 'vAvA_testbench', path = 'modules/testbench' }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- VERSIONS LOCALES (backup si GitHub inaccessible)
-- ═══════════════════════════════════════════════════════════════════════════

local LOCAL_VERSIONS = {
    ['vava_core'] = '1.0.0',
    ['economy'] = '1.2.0',
    ['creator'] = '1.0.0',
    ['garage'] = '1.0.0',
    ['inventory'] = '1.0.0',
    ['chat'] = '1.0.0',
    ['jobs'] = '1.0.0',
    ['keys'] = '1.0.0',
    ['concess'] = '1.0.0',
    ['jobshop'] = '1.0.0',
    ['persist'] = '1.0.0',
    ['sit'] = '1.0.0',
    ['loadingscreen'] = '1.0.0',
    ['testbench'] = '1.0.0'
}

-- ═══════════════════════════════════════════════════════════════════════════
-- MISES À JOUR LOCALES (si GitHub inaccessible)
-- ═══════════════════════════════════════════════════════════════════════════

local LOCAL_UPDATES = {
    -- Economy v1.2.0 - Ajout du système de monitoring
    {
        module = 'economy',
        version = '1.2.0',
        description = 'Ajout du système de monitoring et rapports économiques',
        queries = {
            [[
                CREATE TABLE IF NOT EXISTS `economy_reports` (
                    `id` INT(11) NOT NULL AUTO_INCREMENT,
                    `report_type` ENUM('hourly', 'daily', 'weekly', 'monthly', 'custom') NOT NULL DEFAULT 'hourly',
                    `report_data` JSON NOT NULL,
                    `generated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
                    `generated_by` VARCHAR(100) DEFAULT 'system',
                    PRIMARY KEY (`id`),
                    KEY `report_type` (`report_type`),
                    KEY `generated_at` (`generated_at`)
                ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
            ]],
            [[
                ALTER TABLE `economy_logs` 
                MODIFY COLUMN `source` ENUM('auto', 'admin', 'system', 'monitoring') NOT NULL DEFAULT 'auto';
            ]]
        },
        files = {
            'modules/economy/server/auto_adjust.lua',
            'modules/economy/config/economy.lua'
        },
        needsRestart = true
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- UTILITAIRES HTTP
-- ═══════════════════════════════════════════════════════════════════════════

local function HTTPRequest(url, method, data, headers, callback)
    method = method or 'GET'
    data = data or ''
    headers = headers or {}
    
    PerformHttpRequest(url, function(statusCode, responseData, responseHeaders)
        if callback then
            callback(statusCode, responseData, responseHeaders)
        end
    end, method, data, headers)
end

local function GetGitHubRawURL(file)
    return string.format(
        'https://raw.githubusercontent.com/%s/%s/%s',
        CONFIG.githubRepo,
        CONFIG.branch,
        file
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- RÉCUPÉRER LES VERSIONS DEPUIS GITHUB
-- ═══════════════════════════════════════════════════════════════════════════

function vCore.AutoUpdate.FetchGitHubVersions(callback)
    local url = GetGitHubRawURL(CONFIG.versionFile)
    
    print('^3[AUTO UPDATE]^0 Récupération des versions depuis GitHub...')
    print('^3[AUTO UPDATE]^0 URL: ' .. url)
    
    HTTPRequest(url, 'GET', '', {}, function(statusCode, data)
        if statusCode == 200 then
            local success, versions = pcall(json.decode, data)
            if success and versions then
                print('^2[AUTO UPDATE]^0 Versions GitHub récupérées avec succès')
                callback(true, versions)
            else
                print('^1[AUTO UPDATE ERROR]^0 Erreur de parsing du fichier version.json')
                callback(false, nil)
            end
        else
            print('^1[AUTO UPDATE ERROR]^0 GitHub inaccessible (HTTP ' .. statusCode .. ')')
            callback(false, nil)
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VÉRIFIER LA VERSION D'UN MODULE
-- ═══════════════════════════════════════════════════════════════════════════

function vCore.AutoUpdate.GetInstalledVersion(moduleName)
    local result = MySQL.query.await([[
        SELECT version FROM vcore_module_versions WHERE module_name = ?
    ]], { moduleName })
    
    if result and result[1] then
        return result[1].version
    end
    return '0.0.0'
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ENREGISTRER LA VERSION D'UN MODULE
-- ═══════════════════════════════════════════════════════════════════════════

function vCore.AutoUpdate.SetVersion(moduleName, version)
    MySQL.insert([[
        INSERT INTO vcore_module_versions (module_name, version, updated_at)
        VALUES (?, ?, NOW())
        ON DUPLICATE KEY UPDATE 
            version = VALUES(version),
            updated_at = NOW()
    ]], { moduleName, version })
end

-- ═══════════════════════════════════════════════════════════════════════════
-- COMPARER LES VERSIONS (semantic versioning)
-- ═══════════════════════════════════════════════════════════════════════════

function vCore.AutoUpdate.CompareVersions(v1, v2)
    -- Retourne: -1 si v1 < v2, 0 si v1 == v2, 1 si v1 > v2
    local function parseVersion(version)
        local major, minor, patch = version:match("(%d+)%.(%d+)%.(%d+)")
        return {
            major = tonumber(major) or 0,
            minor = tonumber(minor) or 0,
            patch = tonumber(patch) or 0
        }
    end
    
    local ver1 = parseVersion(v1)
    local ver2 = parseVersion(v2)
    
    if ver1.major ~= ver2.major then
        return ver1.major < ver2.major and -1 or 1
    end
    if ver1.minor ~= ver2.minor then
        return ver1.minor < ver2.minor and -1 or 1
    end
    if ver1.patch ~= ver2.patch then
        return ver1.patch < ver2.patch and -1 or 1
    end
    
    return 0
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TÉLÉCHARGER UN FICHIER DEPUIS GITHUB
-- ═══════════════════════════════════════════════════════════════════════════

function vCore.AutoUpdate.DownloadFile(githubPath, localPath, callback)
    -- Vérifier si le fichier est protégé
    if IsFileProtected(githubPath) then
        print('^3[AUTO UPDATE]^0 Fichier protégé ignoré: ' .. githubPath)
        
        -- Télécharger comme .example si c'est un fichier config
        if githubPath:match('config') or githubPath:match('%.lua$') then
            local examplePath = localPath .. '.example'
            local url = GetGitHubRawURL(githubPath)
            
            HTTPRequest(url, 'GET', '', {}, function(statusCode, data)
                if statusCode == 200 then
                    local file = io.open(examplePath, 'w')
                    if file then
                        file:write(data)
                        file:close()
                        print('^2[AUTO UPDATE]^0 Fichier .example créé: ' .. examplePath)
                    end
                end
                if callback then callback(true) end
            end)
        else
            if callback then callback(true) end
        end
        return
    end
    
    -- Vérifier si le fichier existe déjà (pour les configs)
    if localPath:match('config') then
        local existingFile = io.open(localPath, 'r')
        if existingFile then
            existingFile:close()
            print('^3[AUTO UPDATE]^0 Config existante conservée: ' .. localPath)
            
            -- Créer une version .new pour comparaison
            local newPath = localPath .. '.new'
            local url = GetGitHubRawURL(githubPath)
            
            HTTPRequest(url, 'GET', '', {}, function(statusCode, data)
                if statusCode == 200 then
                    local file = io.open(newPath, 'w')
                    if file then
                        file:write(data)
                        file:close()
                        print('^2[AUTO UPDATE]^0 Nouvelle version disponible: ' .. newPath)
                        print('^3[AUTO UPDATE]^0 Comparez et fusionnez manuellement vos changements')
                    end
                end
                if callback then callback(true) end
            end)
            return
        end
    end
    
    -- Télécharger normalement
    local url = GetGitHubRawURL(githubPath)
    
    HTTPRequest(url, 'GET', '', {}, function(statusCode, data)
        if statusCode == 200 then
            local file = io.open(localPath, 'w')
            if file then
                file:write(data)
                file:close()
                if callback then callback(true) end
            else
                print('^1[AUTO UPDATE ERROR]^0 Impossible d\'écrire: ' .. localPath)
                if callback then callback(false) end
            end
        else
            print('^1[AUTO UPDATE ERROR]^0 Échec téléchargement: ' .. githubPath .. ' (HTTP ' .. statusCode .. ')')
            if callback then callback(false) end
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- REDÉMARRER UNE RESSOURCE
-- ═══════════════════════════════════════════════════════════════════════════

function vCore.AutoUpdate.RestartResource(resourceName)
    if GetResourceState(resourceName) == 'started' then
        print('^3[AUTO UPDATE]^0 Redémarrage de la ressource: ' .. resourceName)
        ExecuteCommand('restart ' .. resourceName)
        return true
    end
    return false
end

-- ═══════════════════════════════════════════════════════════════════════════
-- RÉINSTALLER UN MODULE (comme txAdmin recipe)
-- ═══════════════════════════════════════════════════════════════════════════

function vCore.AutoUpdate.ReinstallModule(moduleName, update)
    local mapping = MODULE_MAPPING[moduleName]
    if not mapping then
        print('^1[AUTO UPDATE ERROR]^0 Module inconnu: ' .. moduleName)
        return false
    end
    
    local resourceName = mapping.resource
    local resourcePath = GetResourcePath(resourceName)
    
    if not resourcePath then
        print('^1[AUTO UPDATE ERROR]^0 Ressource non trouvée: ' .. resourceName)
        return false
    end
    
    print('^3[AUTO UPDATE]^0 Réinstallation du module: ' .. moduleName .. ' → ' .. resourceName)
    
    -- Filtrer les fichiers protégés
    local filesToDownload = update.files or {}
    local filteredFiles = {}
    local protectedCount = 0
    
    for _, file in ipairs(filesToDownload) do
        if not IsFileProtected(file) then
            table.insert(filteredFiles, file)
        else
            protectedCount = protectedCount + 1
            print('^3[AUTO UPDATE]^0 Fichier protégé ignoré: ' .. file)
        end
    end
    
    if protectedCount > 0 then
        print('^3[AUTO UPDATE]^0 ' .. protectedCount .. ' fichier(s) de configuration préservé(s)')
    end
    
    -- Télécharger les fichiers non protégés
    local downloadCount = 0
    local downloadFailed = 0
    
    for _, file in ipairs(filteredFiles) do
        local localPath = resourcePath:gsub('\\', '/') .. '/' .. file:gsub(mapping.path .. '/', '')
        
        vCore.AutoUpdate.DownloadFile(file, localPath, function(success)
            if success then
                downloadCount = downloadCount + 1
                print('^2[AUTO UPDATE]^0 Téléchargé: ' .. file)
            else
                downloadFailed = downloadFailed + 1
            end
        end)
        
        Wait(100) -- Éviter de surcharger GitHub
    end
    
    if downloadFailed == 0 then
        print('^2[AUTO UPDATE]^0 Module ' .. moduleName .. ' mis à jour avec succès')
        print('^3[AUTO UPDATE]^0 Fichiers mis à jour: ' .. downloadCount .. ' | Fichiers préservés: ' .. protectedCount)
        
        -- Redémarrer la ressource si nécessaire
        if update.needsRestart and CONFIG.autoRestart then
            Wait(500)
            vCore.AutoUpdate.RestartResource(resourceName)
        end
        
        return true
    else
        print('^1[AUTO UPDATE ERROR]^0 Échec partiel: ' .. downloadFailed .. ' fichier(s) non téléchargé(s)')
        return false
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXÉCUTER UNE MISE À JOUR
-- ═══════════════════════════════════════════════════════════════════════════

function vCore.AutoUpdate.ApplyUpdate(update)
    print('^3[AUTO UPDATE]^0 Application de la mise à jour: ' .. update.module .. ' v' .. update.version)
    print('^3[AUTO UPDATE]^0 Description: ' .. update.description)
    
    local success = true
    local errorMsg = nil
    
    -- Exécuter les requêtes SQL
    if update.queries then
        for i, query in ipairs(update.queries) do
            local ok, err = pcall(function()
                MySQL.query.await(query)
            end)
            
            if not ok then
                success = false
                errorMsg = 'Erreur SQL requête #' .. i .. ': ' .. tostring(err)
                print('^1[AUTO UPDATE ERROR]^0 ' .. errorMsg)
                break
            else
                print('^2[AUTO UPDATE]^0 Requête #' .. i .. ' exécutée avec succès')
            end
        end
    end
    
    -- Enregistrer la nouvelle version
    if success then
        vCore.AutoUpdate.SetVersion(update.module, update.version)
        print('^2[AUTO UPDATE]^0 Mise à jour ' .. update.module .. ' v' .. update.version .. ' terminée avec succès!')
        
        -- Logger dans economy_logs si c'est une mise à jour economy
        if update.module == 'economy' then
            MySQL.insert([[
                INSERT INTO economy_logs (log_type, item_or_job, reason, source, timestamp)
                VALUES ('recalculate', 'system_update', ?, 'system', NOW())
            ]], { 'Mise à jour automatique v' .. update.version .. ': ' .. update.description })
        end
    else
        print('^1[AUTO UPDATE ERROR]^0 Échec de la mise à jour ' .. update.module .. ' v' .. update.version)
    end
    
    return success, errorMsg
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VÉRIFIER ET APPLIQUER TOUTES LES MISES À JOUR
-- ═══════════════════════════════════════════════════════════════════════════

function vCore.AutoUpdate.CheckAndApply()
    print('^5═══════════════════════════════════════════════════════════^0')
    print('^5[AUTO UPDATE]^0 Vérification des mises à jour des modules...')
    print('^5═══════════════════════════════════════════════════════════^0')
    
    -- Créer la table de versions si elle n'existe pas
    MySQL.query.await([[
        CREATE TABLE IF NOT EXISTS `vcore_module_versions` (
            `id` INT(11) NOT NULL AUTO_INCREMENT,
            `module_name` VARCHAR(100) NOT NULL,
            `version` VARCHAR(20) NOT NULL,
            `updated_at` TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP ON UPDATE CURRENT_TIMESTAMP,
            PRIMARY KEY (`id`),
            UNIQUE KEY `module_name` (`module_name`)
        ) ENGINE=InnoDB DEFAULT CHARSET=utf8mb4 COLLATE=utf8mb4_unicode_ci;
    ]])
    
    -- Essayer de récupérer les versions depuis GitHub
    vCore.AutoUpdate.FetchGitHubVersions(function(success, githubVersions)
        local versions = success and githubVersions or LOCAL_VERSIONS
        local updates = success and (githubVersions.updates or LOCAL_UPDATES) or LOCAL_UPDATES
        local source = success and 'GitHub' or 'Local'
        
        print('^3[AUTO UPDATE]^0 Source: ' .. source)
        
        local updatesApplied = 0
        local updatesFailed = 0
        local modulesReinstalled = 0
        
        -- Parcourir toutes les mises à jour disponibles
        for _, update in ipairs(updates) do
            -- Valider que update.version est une string
            if not update.module or not update.version or type(update.version) ~= 'string' then
                print('^1[AUTO UPDATE ERROR]^0 Update invalide détecté, ignoré')
                goto continue
            end
            
            local installedVersion = vCore.AutoUpdate.GetInstalledVersion(update.module)
            local comparison = vCore.AutoUpdate.CompareVersions(installedVersion, update.version)
            
            if comparison < 0 then
                -- Version installée plus ancienne
                print('^3[AUTO UPDATE]^0 Module: ' .. update.module)
                print('^3[AUTO UPDATE]^0 Version installée: v' .. installedVersion .. ' → Nouvelle version: v' .. update.version)
                
                local success, err = vCore.AutoUpdate.ApplyUpdate(update)
                
                if success then
                    updatesApplied = updatesApplied + 1
                    
                    -- Réinstaller les fichiers du module si disponible sur GitHub
                    if success and source == 'GitHub' and update.files then
                        if vCore.AutoUpdate.ReinstallModule(update.module, update) then
                            modulesReinstalled = modulesReinstalled + 1
                        end
                    end
                else
                    updatesFailed = updatesFailed + 1
                end
                
                Wait(100)
            end
            
            ::continue::
        end
        
        -- Enregistrer les versions pour tous les modules
        for moduleName, version in pairs(versions) do
            -- Ignorer les entrées qui ne sont pas des versions (metadata, updates, etc.)
            if moduleName ~= 'metadata' and moduleName ~= 'updates' and type(version) == 'string' then
                local installedVersion = vCore.AutoUpdate.GetInstalledVersion(moduleName)
                if installedVersion == '0.0.0' then
                    vCore.AutoUpdate.SetVersion(moduleName, version)
                    print('^2[AUTO UPDATE]^0 Module ' .. moduleName .. ' enregistré: v' .. version)
                end
            end
        end
        
        -- Résumé
        print('^5═══════════════════════════════════════════════════════════^0')
        if updatesApplied > 0 then
            print('^2[AUTO UPDATE]^0 ' .. updatesApplied .. ' mise(s) à jour appliquée(s) avec succès')
        end
        if modulesReinstalled > 0 then
            print('^2[AUTO UPDATE]^0 ' .. modulesReinstalled .. ' module(s) réinstallé(s) depuis GitHub')
        end
        if updatesFailed > 0 then
            print('^1[AUTO UPDATE]^0 ' .. updatesFailed .. ' mise(s) à jour échouée(s)')
        end
        if updatesApplied == 0 and updatesFailed == 0 then
            print('^2[AUTO UPDATE]^0 Tous les modules sont à jour!')
        end
        print('^5═══════════════════════════════════════════════════════════^0')
        
        -- Programmer la prochaine vérification
        if CONFIG.autoUpdate then
            vCore.AutoUpdate.ScheduleNextCheck()
        end
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- PROGRAMMER LA PROCHAINE VÉRIFICATION
-- ═══════════════════════════════════════════════════════════════════════════

function vCore.AutoUpdate.ScheduleNextCheck()
    SetTimeout(CONFIG.checkInterval, function()
        print('^3[AUTO UPDATE]^0 Vérification périodique des mises à jour...')
        vCore.AutoUpdate.CheckAndApply()
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDE ADMIN - FORCER UNE MISE À JOUR
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('forceupdate', function(source, args)
    if source ~= 0 then
        local xPlayer = vCore.GetPlayerFromId(source)
        if not xPlayer or xPlayer.getGroup() < 4 then
            return print('^1[AUTO UPDATE]^0 Permission refusée')
        end
    end
    
    print('^3[AUTO UPDATE]^0 Mise à jour forcée par admin...')
    vCore.AutoUpdate.CheckAndApply()
end, true)

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDE ADMIN - AFFICHER LES VERSIONS
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('versions', function(source, args)
    if source ~= 0 then
        local xPlayer = vCore.GetPlayerFromId(source)
        if not xPlayer or xPlayer.getGroup() < 3 then
            return
        end
    end
    
    print('^5═══════════════════════════════════════════════════════════^0')
    print('^5[VERSIONS DES MODULES]^0')
    print('^5═══════════════════════════════════════════════════════════^0')
    
    -- Essayer de récupérer depuis GitHub
    vCore.AutoUpdate.FetchGitHubVersions(function(success, githubVersions)
        local versions = success and githubVersions or LOCAL_VERSIONS
        
        for moduleName, expectedVersion in pairs(versions) do
            local installedVersion = vCore.AutoUpdate.GetInstalledVersion(moduleName)
            local comparison = vCore.AutoUpdate.CompareVersions(installedVersion, expectedVersion)
            local status
            
            if comparison < 0 then
                status = '^3[UPDATE AVAILABLE]^0'
            elseif comparison == 0 then
                status = '^2[OK]^0'
            else
                status = '^1[NEWER]^0'
            end
            
            print(string.format('%-20s %s v%-10s (dernière: v%s)', moduleName, status, installedVersion, expectedVersion))
            
            -- Afficher la ressource associée
            local resourceName = MODULE_MAPPING[moduleName] and MODULE_MAPPING[moduleName].resource
            if resourceName then
                local state = GetResourceState(resourceName)
                local stateColor = state == 'started' and '^2' or '^1'
                print(string.format('  └─ Ressource: %s%s^0 (%s)', stateColor, resourceName, state))
            end
        end
        
        print('^5═══════════════════════════════════════════════════════════^0')
    end)
end, true)

RegisterCommand('checkupdates', function(source, args)
    if source ~= 0 then
        local xPlayer = vCore.GetPlayerFromId(source)
        if not xPlayer or xPlayer.getGroup() < 3 then
            return print('^1[AUTO UPDATE]^0 Permission refusée')
        end
    end
    
    print('^3[AUTO UPDATE]^0 Vérification manuelle des mises à jour...')
    vCore.AutoUpdate.CheckAndApply()
end, true)

RegisterCommand('reinstallmodule', function(source, args)
    if source ~= 0 then
        local xPlayer = vCore.GetPlayerFromId(source)
        if not xPlayer or xPlayer.getGroup() < 4 then
            return print('^1[AUTO UPDATE]^0 Permission refusée (admin niveau 4 requis)')
        end
    end
    
    local moduleName = args[1]
    if not moduleName then
        return print('^1[AUTO UPDATE]^0 Usage: /reinstallmodule <module>')
    end
    
    local mapping = MODULE_MAPPING[moduleName]
    if not mapping then
        return print('^1[AUTO UPDATE]^0 Module inconnu: ' .. moduleName)
    end
    
    -- Créer une mise à jour fictive pour réinstaller
    local update = {
        module = moduleName,
        version = LOCAL_VERSIONS[moduleName] or '1.0.0',
        files = {},  -- Tous les fichiers du module
        needsRestart = true
    }
    
    print('^3[AUTO UPDATE]^0 Réinstallation forcée du module: ' .. moduleName)
    vCore.AutoUpdate.ReinstallModule(moduleName, update)
end, true)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORT
-- ═══════════════════════════════════════════════════════════════════════════

exports('GetModuleVersion', function(moduleName)
    return vCore.AutoUpdate.GetInstalledVersion(moduleName)
end)

exports('CheckUpdates', function()
    return vCore.AutoUpdate.CheckAndApply()
end)

return vCore.AutoUpdate
