--[[
    vAvA_core - Client Player
    Fonctions liées au joueur côté client
]]

vCore = vCore or {}
vCore.Player = {}

-- ═══════════════════════════════════════════════════════════════════════════
-- INFORMATIONS JOUEUR
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne le nom complet du joueur
---@return string
function vCore.Player.GetName()
    return (vCore.PlayerData.firstName or '') .. ' ' .. (vCore.PlayerData.lastName or '')
end

---Retourne le job du joueur
---@return table
function vCore.Player.GetJob()
    return vCore.PlayerData.job or {}
end

---Vérifie si le joueur est en service
---@return boolean
function vCore.Player.IsOnDuty()
    return vCore.PlayerData.onDuty or false
end

---Retourne l'argent du joueur
---@param moneyType? string
---@return number|table
function vCore.Player.GetMoney(moneyType)
    if moneyType then
        return vCore.PlayerData.money and vCore.PlayerData.money[moneyType] or 0
    end
    return vCore.PlayerData.money or {}
end

---Retourne un status
---@param statusType string
---@return number
function vCore.Player.GetStatus(statusType)
    return vCore.PlayerData.status and vCore.PlayerData.status[statusType] or 0
end

---Vérifie si le joueur est admin
---@return boolean
function vCore.Player.IsAdmin()
    local group = vCore.PlayerData.group or 'user'
    local level = Config.Admin.Groups[group] or 0
    return level >= vCore.AdminLevel.ADMIN
end

---Retourne le groupe du joueur
---@return string
function vCore.Player.GetGroup()
    return vCore.PlayerData.group or 'user'
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS PED
-- ═══════════════════════════════════════════════════════════════════════════

---Vérifie si le joueur est mort
---@return boolean
function vCore.Player.IsDead()
    return IsEntityDead(PlayerPedId()) or IsPedDeadOrDying(PlayerPedId(), true)
end

---Vérifie si le joueur est dans un véhicule
---@return boolean
function vCore.Player.InVehicle()
    return IsPedInAnyVehicle(PlayerPedId(), false)
end

---Retourne le véhicule actuel
---@return number
function vCore.Player.GetVehicle()
    return GetVehiclePedIsIn(PlayerPedId(), false)
end

---Vérifie si le joueur est le conducteur
---@return boolean
function vCore.Player.IsDriver()
    local vehicle = vCore.Player.GetVehicle()
    if vehicle == 0 then return false end
    return GetPedInVehicleSeat(vehicle, -1) == PlayerPedId()
end

---Vérifie si le joueur vise
---@return boolean
function vCore.Player.IsAiming()
    return IsPlayerFreeAiming(PlayerId())
end

---Vérifie si le joueur tire
---@return boolean
function vCore.Player.IsShooting()
    return IsPedShooting(PlayerPedId())
end

---Retourne l'arme actuelle
---@return number hash
function vCore.Player.GetWeapon()
    local _, hash = GetCurrentPedWeapon(PlayerPedId(), true)
    return hash
end

---Vérifie si le joueur a une arme en main
---@return boolean
function vCore.Player.HasWeapon()
    local hash = vCore.Player.GetWeapon()
    return hash ~= GetHashKey('WEAPON_UNARMED')
end

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTIONS POSITION
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne les coordonnées du joueur
---@return vector3
function vCore.Player.GetCoords()
    return GetEntityCoords(PlayerPedId())
end

---Retourne le heading du joueur
---@return number
function vCore.Player.GetHeading()
    return GetEntityHeading(PlayerPedId())
end

---Retourne la rue actuelle
---@return string, string
function vCore.Player.GetStreet()
    local coords = vCore.Player.GetCoords()
    local street, crossing = GetStreetNameAtCoord(coords.x, coords.y, coords.z)
    return GetStreetNameFromHashKey(street), GetStreetNameFromHashKey(crossing)
end

---Retourne la zone actuelle
---@return string
function vCore.Player.GetZone()
    local coords = vCore.Player.GetCoords()
    return GetLabelText(GetNameOfZone(coords.x, coords.y, coords.z))
end

-- ═══════════════════════════════════════════════════════════════════════════
-- JOUEURS PROCHES
-- ═══════════════════════════════════════════════════════════════════════════

---Retourne les joueurs proches
---@param radius? number
---@return table
function vCore.Player.GetNearbyPlayers(radius)
    radius = radius or 5.0
    local players = {}
    local myCoords = vCore.Player.GetCoords()
    local myId = PlayerId()
    
    for _, player in ipairs(GetActivePlayers()) do
        if player ~= myId then
            local ped = GetPlayerPed(player)
            local coords = GetEntityCoords(ped)
            local dist = #(myCoords - coords)
            
            if dist <= radius then
                table.insert(players, {
                    id = player,
                    serverId = GetPlayerServerId(player),
                    ped = ped,
                    coords = coords,
                    distance = dist
                })
            end
        end
    end
    
    -- Trier par distance
    table.sort(players, function(a, b)
        return a.distance < b.distance
    end)
    
    return players
end

---Retourne le joueur le plus proche
---@param radius? number
---@return table|nil
function vCore.Player.GetClosestPlayer(radius)
    local players = vCore.Player.GetNearbyPlayers(radius)
    return players[1]
end

-- ═══════════════════════════════════════════════════════════════════════════
-- KEYBINDS
-- ═══════════════════════════════════════════════════════════════════════════

-- Toggle duty (F6)
RegisterCommand('+toggleDuty', function()
    if not vCore.IsLoaded then return end
    TriggerServerEvent('vCore:toggleDuty')
end, false)

RegisterKeyMapping('+toggleDuty', 'Prise/Fin de service', 'keyboard', 'F6')
