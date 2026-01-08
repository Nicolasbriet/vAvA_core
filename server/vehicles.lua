--[[
    vAvA_core - Server Vehicles
    Gestion des véhicules
]]

vCore = vCore or {}
vCore.Vehicles = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS PRINCIPALES
-- ═══════════════════════════════════════════════════════════════════════════

---Récupère les véhicules d'un joueur
---@param source number
---@return table
function vCore.Vehicles.GetPlayerVehicles(source)
    local player = vCore.GetPlayer(source)
    if not player then return {} end
    
    return vCore.DB.GetPlayerVehicles(player:GetIdentifier())
end

---Donne un véhicule à un joueur
---@param source number
---@param model string
---@param plate? string
---@param props? table
---@return boolean, string|nil plate
function vCore.Vehicles.GiveVehicle(source, model, plate, props)
    local player = vCore.GetPlayer(source)
    if not player then return false, nil end
    
    -- Générer la plaque si non fournie
    if not plate then
        plate = vCore.Vehicles.GeneratePlate()
    end
    
    -- Vérifier que la plaque n'existe pas
    local existing = vCore.DB.Single('SELECT id FROM vehicles WHERE plate = ?', {plate})
    if existing then
        return false, nil
    end
    
    local id = vCore.DB.AddVehicle(player:GetIdentifier(), plate, model, props)
    
    if id then
        vCore.Log('vehicle', player:GetIdentifier(),
            'Véhicule ajouté: ' .. model .. ' (' .. plate .. ')',
            {model = model, plate = plate}
        )
        
        return true, plate
    end
    
    return false, nil
end

---Génère une plaque d'immatriculation
---@return string
function vCore.Vehicles.GeneratePlate()
    local chars = 'ABCDEFGHIJKLMNOPQRSTUVWXYZ'
    local nums = '0123456789'
    
    local plate = ''
    
    -- Format: ABC 123
    for i = 1, 3 do
        local idx = math.random(1, #chars)
        plate = plate .. string.sub(chars, idx, idx)
    end
    
    plate = plate .. ' '
    
    for i = 1, 3 do
        local idx = math.random(1, #nums)
        plate = plate .. string.sub(nums, idx, idx)
    end
    
    return plate
end

---Met à jour l'état d'un véhicule
---@param plate string
---@param state string
---@return boolean
function vCore.Vehicles.SetState(plate, state)
    return vCore.DB.UpdateVehicleState(plate, state)
end

---Vérifie si un joueur possède un véhicule
---@param source number
---@param plate string
---@return boolean
function vCore.Vehicles.OwnsVehicle(source, plate)
    local player = vCore.GetPlayer(source)
    if not player then return false end
    
    local vehicle = vCore.DB.Single('SELECT * FROM vehicles WHERE plate = ? AND owner = ?', 
        {plate, player:GetIdentifier()})
    
    return vehicle ~= nil
end

---Récupère un véhicule par plaque
---@param plate string
---@return table|nil
function vCore.Vehicles.GetVehicle(plate)
    return vCore.DB.Single('SELECT * FROM vehicles WHERE plate = ?', {plate})
end

---Supprime un véhicule
---@param plate string
---@return boolean
function vCore.Vehicles.DeleteVehicle(plate)
    local affected = vCore.DB.Execute('DELETE FROM vehicles WHERE plate = ?', {plate})
    return affected > 0
end

---Met à jour les propriétés d'un véhicule
---@param plate string
---@param props table
---@return boolean
function vCore.Vehicles.UpdateProps(plate, props)
    local affected = vCore.DB.Execute(
        'UPDATE vehicles SET props = ? WHERE plate = ?',
        {json.encode(props), plate}
    )
    return affected > 0
end

---Met à jour le carburant
---@param plate string
---@param fuel number
---@return boolean
function vCore.Vehicles.SetFuel(plate, fuel)
    local affected = vCore.DB.Execute(
        'UPDATE vehicles SET fuel = ? WHERE plate = ?',
        {math.floor(fuel), plate}
    )
    return affected > 0
end

---Met à jour l'état de carrosserie et moteur
---@param plate string
---@param body number
---@param engine number
---@return boolean
function vCore.Vehicles.UpdateHealth(plate, body, engine)
    local affected = vCore.DB.Execute(
        'UPDATE vehicles SET body = ?, engine = ? WHERE plate = ?',
        {body, engine, plate}
    )
    return affected > 0
end

-- ═══════════════════════════════════════════════════════════════════════════
-- EXPORTS
-- ═══════════════════════════════════════════════════════════════════════════

exports('GetPlayerVehicles', function(source)
    return vCore.Vehicles.GetPlayerVehicles(source)
end)

exports('GiveVehicle', function(source, model, plate, props)
    return vCore.Vehicles.GiveVehicle(source, model, plate, props)
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- ÉVÉNEMENTS
-- ═══════════════════════════════════════════════════════════════════════════

-- Sortir un véhicule du garage
RegisterNetEvent('vCore:spawnVehicle', function(plate)
    local source = source
    local player = vCore.GetPlayer(source)
    
    if not player then return end
    
    local vehicle = vCore.Vehicles.GetVehicle(plate)
    
    if not vehicle then
        vCore.Notify(source, Lang('vehicle_not_found'), 'error')
        return
    end
    
    if vehicle.owner ~= player:GetIdentifier() then
        vCore.Notify(source, Lang('vehicle_not_owned'), 'error')
        return
    end
    
    if vehicle.state ~= 'garaged' then
        vCore.Notify(source, Lang('vehicle_already_out'), 'error')
        return
    end
    
    -- Mettre à jour l'état
    vCore.Vehicles.SetState(plate, 'out')
    
    -- Envoyer les infos au client pour spawn
    TriggerClientEvent('vCore:doSpawnVehicle', source, vehicle)
    
    vCore.Log('vehicle', player:GetIdentifier(),
        'Véhicule sorti: ' .. plate,
        {plate = plate}
    )
end)

-- Ranger un véhicule au garage
RegisterNetEvent('vCore:storeVehicle', function(plate)
    local source = source
    local player = vCore.GetPlayer(source)
    
    if not player then return end
    
    if not vCore.Vehicles.OwnsVehicle(source, plate) then
        vCore.Notify(source, Lang('vehicle_not_owned'), 'error')
        return
    end
    
    vCore.Vehicles.SetState(plate, 'garaged')
    vCore.Notify(source, Lang('vehicle_stored'), 'success')
    
    TriggerEvent(vCore.Events.VEHICLE_STORED, source, plate)
end)

-- Mettre à jour les props du véhicule
RegisterNetEvent('vCore:updateVehicleProps', function(plate, props, fuel, body, engine)
    local source = source
    
    if not vCore.Vehicles.OwnsVehicle(source, plate) then return end
    
    vCore.Vehicles.UpdateProps(plate, props)
    vCore.Vehicles.SetFuel(plate, fuel)
    vCore.Vehicles.UpdateHealth(plate, body, engine)
end)
