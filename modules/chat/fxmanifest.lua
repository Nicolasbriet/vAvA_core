--[[
    vAvA_chat - Système de Chat RP Intégré
    Version: 1.0.0 - Module vAvA_core
    Adapté de vAvA_chat standalone
]]

fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vAvA_chat'
author 'vAvA'
description 'Système de chat RP complet avec commandes /me, /do, /ooc, /mp, /police, /ems, /staff'
version '1.1.0'

shared_scripts {
    'config.lua',
    'locales/*.lua'
}
client_script 'client/main.lua'
server_script 'server/main.lua'

ui_page 'html/index.html'

files {
    'html/index.html',
    'html/style.css',
    'html/app.js',
    'html/config.js'
}
