--[[
    vAvA_core - Helpers & Shortcuts
    Fonctions helper pour faciliter le développement
]]

vCore = vCore or {}
vCore.Helpers = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- PLAYER HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

if IsDuplicityVersion() then
    ---Obtient l'identifier d'un joueur
    ---@param source number
    ---@return string|nil
    function vCore.Helpers.GetIdentifier(source)
        local player = vCore.GetPlayer(source)
        return player and player:GetIdentifier()
    end
    
    ---Obtient le nom d'un joueur
    ---@param source number
    ---@return string|nil
    function vCore.Helpers.GetPlayerName(source)
        local player = vCore.GetPlayer(source)
        return player and player:GetName() or GetPlayerName(source)
    end
    
    ---Obtient l'argent d'un joueur
    ---@param source number
    ---@param type string
    ---@return number
    function vCore.Helpers.GetMoney(source, type)
        local player = vCore.GetPlayer(source)
        return player and player:GetMoney(type) or 0
    end
    
    ---Vérifie si un joueur a assez d'argent
    ---@param source number
    ---@param type string
    ---@param amount number
    ---@return boolean
    function vCore.Helpers.HasMoney(source, type, amount)
        return vCore.Helpers.GetMoney(source, type) >= amount
    end
    
    ---Obtient le job d'un joueur
    ---@param source number
    ---@return table|nil
    function vCore.Helpers.GetJob(source)
        local player = vCore.GetPlayer(source)
        return player and player:GetJob()
    end
    
    ---Vérifie si un joueur a un job
    ---@param source number
    ---@param jobName string
    ---@param minGrade? number
    ---@return boolean
    function vCore.Helpers.HasJob(source, jobName, minGrade)
        return vCore.Permissions.HasJob(source, jobName, minGrade)
    end
    
    ---Vérifie si un joueur est en service
    ---@param source number
    ---@return boolean
    function vCore.Helpers.IsOnDuty(source)
        local player = vCore.GetPlayer(source)
        return player and player:IsOnDuty() or false
    end
    
    ---Obtient tous les joueurs avec un job
    ---@param jobName string
    ---@return table
    function vCore.Helpers.GetJobPlayers(jobName)
        local players = {}
        for _, player in pairs(vCore.GetPlayers()) do
            local job = player:GetJob()
            if job.name == jobName then
                table.insert(players, player)
            end
        end
        return players
    end
    
    ---Obtient tous les joueurs en service avec un job
    ---@param jobName string
    ---@return table
    function vCore.Helpers.GetOnDutyJobPlayers(jobName)
        local players = {}
        for _, player in pairs(vCore.GetPlayers()) do
            local job = player:GetJob()
            if job.name == jobName and player:IsOnDuty() then
                table.insert(players, player)
            end
        end
        return players
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- NOTIFICATION HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

---Notification de succès
---@param target number
---@param message string
---@param duration? number
function vCore.Helpers.NotifySuccess(target, message, duration)
    if IsDuplicityVersion() then
        TriggerClientEvent(vCore.Events.UI_NOTIFY, target, message, 'success', duration)
    else
        vCore.UI.Notify(message, 'success', duration)
    end
end

---Notification d'erreur
---@param target number
---@param message string
---@param duration? number
function vCore.Helpers.NotifyError(target, message, duration)
    if IsDuplicityVersion() then
        TriggerClientEvent(vCore.Events.UI_NOTIFY, target, message, 'error', duration)
    else
        vCore.UI.Notify(message, 'error', duration)
    end
end

---Notification d'avertissement
---@param target number
---@param message string
---@param duration? number
function vCore.Helpers.NotifyWarning(target, message, duration)
    if IsDuplicityVersion() then
        TriggerClientEvent(vCore.Events.UI_NOTIFY, target, message, 'warning', duration)
    else
        vCore.UI.Notify(message, 'warning', duration)
    end
end

---Notification d'information
---@param target number
---@param message string
---@param duration? number
function vCore.Helpers.NotifyInfo(target, message, duration)
    if IsDuplicityVersion() then
        TriggerClientEvent(vCore.Events.UI_NOTIFY, target, message, 'info', duration)
    else
        vCore.UI.Notify(message, 'info', duration)
    end
end

---Notification à tous les joueurs
---@param message string
---@param type string
---@param duration? number
function vCore.Helpers.NotifyAll(message, type, duration)
    if IsDuplicityVersion() then
        TriggerClientEvent(vCore.Events.UI_NOTIFY, -1, message, type, duration)
    end
end

---Notification à tous les joueurs avec un job
---@param jobName string
---@param message string
---@param type string
---@param duration? number
function vCore.Helpers.NotifyJob(jobName, message, type, duration)
    if IsDuplicityVersion() then
        local players = vCore.Helpers.GetJobPlayers(jobName)
        for _, player in ipairs(players) do
            TriggerClientEvent(vCore.Events.UI_NOTIFY, player:GetSource(), message, type, duration)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DISTANCE HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

---Vérifie si deux positions sont proches
---@param pos1 vector3|table
---@param pos2 vector3|table
---@param maxDistance number
---@return boolean
function vCore.Helpers.IsNearby(pos1, pos2, maxDistance)
    if not pos1 or not pos2 then return false end
    
    local x1 = pos1.x or pos1[1]
    local y1 = pos1.y or pos1[2]
    local z1 = pos1.z or pos1[3]
    local x2 = pos2.x or pos2[1]
    local y2 = pos2.y or pos2[2]
    local z2 = pos2.z or pos2[3]
    
    local distance = vCore.Utils.GetDistance(x1, y1, z1, x2, y2, z2)
    return distance <= maxDistance
end

if not IsDuplicityVersion() then
    ---Obtient la position du joueur
    ---@return vector3
    function vCore.Helpers.GetPlayerCoords()
        return GetEntityCoords(PlayerPedId())
    end
    
    ---Vérifie si le joueur est proche d'une position
    ---@param coords vector3|table
    ---@param maxDistance number
    ---@return boolean
    function vCore.Helpers.IsPlayerNearby(coords, maxDistance)
        return vCore.Helpers.IsNearby(vCore.Helpers.GetPlayerCoords(), coords, maxDistance)
    end
    
    ---Obtient le véhicule actuel du joueur
    ---@return number
    function vCore.Helpers.GetPlayerVehicle()
        local ped = PlayerPedId()
        return GetVehiclePedIsIn(ped, false)
    end
    
    ---Vérifie si le joueur est dans un véhicule
    ---@return boolean
    function vCore.Helpers.IsInVehicle()
        return IsPedInAnyVehicle(PlayerPedId(), false)
    end
    
    ---Vérifie si le joueur est conducteur
    ---@return boolean
    function vCore.Helpers.IsDriver()
        local ped = PlayerPedId()
        local vehicle = GetVehiclePedIsIn(ped, false)
        if vehicle == 0 then return false end
        return GetPedInVehicleSeat(vehicle, -1) == ped
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- ITEM HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

if IsDuplicityVersion() then
    ---Vérifie si un joueur a un item
    ---@param source number
    ---@param itemName string
    ---@param amount? number
    ---@return boolean
    function vCore.Helpers.HasItem(source, itemName, amount)
        local player = vCore.GetPlayer(source)
        return player and player:HasItem(itemName, amount) or false
    end
    
    ---Obtient la quantité d'un item
    ---@param source number
    ---@param itemName string
    ---@return number
    function vCore.Helpers.GetItemCount(source, itemName)
        local player = vCore.GetPlayer(source)
        if not player then return 0 end
        
        local item = player:GetItem(itemName)
        return item and item.amount or 0
    end
    
    ---Vérifie si le joueur peut porter plus de poids
    ---@param source number
    ---@param weight number
    ---@return boolean
    function vCore.Helpers.CanCarry(source, weight)
        local player = vCore.GetPlayer(source)
        return player and player:CanCarry(weight) or false
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- VEHICLE HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

if not IsDuplicityVersion() then
    ---Obtient les propriétés d'un véhicule
    ---@param vehicle number
    ---@return table
    function vCore.Helpers.GetVehicleProperties(vehicle)
        if not DoesEntityExist(vehicle) then return {} end
        
        local props = {
            model = GetEntityModel(vehicle),
            plate = GetVehicleNumberPlateText(vehicle),
            color1 = GetVehicleColours(vehicle),
            pearlescentColor = GetVehicleExtraColours(vehicle),
            windowTint = GetVehicleWindowTint(vehicle),
            wheels = GetVehicleWheelType(vehicle),
            neonEnabled = {
                IsVehicleNeonLightEnabled(vehicle, 0),
                IsVehicleNeonLightEnabled(vehicle, 1),
                IsVehicleNeonLightEnabled(vehicle, 2),
                IsVehicleNeonLightEnabled(vehicle, 3)
            },
            modEngine = GetVehicleMod(vehicle, 11),
            modBrakes = GetVehicleMod(vehicle, 12),
            modTransmission = GetVehicleMod(vehicle, 13),
            modSuspension = GetVehicleMod(vehicle, 15),
            modArmor = GetVehicleMod(vehicle, 16),
            modTurbo = IsToggleModOn(vehicle, 18)
        }
        
        return props
    end
    
    ---Applique les propriétés à un véhicule
    ---@param vehicle number
    ---@param props table
    function vCore.Helpers.SetVehicleProperties(vehicle, props)
        if not DoesEntityExist(vehicle) or not props then return end
        
        if props.plate then
            SetVehicleNumberPlateText(vehicle, props.plate)
        end
        
        if props.color1 then
            SetVehicleColours(vehicle, props.color1, props.color1)
        end
        
        if props.windowTint then
            SetVehicleWindowTint(vehicle, props.windowTint)
        end
        
        if props.wheels then
            SetVehicleWheelType(vehicle, props.wheels)
        end
        
        if props.modEngine then
            SetVehicleMod(vehicle, 11, props.modEngine, false)
        end
        
        if props.modBrakes then
            SetVehicleMod(vehicle, 12, props.modBrakes, false)
        end
        
        if props.modTransmission then
            SetVehicleMod(vehicle, 13, props.modTransmission, false)
        end
        
        if props.modTurbo then
            ToggleVehicleMod(vehicle, 18, true)
        end
    end
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TIMING HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

---Attend avec callback
---@param ms number
---@param callback function
function vCore.Helpers.Wait(ms, callback)
    Citizen.SetTimeout(ms, callback)
end

---Crée un intervalle
---@param ms number
---@param callback function
---@return number intervalId
function vCore.Helpers.SetInterval(ms, callback)
    return SetInterval(callback, ms)
end

---Arrête un intervalle
---@param intervalId number
function vCore.Helpers.ClearInterval(intervalId)
    ClearInterval(intervalId)
end

---Crée un timer avec compte à rebours
---@param duration number Durée en secondes
---@param onTick? function Appelé chaque seconde avec le temps restant
---@param onComplete? function Appelé à la fin
function vCore.Helpers.CreateTimer(duration, onTick, onComplete)
    local remaining = duration
    
    local interval = vCore.Helpers.SetInterval(1000, function()
        remaining = remaining - 1
        
        if onTick then
            onTick(remaining)
        end
        
        if remaining <= 0 then
            vCore.Helpers.ClearInterval(interval)
            if onComplete then
                onComplete()
            end
        end
    end)
    
    return interval
end

-- ═══════════════════════════════════════════════════════════════════════════
-- MATH HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

---Calcule un pourcentage
---@param value number
---@param max number
---@return number
function vCore.Helpers.Percentage(value, max)
    if max == 0 then return 0 end
    return (value / max) * 100
end

---Applique un pourcentage
---@param value number
---@param percentage number
---@return number
function vCore.Helpers.ApplyPercentage(value, percentage)
    return value * (percentage / 100)
end

---Interpole entre deux valeurs
---@param a number
---@param b number
---@param t number Entre 0 et 1
---@return number
function vCore.Helpers.Lerp(a, b, t)
    return a + (b - a) * vCore.Utils.Clamp(t, 0, 1)
end

---Génère un nombre aléatoire float
---@param min number
---@param max number
---@return number
function vCore.Helpers.RandomFloat(min, max)
    return min + (math.random() * (max - min))
end

---Vérifie si un nombre est pair
---@param n number
---@return boolean
function vCore.Helpers.IsEven(n)
    return n % 2 == 0
end

---Vérifie si un nombre est impair
---@param n number
---@return boolean
function vCore.Helpers.IsOdd(n)
    return n % 2 ~= 0
end

-- ═══════════════════════════════════════════════════════════════════════════
-- STRING HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

---Met la première lettre en majuscule
---@param str string
---@return string
function vCore.Helpers.Capitalize(str)
    return str:sub(1, 1):upper() .. str:sub(2):lower()
end

---Met en titre (première lettre de chaque mot)
---@param str string
---@return string
function vCore.Helpers.TitleCase(str)
    return str:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)
end

---Vérifie si une chaîne commence par
---@param str string
---@param prefix string
---@return boolean
function vCore.Helpers.StartsWith(str, prefix)
    return str:sub(1, #prefix) == prefix
end

---Vérifie si une chaîne se termine par
---@param str string
---@param suffix string
---@return boolean
function vCore.Helpers.EndsWith(str, suffix)
    return suffix == '' or str:sub(-#suffix) == suffix
end

---Remplace toutes les occurrences
---@param str string
---@param find string
---@param replace string
---@return string
function vCore.Helpers.ReplaceAll(str, find, replace)
    return str:gsub(find, replace)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- TABLE HELPERS
-- ═══════════════════════════════════════════════════════════════════════════

---Filtre un tableau
---@param tbl table
---@param predicate function
---@return table
function vCore.Helpers.Filter(tbl, predicate)
    local result = {}
    for i, v in ipairs(tbl) do
        if predicate(v, i) then
            table.insert(result, v)
        end
    end
    return result
end

---Map un tableau
---@param tbl table
---@param func function
---@return table
function vCore.Helpers.Map(tbl, func)
    local result = {}
    for i, v in ipairs(tbl) do
        table.insert(result, func(v, i))
    end
    return result
end

---Réduit un tableau
---@param tbl table
---@param func function
---@param initial any
---@return any
function vCore.Helpers.Reduce(tbl, func, initial)
    local accumulator = initial
    for i, v in ipairs(tbl) do
        accumulator = func(accumulator, v, i)
    end
    return accumulator
end

---Trouve un élément
---@param tbl table
---@param predicate function
---@return any|nil
function vCore.Helpers.Find(tbl, predicate)
    for i, v in ipairs(tbl) do
        if predicate(v, i) then
            return v
        end
    end
    return nil
end

---Vérifie si un élément existe
---@param tbl table
---@param predicate function
---@return boolean
function vCore.Helpers.Some(tbl, predicate)
    for i, v in ipairs(tbl) do
        if predicate(v, i) then
            return true
        end
    end
    return false
end

---Vérifie si tous les éléments respectent la condition
---@param tbl table
---@param predicate function
---@return boolean
function vCore.Helpers.Every(tbl, predicate)
    for i, v in ipairs(tbl) do
        if not predicate(v, i) then
            return false
        end
    end
    return true
end

---Inverse un tableau
---@param tbl table
---@return table
function vCore.Helpers.Reverse(tbl)
    local result = {}
    for i = #tbl, 1, -1 do
        table.insert(result, tbl[i])
    end
    return result
end

---Mélange un tableau (shuffle)
---@param tbl table
---@return table
function vCore.Helpers.Shuffle(tbl)
    local result = vCore.Utils.DeepClone(tbl)
    for i = #result, 2, -1 do
        local j = math.random(i)
        result[i], result[j] = result[j], result[i]
    end
    return result
end

print('^2[vCore:Helpers]^7 Fonctions helper chargées (' .. vCore.Utils.TableCount(vCore.Helpers) .. ' helpers)')
