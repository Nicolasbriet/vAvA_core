--[[
    vava_hud/client/nui.lua
    Rôle : pont vers l'interface web. La page se charge en arrière-plan à l'arrivée du joueur : rien n'est envoyé
           avant qu'elle se dise prête (un message plus tôt serait perdu) ; elle reçoit alors l'état complet.
    Dépendances : client/core.lua
]]

local SendNUIMessage, RegisterNUICallback = SendNUIMessage, RegisterNUICallback

local nui = {}
VavaHud.nui = nui

local ready = false

---@param action string
---@param payload table
function nui.send(action, payload)
    if ready then SendNUIMessage({ action = action, payload = payload }) end
end

--- `snapshot` renvoie l'état complet, envoyé dès que la page est prête (et à chaque rechargement de la page).
---@param snapshot fun(): table
function nui.onReady(snapshot)
    RegisterNUICallback('ready', function(_, cb)
        ready = true
        cb({ ok = true })
        SendNUIMessage({ action = 'init', payload = snapshot() })
    end)
end
