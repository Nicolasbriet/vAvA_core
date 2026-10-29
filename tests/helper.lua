--[[
    tests/helper.lua
    Rôle : charge des fichiers Lua du dépôt hors de FiveM pour les tests unitaires (busted).
           Fournit des doublures minimales des natives utilisées au chargement. Seule la logique pure
           (shared/, formules, validations) se teste ici ; tout ce qui touche au jeu se teste en jeu.
]]

local helper = {}

local ROOT = os.getenv('VAVA_ROOT') or '.'

-- natives appelées au chargement des fichiers partagés
local stubs = {
    GetCurrentResourceName = function() return 'vAvA_core' end,
    GetResourceMetadata = function() return '0.0.0' end,
    IsDuplicityVersion = function() return true end,
    GetGameTimer = function() return math.floor(os.clock() * 1000) end,
    Wait = function() end,
    CreateThread = function(fn) fn() end,
}

--- Remet l'environnement global à zéro puis pose les doublures.
function helper.reset()
    vAvA = nil
    for name, fn in pairs(stubs) do _G[name] = fn end
end

--- Charge un fichier du dépôt (chemin relatif à la racine).
---@param path string
function helper.load(path)
    local chunk, err = loadfile(ROOT .. '/' .. path)
    if not chunk then error(err, 2) end
    return chunk()
end

--- Charge plusieurs fichiers dans l'ordre, comme le ferait un fxmanifest.
---@param paths string[]
function helper.loadAll(paths)
    for _, path in ipairs(paths) do helper.load(path) end
end

return helper
