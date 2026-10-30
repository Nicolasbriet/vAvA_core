--[[
    client/init.lua
    Rôle : démarrage du core côté client. Seul fichier client à effets de bord : niveau de log, net events,
           export, mise en attente du joueur jusqu'à la sélection d'un personnage, nettoyage à l'arrêt d'une
           ressource cliente. Aucun thread permanent.
    Dépendances : shared/, client/core/, client/players/
]]

local tostring = tostring
local AddEventHandler = AddEventHandler

local logger = vAvA.logger
local hooks = vAvA.hooks
local rpc = vAvA.rpc
local api = vAvA.api
local session = vAvA.session
local spawn = vAvA.spawn
local netprobe = vAvA.netprobe
local zones = vAvA.zones
local log = logger.create('core')

local clientLevel = vAvA.config.shared.log.clientLevel
if not logger.setLevel(clientLevel) then
    log.warn("niveau de log client inconnu '%s' dans config/shared.lua : debug conservé", tostring(clientLevel))
end

rpc.start()
netprobe.start()
zones.start()
session.start()
spawn.start()
api.register()

AddEventHandler('onResourceStop', function(resource)
    if resource == vAvA.resourceName then return end
    hooks.purgeOwner(resource)
    rpc.purgeOwner(resource)
    -- zones du module oubliées sans notification (le serveur oublie aussi les siennes)
    zones.purgeOwner(resource)
    api.forget(resource)
end)
