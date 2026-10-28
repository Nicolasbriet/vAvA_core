--[[
    vava_chat/fxmanifest.lua
    Rôle : chat du royaume, à la place de la ressource « chat » de FiveM (mêmes évènements : les autres ressources
           marchent sans changement) : /ooc (hors-RP à 20 m, aussi le texte tapé sans commande dans Général), /me et
           /do (à 15 m, dans le chat et au-dessus de la tête), /mp et /r (privés), /staff (Conseil) ; onglets Général,
           Actions, Conseil et un par correspondant ; fenêtre déplaçable et agrandissable, gardée sur le PC du joueur ;
           journal de modération en base (/ooc, /mp, /staff, 7 jours). Le serveur choisit chaque destinataire :
           aucun message n'est envoyé à tout le serveur.
    Dépendances : vAvA_core ≥ 0.5.0 ; facultative : vava_admin (canal du Conseil, rangs)
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'
use_experimental_fxv2_oal 'yes'

name 'vava_chat'
description 'Chat vAvA : hors-RP, /me, /do, messages privés, Conseil, onglets'
version '1.1.0'

dependency 'vAvA_core'
-- remplace la ressource « chat » : une ressource qui en dépend démarre avec celle-ci
provide 'chat'

vava_migration 'sql/0001_chat.sql'

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/css/*.css',
    'web/js/*.js',
    'web/fonts/*.woff2',
    'web/img/*',
}

-- Ordre explicite : chaque fichier ne dépend que de ceux listés avant lui.
shared_scripts {
    'shared/constants.lua',
    'config.lua',
    'shared/text.lua',
}

server_scripts {
    'server/core.lua',
    'server/links.lua',
    'server/sessions.lua',
    'server/audience.lua',
    'server/logs.lua',
    'server/messages.lua',
    'server/compat.lua',
    'server/api.lua',
    'server/commands.lua',
    'server/main.lua',
}

client_scripts {
    'client/core.lua',
    'client/nui.lua',
    'client/layout.lua',
    'client/suggestions.lua',
    'client/compat.lua',
    'client/outbox.lua',
    'client/commands.lua',
    'client/overhead.lua',
    'client/input.lua',
    'client/visibility.lua',
    'client/main.lua',
}
