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
-- actions du Conseil : un rang donné ou retiré fait revérifier les caméras du web
VavaBridge.ADMIN_ACTION = 'vava_admin:action'
VavaBridge.STAFF_ACTIONS = { staffGrant = true, staffRevoke = true }

-- Clé du pont, jamais sur la ligne de commande de FXServer : le pont la demande en écrivant KEY_ASK dans la console ; la
-- Chancellerie, qui lit cette console, répond sur l'entrée de FXServer par « KEY_COMMAND <clé> », commande que seule la
-- console peut lancer. Protocole partagé avec chancellerie/lib/bridge.js : ne changer l'un qu'avec l'autre.
VavaBridge.KEY_COMMAND = 'vava_chancellerie_cle'
VavaBridge.KEY_ASK = 'vava_chancellerie:cle?'
