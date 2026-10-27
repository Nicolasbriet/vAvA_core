--[[
    vava_chancellerie/shared/constants.lua
    Rôle : table du module (seule globale de la ressource) et constantes de protocole.
    Dépendances : aucune
]]

VavaBridge = {}

-- Modules reliés.
VavaBridge.ADMIN = 'vava_admin'
VavaBridge.VOICE = 'vava_voice'
VavaBridge.CAMERAS = 'vava_cameras'
VavaBridge.ADMIN_REPORT = 'vava_admin:report'
-- message à un joueur, affiché par vava_admin : { text, kind, title? }
VavaBridge.ADMIN_NOTIFY = 'vava_admin:notify'
-- offres et fins des caméras regardées depuis le web
VavaBridge.CAMERAS_WEB = 'vava_cameras:web'
