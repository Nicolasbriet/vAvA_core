-- Lint de vAvA (Lua 5.4 / FiveM). Lancé par scripts/verifier.sh et la CI.
-- Les natives FiveM sont des milliers de globales en CamelCase : luacheck ne sait pas les lister par motif,
-- donc l'accès aux globales non définies (113) est ignoré. Ce qui reste vérifié compte : erreurs de syntaxe,
-- variables inutilisées, masquage, globales ÉCRITES par erreur (111/112), code mort, boucles vides.
std = 'lua54'
max_line_length = 120
codes = true
ignore = {
    '113',          -- accès à une globale non définie (natives FiveM)
    '212/self',     -- self inutilisé dans les méthodes
    '631',          -- longueur de ligne gérée par max_line_length
}
-- Globales qu'une ressource a le droit de créer : sa table de module, et rien d'autre.
globals = {
    'vAvA',
    'VavaAdmin', 'VavaAppearance', 'VavaArrival', 'VavaCameras', 'VavaChancellerie', 'VavaCharactersUi', 'VavaChat',
    'VavaCodex', 'VavaCrafting', 'VavaFarming', 'VavaGathering', 'VavaHealth', 'VavaHud', 'VavaInventory',
    'VavaLoading', 'VavaMagic', 'VavaNeeds', 'VavaProvisions', 'VavaSkills', 'VavaTime', 'VavaVoice', 'VavaWorld',
    'VavaAtelier', 'VavaCombat',
    'VavaBridge', 'VavaExample', 'VavaAnimTest', 'VavaDevCharacters', 'VavaExampleAtelier', 'VavaExampleCombat',
    'exports',
}
exclude_files = { 'chancellerie/**', '**/web/**', 'tests/**', '.outils/**', '.claude/**' }
files['**/fxmanifest.lua'] = { ignore = { '111', '112', '113', '611', '612' }, allow_defined_top = true }
files['**/config.lua'] = { max_line_length = 160 }
