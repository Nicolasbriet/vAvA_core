--[[
    vava_arrival/shared/screen.lua
    Rôle : logique PURE dont se sert le client (aucune native, testée hors jeu : tests/spec/arrival_rules_spec.lua) :
           écran prêt pour l'accueil. Seul fichier de logique servi aux joueurs ; le reste (shared/rules.lua) est servi
           au seul serveur (T-132).
    Dépendances : shared/constants.lua
]]

local screen = {}
VavaArrival.screen = screen

--- Vrai si l'écran est prêt pour l'accueil : ni menu pause, ni interface qui a le focus, écran ouvert (fondu fini).
---@param state { paused: boolean, nuiFocused: boolean, fadedIn: boolean }
---@return boolean
function screen.ready(state)
    return state.paused ~= true and state.nuiFocused ~= true and state.fadedIn == true
end
