--[[
    tests/audit/fxmanifest.lua
    Rôle : cas écrits pour `./scripts/audit-reseau.sh --essai` (jamais chargé, ni linté, ni audité en mode normal) :
           motifs livrés d'un manifeste qui couvriraient web/dev/ (données simulées, T-012) ; config.lua servi aux
           joueurs, config_client.lua servi au seul serveur (T-132). Chaque ligne qui compte finit par ce que l'audit
           doit en dire. Un bloc de commentaire ne compte pas : 'web/dev/devmock.js', 'web/**', 'config.lua'
]]

ui_page 'web/index.html'  -- attendu: rien

files {
    'web/index.html',  -- attendu: rien
    'web/css/*.css',  -- attendu: rien
    'web/js/*.js',  -- attendu: rien
    'web/img/*',  -- attendu: rien
    'web/devices.js',  -- attendu: rien
    'web/items/*.svg', -- pas 'web/**' : un commentaire de fin de ligne ne compte pas  -- attendu: rien
    'web/**',  -- attendu: BLOQUANT
    'web/**/*.js',  -- attendu: BLOQUANT
    'web/*/devmock.js',  -- attendu: BLOQUANT
    'web/*/*',  -- attendu: BLOQUANT
    'web/d?v/*.js',  -- attendu: BLOQUANT
    'web/dev/devmock.js',  -- attendu: BLOQUANT
    "web/dev/*.js",  -- attendu: BLOQUANT
    'web/dev',  -- attendu: BLOQUANT
    '*/dev/devmock.js',  -- attendu: BLOQUANT
    'stream/*/props.ydr',  -- attendu: rien
    -- chaînes normalisées avant le test (relecture : `./` en tête, `\` Windows, `/./`)
    './web/dev/devmock.js',  -- attendu: BLOQUANT
    'web\\dev\\devmock.js',  -- attendu: BLOQUANT
    'web/./dev/devmock.js',  -- attendu: BLOQUANT
    -- chaînes longues
    [[web/dev/devmock.js]],  -- attendu: BLOQUANT
    [==[web/js/*.js]==],  -- attendu: rien
    [=[ -- attendu: BLOQUANT
web/**
]=],
    -- joker en dernière partie qui peut valoir `dev`
    'web/de?',  -- attendu: BLOQUANT
    'web/dev*',  -- attendu: BLOQUANT
    'web/*',  -- attendu: BLOQUANT
    'web/[d]ev/x.js',  -- attendu: BLOQUANT
    'web/[!d]ev',  -- attendu: rien
    'web/*.js',  -- attendu: rien
    { 'web/sous/tableau/**' },  -- attendu: BLOQUANT
}
-- seules les chaînes de files, file, ui_page et loadscreen comptent (relecture réseau 2)
client_scripts { 'client/**/*.lua' }  -- attendu: rien
shared_script 'web/**'  -- attendu: rien
loadscreen 'web/dev/ecran.html'  -- attendu: BLOQUANT
files { 'web/index.html' } client_script 'web/**'  -- attendu: rien
-- files { 'web/dev/devmock.js' }  -- attendu: rien
file 'web/dev/horsjeu.js'  -- attendu: BLOQUANT
--[==[ bloc de commentaire sur plusieurs lignes
    'web/**'  -- attendu: rien
]==] file 'web/*/x.js'  -- attendu: BLOQUANT
--[[ bloc fermé sur la même ligne ]] file 'web/**'  -- attendu: BLOQUANT
--[[ 'web/**' ]] file 'web/index.html'  -- attendu: rien

-- T-132 : config.lua jamais servi aux joueurs ; config_client.lua jamais au seul serveur
shared_scripts {
    'shared/constants.lua',  -- attendu: rien
    'config_client.lua',  -- attendu: rien
    'config.lua',  -- attendu: BLOQUANT
    './config.lua',  -- attendu: BLOQUANT
    '*.lua',  -- attendu: BLOQUANT
    'config.*',  -- attendu: BLOQUANT
    'conf?g.lua',  -- attendu: BLOQUANT
    '**/*.lua',  -- attendu: BLOQUANT
    '@vava_autre/config.lua',  -- attendu: BLOQUANT
    'shared/config.lua',  -- attendu: rien
    'config_client.lua.bak',  -- attendu: rien
}
client_script 'config.lua'  -- attendu: BLOQUANT
client_scripts { 'config_client.lua', 'client/main.lua' }  -- attendu: rien
files { 'config.lua' }  -- attendu: BLOQUANT
server_scripts {
    'config.lua',  -- attendu: rien
    'config_client.lua',  -- attendu: BLOQUANT
    'shared/rules.lua',  -- attendu: rien
}
server_script 'config_client.lua'  -- attendu: BLOQUANT
server_scripts { '*.lua' }  -- attendu: BLOQUANT
-- shared_script 'config.lua'  -- attendu: rien
--[[ client_script 'config.lua' ]] client_script 'client/a.lua'  -- attendu: rien
shared_scripts { 'config.lua' } -- exception transitoire  -- attendu: rien
-- relecture : une table imbriquée garde sa directive ; deux directives sur une ligne
client_scripts { { 'config.lua' } }  -- attendu: BLOQUANT
server_scripts { 'config.lua' } shared_script 'config.lua'  -- attendu: BLOQUANT
-- relecture sécurité S-6 : ui_page et loadscreen servent aussi le fichier aux joueurs
ui_page 'config.lua'  -- attendu: BLOQUANT
loadscreen 'config.lua'  -- attendu: BLOQUANT
-- relecture sécurité S-1 : casse (NTFS), `..`, valeur calculée
shared_script 'Config.lua'  -- attendu: BLOQUANT
client_script 'CONFIG.LUA'  -- attendu: BLOQUANT
server_script 'Config_Client.lua'  -- attendu: BLOQUANT
client_script 'shared/../config.lua'  -- attendu: BLOQUANT
client_script 'client/x/../../config.lua'  -- attendu: BLOQUANT
files { 'web/x/../dev/devmock.js' }  -- attendu: BLOQUANT
server_script 'server/../server/main.lua'  -- attendu: rien
shared_script '../config.lua'  -- attendu: BLOQUANT
client_script '../vava_autre/client/a.lua'  -- attendu: BLOQUANT
shared_script 'con' .. 'fig.lua'  -- attendu: BLOQUANT
shared_scripts(liste)  -- attendu: BLOQUANT
shared_scripts liste  -- attendu: BLOQUANT
client_scripts { 'client/a.lua', autre }  -- attendu: BLOQUANT
client_scripts { 'client/' .. 'a.lua' }  -- attendu: BLOQUANT
client_scripts { 'client/a.lua'; 'client/b.lua' }  -- attendu: rien
client_script('client/a.lua')  -- attendu: rien
dependencies { 'vAvA_core', nom }  -- attendu: rien
-- relecture sécurité S-2 : « audit: ok » ne fait pas taire les règles des manifestes
shared_script 'config.lua' -- audit: ok  -- attendu: BLOQUANT
