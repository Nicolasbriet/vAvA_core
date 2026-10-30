--[[
    vava_provisions/client/nui.lua
    Rôle : SEUL fichier qui parle à la page : l'invite près d'un point d'eau, montrée (`{ action = 'prompt', key, verb,
           label }`) ou cachée (`{ action = 'prompt', hidden = true }`), envoyée seulement quand elle change. Aucun focus,
           aucun retour de la page.
    Dépendances : client/core.lua
]]

local SendNUIMessage = SendNUIMessage

local nui = {}
VavaProvisions.nui = nui

-- dernière invite envoyée : touche, verbe, nom (nil : cachée)
local shownKey, shownVerb, shownLabel = nil, nil, nil
local hidden = true

--- Montre l'invite (rien n'est envoyé si elle est déjà telle quelle).
---@param key string
---@param verb string
---@param label string
function nui.showPrompt(key, verb, label)
    if not hidden and shownKey == key and shownVerb == verb and shownLabel == label then return end
    shownKey, shownVerb, shownLabel, hidden = key, verb, label, false
    SendNUIMessage({ action = 'prompt', key = key, verb = verb, label = label })
end

--- Cache l'invite (rien n'est envoyé si elle l'est déjà).
function nui.hidePrompt()
    if hidden then return end
    shownKey, shownVerb, shownLabel, hidden = nil, nil, nil, true
    SendNUIMessage({ action = 'prompt', hidden = true })
end
