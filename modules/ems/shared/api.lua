-- ========================================
-- API PUBLIQUE vAvA_ems
-- ========================================

-- Cette API permet aux autres ressources d'interagir avec le système EMS

if IsDuplicityVersion() then
    -- CÔTÉ SERVEUR
    
    ---@param source number L'ID du joueur
    ---@return table|nil Les données médicales du joueur
    function GetPlayerMedicalState(source)
        return exports['vAvA_ems']:GetPlayerMedicalState(source)
    end
    
    ---@param source number L'ID du joueur
    ---@param state string L'état médical (voir EMSConfig.MedicalStates)
    ---@return boolean Succès de l'opération
    function SetPlayerMedicalState(source, state)
        return exports['vAvA_ems']:SetPlayerMedicalState(source, state)
    end
    
    ---@param source number L'ID du joueur
    ---@param injuryType string Type de blessure
    ---@param bodyPart string Partie du corps
    ---@param severity number Sévérité (1-4)
    ---@return boolean Succès de l'opération
    function AddInjury(source, injuryType, bodyPart, severity)
        return exports['vAvA_ems']:AddInjury(source, injuryType, bodyPart, severity)
    end
    
    ---@param source number L'ID du joueur
    ---@param injuryId number L'ID de la blessure
    ---@return boolean Succès de l'opération
    function RemoveInjury(source, injuryId)
        return exports['vAvA_ems']:RemoveInjury(source, injuryId)
    end
    
    ---@param source number L'ID du joueur
    ---@return table|nil Les signes vitaux du joueur
    function GetVitalSigns(source)
        return exports['vAvA_ems']:GetVitalSigns(source)
    end
    
    ---@param source number L'ID du joueur
    ---@param vitalSign string Le signe vital à modifier
    ---@param value number La nouvelle valeur
    ---@return boolean Succès de l'opération
    function SetVitalSign(source, vitalSign, value)
        return exports['vAvA_ems']:SetVitalSign(source, vitalSign, value)
    end
    
    ---@param source number L'ID du joueur
    ---@return string|nil Le groupe sanguin du joueur
    function GetBloodType(source)
        return exports['vAvA_ems']:GetBloodType(source)
    end
    
    ---@param source number L'ID du joueur
    ---@param bloodType string Le nouveau groupe sanguin
    ---@return boolean Succès de l'opération
    function SetBloodType(source, bloodType)
        return exports['vAvA_ems']:SetBloodType(source, bloodType)
    end
    
    ---@param bloodType string|nil Le groupe sanguin (optionnel)
    ---@return number|table Le nombre d'unités ou tout le stock
    function GetBloodStock(bloodType)
        return exports['vAvA_ems']:GetBloodStock(bloodType)
    end
    
    ---@param bloodType string Le groupe sanguin
    ---@param units number Nombre d'unités à ajouter
    ---@return boolean Succès de l'opération
    function AddBloodStock(bloodType, units)
        return exports['vAvA_ems']:AddBloodStock(bloodType, units)
    end
    
    ---@param bloodType string Le groupe sanguin
    ---@param units number Nombre d'unités à retirer
    ---@return boolean Succès de l'opération
    function RemoveBloodStock(bloodType, units)
        return exports['vAvA_ems']:RemoveBloodStock(bloodType, units)
    end
    
    ---@param source number L'ID du médecin
    ---@param targetSource number L'ID du patient
    ---@param bloodType string Le groupe sanguin à transfuser
    ---@return boolean Succès de l'opération
    function TransfuseBlood(source, targetSource, bloodType)
        return exports['vAvA_ems']:TransfuseBlood(source, targetSource, bloodType)
    end
    
    ---@param source number L'ID de l'appelant
    ---@param callType string Type d'appel (RED, ORANGE, YELLOW, BLUE)
    ---@param message string Message de l'appel
    ---@return number L'ID de l'appel créé
    function CreateEmergencyCall(source, callType, message)
        return exports['vAvA_ems']:CreateEmergencyCall(source, callType, message)
    end
    
    ---@return table Tous les appels d'urgence actifs
    function GetActiveCalls()
        return exports['vAvA_ems']:GetActiveCalls()
    end
    
else
    -- CÔTÉ CLIENT
    
    ---@return table|nil L'état médical local du joueur
    function GetLocalMedicalState()
        return exports['vAvA_ems']:GetLocalMedicalState()
    end
    
    ---Ouvre le menu EMS principal
    function OpenEMSMenu()
        exports['vAvA_ems']:OpenEMSMenu()
    end
    
    ---@param targetId number L'ID du patient à diagnostiquer
    function OpenPatientDiagnosis(targetId)
        exports['vAvA_ems']:OpenPatientDiagnosis(targetId)
    end
    
    ---@param equipmentName string Le nom de l'équipement
    ---@param targetId number L'ID de la cible
    function UseEquipment(equipmentName, targetId)
        exports['vAvA_ems']:UseEquipment(equipmentName, targetId)
    end
end

-- ========================================
-- EXEMPLES D'UTILISATION
-- ========================================

--[[

CÔTÉ SERVEUR:

-- Ajouter une blessure après un accident de voiture
RegisterNetEvent('myResource:carCrash', function()
    local source = source
    AddInjury(source, 'contusion', 'head', 2)
    AddInjury(source, 'open_wound', 'chest', 3)
end)

-- Réduire le volume sanguin lors d'une fusillade
RegisterNetEvent('myResource:shotReceived', function()
    local source = source
    local vitals = GetVitalSigns(source)
    if vitals then
        local newVolume = math.max(0, vitals.bloodVolume - 15)
        SetVitalSign(source, 'bloodVolume', newVolume)
    end
    AddInjury(source, 'gunshot_entry', 'abdomen', 4)
end)

-- Vérifier si un joueur est en état critique
local state = GetPlayerMedicalState(source)
if state and (state.state == 'cardiac_arrest' or state.state == 'unconscious') then
    print('Joueur en état critique!')
end

-- Ajouter du sang au stock (don d'un PNJ)
AddBloodStock('O+', 5)

-- Créer un appel d'urgence automatique
CreateEmergencyCall(source, 'RED', 'Accident majeur sur l\'autoroute')


CÔTÉ CLIENT:

-- Obtenir l'état médical local
local myState = GetLocalMedicalState()
if myState then
    print('Mon volume sanguin: ' .. myState.vitalSigns.bloodVolume .. '%')
end

-- Ouvrir le menu EMS (pour les EMS)
RegisterCommand('emsm', function()
    OpenEMSMenu()
end)

-- Diagnostiquer le joueur le plus proche
local closestPlayer = GetClosestPlayer()
if closestPlayer ~= -1 then
    local targetId = GetPlayerServerId(closestPlayer)
    OpenPatientDiagnosis(targetId)
end

]]
