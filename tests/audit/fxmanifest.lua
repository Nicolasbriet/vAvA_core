--[[
    tests/audit/fxmanifest.lua
    Rôle : cas écrits pour `./scripts/audit-reseau.sh --essai` (jamais chargé, ni linté, ni audité en mode normal) :
           motifs livrés d'un manifeste qui couvriraient web/dev/ (données simulées, T-012). Chaque ligne qui compte
           finit par ce que l'audit doit en dire. Un bloc de commentaire ne compte pas : 'web/dev/devmock.js', 'web/**'
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
}
-- files { 'web/dev/devmock.js' }  -- attendu: rien
file 'web/dev/horsjeu.js'  -- attendu: BLOQUANT
--[==[ bloc de commentaire sur plusieurs lignes
    'web/**'  -- attendu: rien
]==] file 'web/*/x.js'  -- attendu: BLOQUANT
--[[ bloc fermé sur la même ligne ]] file 'web/**'  -- attendu: BLOQUANT
--[[ 'web/**' ]] file 'web/index.html'  -- attendu: rien
