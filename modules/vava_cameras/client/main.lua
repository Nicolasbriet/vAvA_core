--[[
    vava_cameras/client/main.lua
    Rôle : assemblage côté client : commande et outil du Registre pour ouvrir le mur, mur fermé quand le personnage
           quitte le jeu ou que la ressource s'arrête (focus rendu).
    Dépendances : shared/constants.lua, config_client.lua, tous les fichiers client/ du module
]]

local type = type
local CreateThread, RegisterCommand, AddEventHandler = CreateThread, RegisterCommand, AddEventHandler

local core = VavaCameras.core
if not core then return end

local nui, wall = VavaCameras.nui, VavaCameras.wall
local ADMIN = VavaCameras.ADMIN

-- outil « Mur des caméras » ouvert depuis le Registre du Conseil
core.hooks.after(ADMIN.OPENED, function(payload)
    if type(payload) == 'table' and payload.key == ADMIN.TOOL then CreateThread(wall.open) end
end)

core.hooks.after('core:character:selection', wall.close)
core.hooks.after('core:character:unloaded', wall.close)

RegisterCommand(VavaCameras.config.wall.command, function()
    CreateThread(wall.open)
end, false)

AddEventHandler('onResourceStop', function(resource)
    if resource == VavaCameras.resource and wall.isOpen() then nui.setFocus(false) end
end)
