-- ============================================
-- vAvA Target - Client API
-- Exports publiques pour autres modules
-- ============================================

-- Tables globales pour stocker les targets
registeredEntities = {}
registeredModels = {}
registeredZones = {}
registeredBones = {}

local nextId = 1

-- ============================================
-- GÉNÉRATION ID UNIQUE
-- ============================================

local function GenerateId()
    local id = 'target_' .. nextId
    nextId = nextId + 1
    return id
end

-- ============================================
-- ADD TARGET ENTITY
-- ============================================

function AddTargetEntity(entity, options)
    if not DoesEntityExist(entity) then
        print('[vAvA Target] Entity does not exist')
        return nil
    end
    
    if not options or type(options) ~= 'table' then
        print('[vAvA Target] Invalid options')
        return nil
    end
    
    local id = GenerateId()
    
    registeredEntities[entity] = options
    
    if TargetConfig.Debug then
        print(string.format('[vAvA Target] Added target to entity %s (ID: %s)', entity, id))
    end
    
    return id
end

-- ============================================
-- ADD TARGET MODEL
-- ============================================

function AddTargetModel(models, options)
    if not options or type(options) ~= 'table' then
        print('[vAvA Target] Invalid options')
        return nil
    end
    
    -- Convertir en table si c'est un seul modèle
    if type(models) ~= 'table' then
        models = {models}
    end
    
    local ids = {}
    
    for _, model in ipairs(models) do
        -- Convertir en hash si c'est un string
        local modelHash = type(model) == 'string' and GetHashKey(model) or model
        
        local id = GenerateId()
        registeredModels[modelHash] = options
        
        table.insert(ids, id)
        
        if TargetConfig.Debug then
            print(string.format('[vAvA Target] Added target to model %s (Hash: %s, ID: %s)', model, modelHash, id))
        end
    end
    
    return ids
end

-- ============================================
-- ADD TARGET ZONE
-- ============================================

function AddTargetZone(zoneData, options)
    if not zoneData or type(zoneData) ~= 'table' then
        print('[vAvA Target] Invalid zone data')
        return nil
    end
    
    if not zoneData.name or not zoneData.type or not zoneData.coords then
        print('[vAvA Target] Zone must have name, type, and coords')
        return nil
    end
    
    if not options or type(options) ~= 'table' then
        print('[vAvA Target] Invalid options')
        return nil
    end
    
    local id = GenerateId()
    
    local zone = {
        id = id,
        name = zoneData.name,
        type = zoneData.type,
        coords = zoneData.coords,
        options = options,
        debug = zoneData.debug or false
    }
    
    -- Ajouter propriétés spécifiques au type
    if zoneData.type == 'sphere' then
        zone.radius = zoneData.radius or TargetConfig.ZoneDistance
        
    elseif zoneData.type == 'box' then
        zone.size = zoneData.size or vector3(2.0, 2.0, 2.0)
        zone.heading = zoneData.heading or 0.0
        
    elseif zoneData.type == 'cylinder' then
        zone.radius = zoneData.radius or TargetConfig.ZoneDistance
        zone.height = zoneData.height or 2.0
        
    elseif zoneData.type == 'poly' then
        zone.points = zoneData.points or {}
        zone.minZ = zoneData.minZ or -1000.0
        zone.maxZ = zoneData.maxZ or 1000.0
    end
    
    table.insert(registeredZones, zone)
    
    if TargetConfig.Debug then
        print(string.format('[vAvA Target] Added zone %s (Type: %s, ID: %s)', zone.name, zone.type, id))
    end
    
    return id
end

-- ============================================
-- ADD TARGET BONE
-- ============================================

function AddTargetBone(bones, options)
    if not bones or type(bones) ~= 'table' then
        print('[vAvA Target] Invalid bones')
        return nil
    end
    
    if not options or type(options) ~= 'table' then
        print('[vAvA Target] Invalid options')
        return nil
    end
    
    local id = GenerateId()
    
    table.insert(registeredBones, {
        id = id,
        bones = bones,
        options = options
    })
    
    if TargetConfig.Debug then
        print(string.format('[vAvA Target] Added target to bones (ID: %s)', id))
    end
    
    return id
end

-- ============================================
-- REMOVE TARGET
-- ============================================

function RemoveTarget(id)
    if not id then
        return false
    end
    
    -- Chercher dans les zones
    for i, zone in ipairs(registeredZones) do
        if zone.id == id then
            table.remove(registeredZones, i)
            
            if TargetConfig.Debug then
                print(string.format('[vAvA Target] Removed zone %s', id))
            end
            
            return true
        end
    end
    
    -- Chercher dans les bones
    for i, bone in ipairs(registeredBones) do
        if bone.id == id then
            table.remove(registeredBones, i)
            
            if TargetConfig.Debug then
                print(string.format('[vAvA Target] Removed bone %s', id))
            end
            
            return true
        end
    end
    
    if TargetConfig.Debug then
        print(string.format('[vAvA Target] Target %s not found', id))
    end
    
    return false
end

-- ============================================
-- REMOVE TARGET MODEL
-- ============================================

function RemoveTargetModel(models)
    if type(models) ~= 'table' then
        models = {models}
    end
    
    local removed = 0
    
    for _, model in ipairs(models) do
        local modelHash = type(model) == 'string' and GetHashKey(model) or model
        
        if registeredModels[modelHash] then
            registeredModels[modelHash] = nil
            removed = removed + 1
        end
    end
    
    if TargetConfig.Debug then
        print(string.format('[vAvA Target] Removed %d model(s)', removed))
    end
    
    return removed > 0
end

-- ============================================
-- REMOVE TARGET ZONE
-- ============================================

function RemoveTargetZone(zoneName)
    for i, zone in ipairs(registeredZones) do
        if zone.name == zoneName then
            table.remove(registeredZones, i)
            
            if TargetConfig.Debug then
                print(string.format('[vAvA Target] Removed zone %s', zoneName))
            end
            
            return true
        end
    end
    
    return false
end

-- ============================================
-- REMOVE TARGET BONE
-- ============================================

function RemoveTargetBone(boneNames)
    if type(boneNames) ~= 'table' then
        boneNames = {boneNames}
    end
    
    local removed = 0
    
    for i = #registeredBones, 1, -1 do
        local boneGroup = registeredBones[i]
        
        for _, boneName in ipairs(boneNames) do
            for _, registeredBone in ipairs(boneGroup.bones) do
                if registeredBone == boneName then
                    table.remove(registeredBones, i)
                    removed = removed + 1
                    break
                end
            end
        end
    end
    
    if TargetConfig.Debug then
        print(string.format('[vAvA Target] Removed %d bone(s)', removed))
    end
    
    return removed > 0
end

-- ============================================
-- DISABLE TARGET
-- ============================================

function DisableTarget(toggle)
    TriggerEvent('vava_target:toggle', not toggle)
    
    if TargetConfig.Debug then
        print(string.format('[vAvA Target] Target system %s', toggle and 'disabled' or 'enabled'))
    end
end

-- ============================================
-- IS TARGET ACTIVE
-- ============================================

function IsTargetActive()
    return isTargetActive
end

-- ============================================
-- GET NEARBY TARGETS
-- ============================================

function GetNearbyTargets(distance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    distance = distance or TargetConfig.MaxDistance
    
    local nearbyTargets = {
        entities = {},
        zones = {}
    }
    
    -- Entités
    local entities = GetNearbyEntities(playerCoords, distance)
    
    for _, entity in ipairs(entities) do
        local options = GetOptionsForEntity(entity)
        
        if #options > 0 then
            table.insert(nearbyTargets.entities, {
                entity = entity,
                coords = GetEntityCoords(entity),
                distance = #(playerCoords - GetEntityCoords(entity)),
                options = options
            })
        end
    end
    
    -- Zones
    for _, zone in ipairs(registeredZones) do
        if IsPlayerInZone(playerCoords, zone) then
            table.insert(nearbyTargets.zones, {
                name = zone.name,
                type = zone.type,
                coords = zone.coords,
                distance = #(playerCoords - zone.coords),
                options = zone.options
            })
        end
    end
    
    return nearbyTargets
end

-- Fonction helper pour obtenir les entités proches
function GetNearbyEntities(coords, distance)
    local entities = {}
    
    -- Peds
    if TargetConfig.EntityTypes.peds then
        local peds = GetGamePool('CPed')
        for _, ped in ipairs(peds) do
            if DoesEntityExist(ped) and #(coords - GetEntityCoords(ped)) <= distance then
                table.insert(entities, ped)
            end
        end
    end
    
    -- Véhicules
    if TargetConfig.EntityTypes.vehicles then
        local vehicles = GetGamePool('CVehicle')
        for _, vehicle in ipairs(vehicles) do
            if DoesEntityExist(vehicle) and #(coords - GetEntityCoords(vehicle)) <= distance then
                table.insert(entities, vehicle)
            end
        end
    end
    
    -- Objets
    if TargetConfig.EntityTypes.objects then
        local objects = GetGamePool('CObject')
        for _, object in ipairs(objects) do
            if DoesEntityExist(object) and #(coords - GetEntityCoords(object)) <= distance then
                table.insert(entities, object)
            end
        end
    end
    
    return entities
end

-- ============================================
-- EXPORTS
-- ============================================

exports('AddTargetEntity', AddTargetEntity)
exports('AddTargetModel', AddTargetModel)
exports('AddTargetZone', AddTargetZone)
exports('AddTargetBone', AddTargetBone)
exports('RemoveTarget', RemoveTarget)
exports('RemoveTargetModel', RemoveTargetModel)
exports('RemoveTargetZone', RemoveTargetZone)
exports('RemoveTargetBone', RemoveTargetBone)
exports('DisableTarget', DisableTarget)
exports('IsTargetActive', IsTargetActive)
exports('GetNearbyTargets', GetNearbyTargets)

-- ============================================
-- CHARGEMENT DES ZONES ET MODÈLES PRÉDÉFINIS
-- ============================================

Citizen.CreateThread(function()
    Citizen.Wait(2000) -- Attendre le chargement complet
    
    -- Charger zones prédéfinies
    if TargetConfig.Zones then
        for _, zoneData in ipairs(TargetConfig.Zones) do
            local options = zoneData.options
            zoneData.options = nil -- Retirer options temporairement
            
            AddTargetZone(zoneData, options)
        end
        
        print(string.format('[vAvA Target] Loaded %d predefined zones', #TargetConfig.Zones))
    end
    
    -- Charger modèles prédéfinis
    if TargetConfig.Models then
        for _, modelData in ipairs(TargetConfig.Models) do
            AddTargetModel(modelData.models, modelData.options)
        end
        
        print(string.format('[vAvA Target] Loaded %d predefined models', #TargetConfig.Models))
    end
    
    print('[vAvA Target] Client initialized successfully')
end)
