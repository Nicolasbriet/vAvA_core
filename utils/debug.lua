--[[
    vAvA_core - Debug Tools
    Outils de débogage pour développeurs
]]

vCore = vCore or {}
vCore.Debug = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- ACTIVATION DU MODE DEBUG
-- ═══════════════════════════════════════════════════════════════════════════

local debugMode = Config.Debug or false
local debugOverlay = false

---Active/Désactive le mode debug
function vCore.Debug.Toggle()
    debugMode = not debugMode
    vCore.Utils.Print('Mode debug:', debugMode and 'ACTIVÉ' or 'DÉSACTIVÉ')
end

---Vérifie si le mode debug est actif
---@return boolean
function vCore.Debug.IsEnabled()
    return debugMode
end

-- ═══════════════════════════════════════════════════════════════════════════
-- LOGGING AVANCÉ
-- ═══════════════════════════════════════════════════════════════════════════

---Log avec stack trace
---@param ... any
function vCore.Debug.Trace(...)
    if not debugMode then return end
    
    local args = {...}
    local message = ''
    
    for i, v in ipairs(args) do
        if type(v) == 'table' then
            message = message .. json.encode(v)
        else
            message = message .. tostring(v)
        end
        if i < #args then
            message = message .. ' '
        end
    end
    
    local trace = debug.traceback('', 2)
    print('^5[vCore:Trace]^7 ' .. message)
    print(trace)
end

---Log une table formatée
---@param tbl table
---@param name? string
function vCore.Debug.PrintTable(tbl, name)
    if not debugMode then return end
    
    name = name or 'Table'
    print('^3[vCore:Debug] ' .. name .. ':^7')
    print(json.encode(tbl, {indent = true}))
end

---Mesure le temps d'exécution
---@param name string
---@param func function
---@return any
function vCore.Debug.Benchmark(name, func)
    if not debugMode then return func() end
    
    local startTime = GetGameTimer()
    local result = {func()}
    local endTime = GetGameTimer()
    
    print(string.format('^3[vCore:Benchmark]^7 %s: %dms', name, endTime - startTime))
    
    return table.unpack(result)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- DEBUG OVERLAY (CLIENT SEULEMENT)
-- ═══════════════════════════════════════════════════════════════════════════

if IsDuplicityVersion() then return end -- Arrêter ici si serveur

---Toggle l'overlay de debug
function vCore.Debug.ToggleOverlay()
    debugOverlay = not debugOverlay
end

---Affiche l'overlay de debug
CreateThread(function()
    while true do
        Wait(500) -- Changé de 0 à 500 pour éviter freeze serveur
        
        if debugMode and debugOverlay then
            local ped = PlayerPedId()
            local coords = GetEntityCoords(ped)
            local heading = GetEntityHeading(ped)
            local vehicle = GetVehiclePedIsIn(ped, false)
            
            local text = string.format([[
~b~=== vCore Debug ===~s~
~y~Position:~s~ %.2f, %.2f, %.2f
~y~Heading:~s~ %.2f
~y~Health:~s~ %d / %d
~y~Armor:~s~ %d
]], coords.x, coords.y, coords.z, heading, GetEntityHealth(ped) - 100, 100, GetPedArmour(ped))
            
            if vehicle ~= 0 then
                local speed = GetEntitySpeed(vehicle) * 3.6
                local fuel = GetVehicleFuelLevel(vehicle)
                local plate = GetVehicleNumberPlateText(vehicle)
                
                text = text .. string.format([[
~b~--- Vehicle ---~s~
~y~Plate:~s~ %s
~y~Speed:~s~ %.0f km/h
~y~Fuel:~s~ %.0f%%
]], plate, speed, fuel)
            end
            
            if vCore.PlayerData then
                local money = vCore.PlayerData.money or {}
                local job = vCore.PlayerData.job or {}
                local status = vCore.PlayerData.status or {}
                
                text = text .. string.format([[
~b~--- Player ---~s~
~y~Cash:~s~ $%s
~y~Bank:~s~ $%s
~y~Job:~s~ %s (%d)
~y~Hunger:~s~ %.0f%%
~y~Thirst:~s~ %.0f%%
]], 
                    vCore.Utils.FormatNumber(money.cash or 0),
                    vCore.Utils.FormatNumber(money.bank or 0),
                    job.label or 'N/A',
                    job.grade or 0,
                    status.hunger or 0,
                    status.thirst or 0
                )
            end
            
            DrawDebugText(text, 0.01, 0.3)
        end
    end
end)

---Dessine du texte de debug
---@param text string
---@param x number
---@param y number
function DrawDebugText(text, x, y)
    SetTextFont(0)
    SetTextProportional(true)
    SetTextScale(0.0, 0.3)
    SetTextColour(255, 255, 255, 255)
    SetTextDropShadow()
    SetTextEdge(1, 0, 0, 0, 255)
    SetTextOutline()
    SetTextEntry('STRING')
    AddTextComponentString(text)
    DrawText(x, y)
end

-- ═══════════════════════════════════════════════════════════════════════════
-- COMMANDES DEBUG
-- ═══════════════════════════════════════════════════════════════════════════

RegisterCommand('debug', function()
    vCore.Debug.Toggle()
end, false)

RegisterCommand('debugoverlay', function()
    vCore.Debug.ToggleOverlay()
end, false)

RegisterCommand('coords', function()
    local ped = PlayerPedId()
    local coords = GetEntityCoords(ped)
    local heading = GetEntityHeading(ped)
    
    local coordsStr = string.format('vector4(%.4f, %.4f, %.4f, %.4f)', coords.x, coords.y, coords.z, heading)
    
    print('^2[Coords]^7 ' .. coordsStr)
    vCore.Notify('Coordonnées copiées dans la console', 'info')
end, false)

RegisterCommand('tpm', function()
    local blip = GetFirstBlipInfoId(8)
    
    if not DoesBlipExist(blip) then
        vCore.Notify('Aucun waypoint défini', 'error')
        return
    end
    
    local coords = GetBlipInfoIdCoord(blip)
    local ped = PlayerPedId()
    
    -- Trouver le sol
    local groundFound, groundZ = false, coords.z
    
    for height = 1, 1000 do
        groundFound, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, height + 0.0, true)
        if groundFound then
            break
        end
    end
    
    SetEntityCoords(ped, coords.x, coords.y, groundZ + 1.0, false, false, false, true)
    vCore.Notify('Téléporté au waypoint', 'success')
end, false)
