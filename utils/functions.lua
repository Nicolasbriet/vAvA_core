--[[
    vAvA_core - Utils Functions
    Fonctions utilitaires additionnelles
]]

vCore = vCore or {}

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS MATH
-- ═══════════════════════════════════════════════════════════════════════════

---Interpole linéairement entre deux valeurs
---@param a number
---@param b number
---@param t number
---@return number
function vCore.Utils.Lerp(a, b, t)
    return a + (b - a) * t
end

---Retourne un angle normalisé entre 0 et 360
---@param angle number
---@return number
function vCore.Utils.NormalizeAngle(angle)
    return angle % 360
end

---Retourne un vecteur normalisé
---@param vec vector3
---@return vector3
function vCore.Utils.NormalizeVector(vec)
    local len = #vec
    if len == 0 then return vec end
    return vec / len
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS RAYCAST
-- ═══════════════════════════════════════════════════════════════════════════

---Effectue un raycast depuis la caméra
---@param distance number
---@param flags? number
---@return boolean, vector3, vector3, number
function vCore.Utils.RaycastFromCamera(distance, flags)
    flags = flags or 1
    
    local camRot = GetGameplayCamRot(2)
    local camPos = GetGameplayCamCoord()
    
    local dir = vCore.Utils.RotationToDirection(camRot)
    local dest = camPos + dir * distance
    
    local ray = StartShapeTestRay(camPos.x, camPos.y, camPos.z, dest.x, dest.y, dest.z, flags, PlayerPedId(), 0)
    local _, hit, endCoords, surfaceNormal, entity = GetShapeTestResult(ray)
    
    return hit == 1, endCoords, surfaceNormal, entity
end

---Convertit une rotation en direction
---@param rotation vector3
---@return vector3
function vCore.Utils.RotationToDirection(rotation)
    local radX = math.rad(rotation.x)
    local radZ = math.rad(rotation.z)
    
    local num = math.abs(math.cos(radX))
    
    return vector3(
        -math.sin(radZ) * num,
        math.cos(radZ) * num,
        math.sin(radX)
    )
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS ENTITY
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne l'entité la plus proche
---@param entities table
---@param coords vector3
---@return number, number
function vCore.Utils.GetClosestEntity(entities, coords)
    local closestEntity = -1
    local closestDistance = -1
    
    for _, entity in ipairs(entities) do
        local entityCoords = GetEntityCoords(entity)
        local distance = #(coords - entityCoords)
        
        if closestDistance == -1 or distance < closestDistance then
            closestEntity = entity
            closestDistance = distance
        end
    end
    
    return closestEntity, closestDistance
end

---Retourne tous les véhicules proches
---@param coords vector3
---@param radius number
---@return table
function vCore.Utils.GetNearbyVehicles(coords, radius)
    local vehicles = {}
    local handle, vehicle = FindFirstVehicle()
    local success
    
    repeat
        local vehicleCoords = GetEntityCoords(vehicle)
        local distance = #(coords - vehicleCoords)
        
        if distance <= radius then
            table.insert(vehicles, {
                entity = vehicle,
                coords = vehicleCoords,
                distance = distance
            })
        end
        
        success, vehicle = FindNextVehicle(handle)
    until not success
    
    EndFindVehicle(handle)
    
    return vehicles
end

---Retourne tous les peds proches
---@param coords vector3
---@param radius number
---@return table
function vCore.Utils.GetNearbyPeds(coords, radius)
    local peds = {}
    local handle, ped = FindFirstPed()
    local success
    local myPed = PlayerPedId()
    
    repeat
        if ped ~= myPed then
            local pedCoords = GetEntityCoords(ped)
            local distance = #(coords - pedCoords)
            
            if distance <= radius then
                table.insert(peds, {
                    entity = ped,
                    coords = pedCoords,
                    distance = distance
                })
            end
        end
        
        success, ped = FindNextPed(handle)
    until not success
    
    EndFindPed(handle)
    
    return peds
end

---Retourne tous les objets proches
---@param coords vector3
---@param radius number
---@return table
function vCore.Utils.GetNearbyObjects(coords, radius)
    local objects = {}
    local handle, object = FindFirstObject()
    local success
    
    repeat
        local objectCoords = GetEntityCoords(object)
        local distance = #(coords - objectCoords)
        
        if distance <= radius then
            table.insert(objects, {
                entity = object,
                coords = objectCoords,
                distance = distance
            })
        end
        
        success, object = FindNextObject(handle)
    until not success
    
    EndFindObject(handle)
    
    return objects
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS ASYNC
-- ═══════════════════════════════════════════════════════════════════════════

---Attend qu'une condition soit vraie
---@param condition function
---@param timeout? number
---@return boolean
function vCore.Utils.WaitUntil(condition, timeout)
    timeout = timeout or 10000
    local startTime = GetGameTimer()
    
    while not condition() do
        if GetGameTimer() - startTime > timeout then
            return false
        end
        Wait(10)
    end
    
    return true
end

---Exécute une fonction après un délai
---@param delay number
---@param callback function
function vCore.Utils.SetTimeout(delay, callback)
    SetTimeout(delay, callback)
end

---Exécute une fonction à intervalle régulier
---@param interval number
---@param callback function
---@return number intervalId
function vCore.Utils.SetInterval(interval, callback)
    local id = math.random(100000, 999999)
    
    CreateThread(function()
        while true do
            Wait(interval)
            if not callback() then break end
        end
    end)
    
    return id
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS STRING
-- ═══════════════════════════════════════════════════════════════════════════

---Première lettre en majuscule
---@param str string
---@return string
function vCore.Utils.Capitalize(str)
    return str:sub(1, 1):upper() .. str:sub(2):lower()
end

---Convertit en camelCase
---@param str string
---@return string
function vCore.Utils.ToCamelCase(str)
    local result = str:gsub("(%s+)(%w)", function(_, c)
        return c:upper()
    end)
    return result:sub(1, 1):lower() .. result:sub(2)
end

---Vérifie si une chaîne commence par
---@param str string
---@param prefix string
---@return boolean
function vCore.Utils.StartsWith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

---Vérifie si une chaîne se termine par
---@param str string
---@param suffix string
---@return boolean
function vCore.Utils.EndsWith(str, suffix)
    return suffix == "" or str:sub(-#suffix) == suffix
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS TABLE
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne les clés d'une table
---@param tbl table
---@return table
function vCore.Utils.TableKeys(tbl)
    local keys = {}
    for k in pairs(tbl) do
        table.insert(keys, k)
    end
    return keys
end

---Retourne les valeurs d'une table
---@param tbl table
---@return table
function vCore.Utils.TableValues(tbl)
    local values = {}
    for _, v in pairs(tbl) do
        table.insert(values, v)
    end
    return values
end

---Filtre une table
---@param tbl table
---@param predicate function
---@return table
function vCore.Utils.TableFilter(tbl, predicate)
    local result = {}
    for k, v in pairs(tbl) do
        if predicate(v, k) then
            if type(k) == 'number' then
                table.insert(result, v)
            else
                result[k] = v
            end
        end
    end
    return result
end

---Map une table
---@param tbl table
---@param mapper function
---@return table
function vCore.Utils.TableMap(tbl, mapper)
    local result = {}
    for k, v in pairs(tbl) do
        result[k] = mapper(v, k)
    end
    return result
end

---Trouve un élément dans une table
---@param tbl table
---@param predicate function
---@return any, any
function vCore.Utils.TableFind(tbl, predicate)
    for k, v in pairs(tbl) do
        if predicate(v, k) then
            return v, k
        end
    end
    return nil, nil
end
