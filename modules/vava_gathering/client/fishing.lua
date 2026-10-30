--[[
    vava_gathering/client/fishing.lua
    Rôle : la pêche côté joueur, après la touche annoncée par le serveur : la barre de tension est jouée par
           l'interface (une aiguille montée en tenant la touche, une zone qui dérive) ; le client lui transmet
           l'appui et le relâchement de la touche d'interaction (commandes +/− du jeu : la touche reste celle que le
           joueur a choisie) et, à la fin, déclare au serveur si la ligne a été tenue. Seul un raté est cru : ligne
           tenue, le serveur tire encore la prise. Aucune boucle Lua : l'interface anime la barre tant qu'elle est
           visible, le jeu envoie les appuis.
    Dépendances : shared/constants.lua, config.lua, client/core.lua, client/nui.lua, client/interact.lua
]]

local type = type
local tointeger, tonumber = math.tointeger, tonumber

local core = VavaGathering.core
if not core then return end

local cfg = VavaGathering.config
local nui = VavaGathering.nui
local interact = VavaGathering.interact

local fishing = {}
VavaGathering.fishing = fishing

-- barre en cours : { token, holdRatio }
local active = nil

--- La touche (évènement du serveur) : la barre de tension démarre avec les réglages reçus.
---@param payload table  { token, tension = { durationMs, zoneMin, zoneMax, drift, pull, gravity, holdRatio } }
function fishing.onBite(payload)
    if type(payload) ~= 'table' or type(payload.tension) ~= 'table' then return end
    local token = tointeger(tonumber(payload.token))
    if not token or not interact.bite(token) then return end
    active = { token = token, holdRatio = payload.tension.holdRatio or cfg.fishing.tension.holdRatio }
    nui.send('tension', { token = token, tension = payload.tension, key = cfg.keys.interact })
end

--- Appui ou relâchement de la touche pendant la barre.
---@param held boolean
function fishing.hold(held)
    if active then nui.send('tensionHold', { held = held }) end
end

--- Fin de la barre (retour de l'interface) : part du temps tenue dans la zone → tenue réussie ou non, déclarée au
--- serveur, qui tire la prise (une ligne relâchée la fait toujours rater, une ligne tenue ne l'assure pas).
---@param data table  { token, ratio }
function fishing.done(data)
    local token = tointeger(tonumber(data.token))
    if not active or not token or active.token ~= token then return end
    local ratio = tonumber(data.ratio) or 0
    local held = ratio >= active.holdRatio
    active = nil
    interact.reel(token, held)
end

--- La session s'est arrêtée autrement (déplacement, départ) : la barre est oubliée.
function fishing.stop()
    active = nil
end

---@return boolean
function fishing.active()
    return active ~= nil
end
