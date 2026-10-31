--[[
    server/players/playtime.lua
    Rôle : temps de jeu des personnages, compté CÔTÉ SERVEUR entre l'apparition confirmée par le serveur (0.14.0 : ped
           vu au point ordonné, server/players/spawn.lua) et le déchargement (la sélection et le temps entre deux
           apparitions ne comptent pas). Un marqueur par personnage ; le total, en secondes entières, est relevé dans
           la boucle des positions (aucune boucle propre), à chaque changement d'apparition et au déchargement, puis
           écrit avec le personnage (colonne play_seconds).
    Dépendances : shared/init.lua
]]

local GetGameTimer = GetGameTimer

local playtime = {}
vAvA.playtime = playtime

--- Reprend le compte : apparition confirmée par le serveur. Sans effet si le compte est déjà en cours.
---@param character vAvA.Character
function playtime.begin(character)
    if not character.playMarker then character.playMarker = GetGameTimer() end
end

--- Ajoute au total les secondes entières écoulées depuis le dernier relevé. Ne marque le personnage à sauvegarder
--- que si le total a changé.
---@param character vAvA.Character
---@return integer added
function playtime.settle(character)
    local marker = character.playMarker
    if not marker then return 0 end
    local seconds = (GetGameTimer() - marker) // 1000
    if seconds <= 0 then return 0 end
    character.playSeconds = character.playSeconds + seconds
    -- le reste de seconde n'est pas perdu : le marqueur n'avance que du temps compté
    character.playMarker = marker + seconds * 1000
    character.revision = character.revision + 1
    return seconds
end

--- Suspend le compte (réapparition, téléportation, déchargement) : relevé, puis marqueur retiré.
---@param character vAvA.Character
function playtime.pause(character)
    playtime.settle(character)
    character.playMarker = nil
end

--- Total courant en secondes entières, temps en cours compris.
---@param character vAvA.Character
---@return integer
function playtime.current(character)
    local marker = character.playMarker
    if not marker then return character.playSeconds end
    return character.playSeconds + (GetGameTimer() - marker) // 1000
end
