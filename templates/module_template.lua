--[[
    MODULE TEMPLATE - vAvA_core
    Copiez ce fichier pour créer un nouveau module facilement
    
    Instructions:
    1. Renommer le fichier: votre_module.lua
    2. Modifier MODULE_NAME
    3. Configurer MODULE_CONFIG
    4. Implémenter les fonctions dans IMPLEMENTATION
    4. Ajouter au fxmanifest: 'modules/votre_module/votre_module.lua'
]]

-- ═══════════════════════════════════════════════════════════════════════════
-- CONFIGURATION MODULE
-- ═══════════════════════════════════════════════════════════════════════════

local MODULE_NAME = 'example_module'  -- 🔴 MODIFIER ICI

local MODULE_CONFIG = {
    version = '1.0.0',
    author = 'Your Name',
    description = 'Description de votre module',
    
    -- Dépendances (autres modules requis)
    dependencies = {
        -- 'other_module_name'
    },
    
    -- Configuration du module
    config = {
        debug = false,
        
        -- Vos paramètres ici
        enabled = true,
        setting1 = 'value1',
        setting2 = 100,
        
        -- Exemple: configuration de positions
        locations = {
            {x = 0.0, y = 0.0, z = 0.0}
        }
    }
}

-- ═══════════════════════════════════════════════════════════════════════════
-- CRÉATION MODULE
-- ═══════════════════════════════════════════════════════════════════════════

local Module = vCore.CreateModule(MODULE_NAME, MODULE_CONFIG)

-- ═══════════════════════════════════════════════════════════════════════════
-- LIFECYCLE HOOKS
-- ═══════════════════════════════════════════════════════════════════════════

---Appelé au chargement du module
function Module.onLoad(self)
    self:Log('Chargement du module...')
    
    -- Initialisation ici
    
    self:Log('Module chargé avec succès!')
end

---Appelé au démarrage du module
function Module.onStart(self)
    self:Log('Démarrage du module...')
    
    -- Enregistrement events, commandes, callbacks...
    self:RegisterEvents()
    self:RegisterCommands()
    self:RegisterCallbacks()
    
    self:Log('Module démarré!')
end

---Appelé à l'arrêt du module
function Module.onStop(self)
    self:Log('Arrêt du module...')
    
    -- Nettoyage ici
end

if IsDuplicityVersion() then
    ---Appelé quand un joueur est chargé
    function Module.onPlayerLoaded(self, player)
        self:Debug('Joueur chargé:', player:GetName())
        
        -- Actions sur le joueur ici
    end
    
    ---Appelé quand un joueur se déconnecte
    function Module.onPlayerUnloaded(self, player)
        self:Debug('Joueur déconnecté:', player:GetName())
        
        -- Sauvegarde/nettoyage ici
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS
-- ═══════════════════════════════════════════════════════════════════════════

function Module:RegisterEvents()
    -- Exemple d'événement
    self:RegisterEvent(MODULE_NAME .. ':exampleEvent', function(source, data)
        self:Debug('Event reçu:', data)
        
        if IsDuplicityVersion() then
            local player = self:GetPlayer(source)
            if not player then return end
            
            -- Traitement serveur
            self:NotifySuccess(source, 'Action réussie!')
        else
            -- Traitement client
        end
    end)
    
    -- Écouter événements core
    if IsDuplicityVersion() then
        self:RegisterEvent(vCore.Events.PLAYER_LOADED, function(source)
            local player = self:GetPlayer(source)
            self:Debug('Joueur connecté:', player:GetName())
        end)
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES
-- ═══════════════════════════════════════════════════════════════════════════

function Module:RegisterCommands()
    if not IsDuplicityVersion() then return end
    
    -- Exemple commande admin
    self:RegisterCommand('examplecmd', {
        help = 'Description de la commande',
        params = {
            {name = 'param1', help = 'Description param1', required = true},
            {name = 'param2', help = 'Description param2', required = false}
        },
        minLevel = vCore.PermissionLevel.ADMIN,
        restricted = true
    }, function(source, args)
        local player = self:GetPlayer(source)
        if not player then return end
        
        local param1 = args[1]
        local param2 = args[2] or 'default'
        
        -- Validation
        local valid, err = vCore.Validation.IsString(param1, 1, 50)
        if not valid then
            self:NotifyError(source, err)
            return
        end
        
        -- Traitement
        self:Log('Commande exécutée par', player:GetName())
        self:NotifySuccess(source, 'Commande réussie!')
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS
-- ═══════════════════════════════════════════════════════════════════════════

function Module:RegisterCallbacks()
    if not IsDuplicityVersion() then return end
    
    -- Exemple callback
    self:RegisterCallback('getData', function(source, cb, param)
        local player = self:GetPlayer(source)
        if not player then
            cb(nil)
            return
        end
        
        -- Récupérer données
        local data = {
            name = player:GetName(),
            job = player:GetJob(),
            param = param
        }
        
        cb(data)
    end)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

---Exemple d'export public
---@param param1 any
---@return any
function Module:ExampleExport(param1)
    self:Debug('Export appelé:', param1)
    
    -- Votre code
    return param1
end

-- Enregistrer l'export
Module:RegisterExport('ExampleExport', function(param1)
    return Module:ExampleExport(param1)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS PRIVÉES
-- ═══════════════════════════════════════════════════════════════════════════

---Fonction privée locale
---@param data any
local function privateFunction(data)
    -- Code privé au module
    return data
end

-- ═══════════════════════════════════════════════════════════════════════════
-- IMPLÉMENTATION (Votre code ici)
-- ═══════════════════════════════════════════════════════════════════════════

if IsDuplicityVersion() then
    -- ═══════════════════════════════════════════════════════════════════════
    -- CODE SERVEUR
    -- ═══════════════════════════════════════════════════════════════════════
    
    ---Exemple fonction serveur
    ---@param source number
    ---@param data table
    function Module:ServerFunction(source, data)
        local player = self:GetPlayer(source)
        if not player then return end
        
        -- Vérifier permissions
        if not self:HasPermission(source, vCore.PermissionLevel.USER) then
            self:NotifyError(source, Lang('no_permission'))
            return
        end
        
        -- Valider données
        local valid, err = vCore.Validation.IsTable(data)
        if not valid then
            self:NotifyError(source, err)
            return
        end
        
        -- Traitement
        self:Debug('Traitement:', data)
        
        -- Base de données
        local result = self:Query('SELECT * FROM table WHERE id = ?', {data.id})
        
        -- Notifier joueur
        self:NotifySuccess(source, 'Opération réussie!')
        
        -- Logger
        self:LogDB('action', source, 'Action effectuée', data)
    end
    
    -- Exemple: Gestion argent
    function Module:GiveReward(source, amount)
        local player = self:GetPlayer(source)
        if not player then return false end
        
        player:AddMoney('cash', amount, MODULE_NAME .. ' reward')
        self:NotifySuccess(source, 'Vous avez reçu ' .. vCore.Utils.FormatMoney(amount))
        
        return true
    end
    
else
    -- ═══════════════════════════════════════════════════════════════════════
    -- CODE CLIENT
    -- ═══════════════════════════════════════════════════════════════════════
    
    ---Exemple fonction client
    function Module:ClientFunction()
        self:Debug('Fonction client appelée')
        
        -- Exemple: Menu
        local menuData = {
            title = 'Menu Example',
            subtitle = 'Sous-titre',
            elements = {
                {label = 'Option 1', value = 'opt1'},
                {label = 'Option 2', value = 'opt2'},
                {label = 'Option 3', value = 'opt3'}
            }
        }
        
        self:ShowMenu(-1, menuData)
    end
    
    ---Exemple: Marker loop
    function Module:StartMarkerLoop()
        Citizen.CreateThread(function()
            while self.enabled do
                local playerCoords = vCore.Helpers.GetPlayerCoords()
                
                for _, location in ipairs(self:GetConfig('locations', {})) do
                    local coords = vector3(location.x, location.y, location.z)
                    local distance = #(playerCoords - coords)
                    
                    if distance < 50.0 then
                        -- Afficher marker
                        DrawMarker(1, coords.x, coords.y, coords.z - 1.0, 0, 0, 0, 0, 0, 0, 1.0, 1.0, 1.0, 255, 0, 0, 200, false, true, 2, false, nil, nil, false)
                        
                        if distance < 2.0 then
                            -- Afficher texte d'aide
                            vCore.UI.ShowHelpText('Appuyez sur ~INPUT_CONTEXT~ pour interagir')
                            
                            if IsControlJustPressed(0, 38) then -- E
                                self:TriggerServerEvent(MODULE_NAME .. ':exampleEvent', {action = 'interact'})
                            end
                        end
                    end
                end
                
                Citizen.Wait(0)
            end
        end)
    end
    
    ---Exemple: Progress bar
    function Module:DoAction()
        self:ShowProgressBar(-1, 'Action en cours...', 5000, {
            canCancel = true,
            animation = {
                dict = 'mini@repair',
                name = 'fixing_a_player'
            },
            onComplete = function()
                self:TriggerServerEvent(MODULE_NAME .. ':actionComplete')
            end,
            onCancel = function()
                self:Debug('Action annulée')
            end
        })
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- CHARGEMENT MODULE
-- ═══════════════════════════════════════════════════════════════════════════

-- Charger le module
Module:Load()

-- Démarrer le module
Citizen.CreateThread(function()
    -- Attendre que vCore soit prêt
    while not vCore or not vCore.Ready do
        Citizen.Wait(100)
    end
    
    Module:Start()
    
    -- Code spécifique client
    if not IsDuplicityVersion() then
        -- Démarrer loops, threads, etc.
        -- Module:StartMarkerLoop()
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS NATIFS FIVEM (optionnel)
-- ═══════════════════════════════════════════════════════════════════════════

-- Permet d'appeler: exports.resource_name:FunctionName()
exports('GetModuleData', function()
    return {
        name = Module.name,
        version = Module.version,
        loaded = Module.loaded
    }
end)
