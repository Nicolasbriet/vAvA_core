--[[
    vAvA_core - Client Callbacks
    Système de callbacks vers le serveur
]]

vCore = vCore or {}

local serverCallbacks = {}
local currentRequestId = 0

-- ═══════════════════════════════════════════════════════════════════════════
-- FONCTION PRINCIPALE
-- ═══════════════════════════════════════════════════════════════════════════

---Déclenche un callback serveur
---@param name string
---@param callback function
---@param ... any
function vCore.TriggerCallback(name, callback, ...)
    currentRequestId = currentRequestId + 1
    serverCallbacks[currentRequestId] = callback
    
    TriggerServerEvent('vCore:triggerCallback', name, currentRequestId, ...)
end

---Alias pour compatibilité
vCore.ServerCallback = vCore.TriggerCallback

-- ═══════════════════════════════════════════════════════════════════════════
-- RÉPONSE DU SERVEUR
-- ═══════════════════════════════════════════════════════════════════════════

RegisterNetEvent('vCore:callbackResponse', function(requestId, ...)
    if serverCallbacks[requestId] then
        serverCallbacks[requestId](...)
        serverCallbacks[requestId] = nil
    end
end)

-- ═══════════════════════════════════════════════════════════════════════════
-- CALLBACKS SYNCHRONES (AWAIT)
-- ═══════════════════════════════════════════════════════════════════════════

---Déclenche un callback serveur et attend la réponse
---@param name string
---@param ... any
---@return any
function vCore.TriggerCallbackSync(name, ...)
    local result = nil
    local finished = false
    
    vCore.TriggerCallback(name, function(...)
        result = {...}
        finished = true
    end, ...)
    
    while not finished do
        Wait(0)
    end
    
    if result then
        return table.unpack(result)
    end
    
    return nil
end

---Alias pour compatibilité
vCore.Await = vCore.TriggerCallbackSync
