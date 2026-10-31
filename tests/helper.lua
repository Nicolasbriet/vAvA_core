--[[
    tests/helper.lua
    Rôle : charge des fichiers Lua du dépôt hors de FiveM pour les tests unitaires (busted).
           Fournit des doublures minimales des natives utilisées au chargement. Seule la logique pure
           (shared/, formules, validations) se teste ici ; tout ce qui touche au jeu se teste en jeu.
]]

local helper = {}

local ROOT = os.getenv('VAVA_ROOT') or '.'

-- Minuteries posées par SetTimeout depuis le dernier reset : { ms, fn }. Rien ne les déclenche tout seul,
-- un test appelle lui-même helper.timers[i].fn() pour simuler l'échéance.
helper.timers = {}

--- Promesse du runtime FiveM réduite à l'essentiel : une seule résolution, gardée telle quelle.
local function newPromise()
    local p = { resolved = false }
    function p:resolve(value)
        if self.resolved then return end
        self.resolved, self.value = true, value
    end
    return p
end

-- natives et objets du runtime FiveM lus au chargement des fichiers partagés
local stubs = {
    GetCurrentResourceName = function() return 'vAvA_core' end,
    GetResourceMetadata = function() return '0.0.0' end,
    IsDuplicityVersion = function() return true end,
    GetGameTimer = function() return math.floor(os.clock() * 1000) end,
    Wait = function() end,
    CreateThread = function(fn) fn() end,
    -- shared/lib/pending.lua
    SetTimeout = function(ms, fn) helper.timers[#helper.timers + 1] = { ms = ms, fn = fn } end,
    promise = { new = newPromise },
    Citizen = {
        -- hors jeu il n'y a pas de planificateur : attendre une promesse non résolue est une erreur du test
        Await = function(p)
            if not p.resolved then error('doublure Citizen.Await : promesse non résolue', 2) end
            return p.value
        end,
    },
}

--- Remet l'environnement global à zéro puis pose les doublures.
function helper.reset()
    vAvA = nil
    helper.timers = {}
    for name, fn in pairs(stubs) do _G[name] = fn end
end

-- Locales Windows à octet unique, sous lesquelles %c, %s et string.lower prennent des octets de caractères UTF-8
-- (« Á », « í », le 0xA0 de « à ») : les essais de texte s'y lancent quand le système en a une (T-133).
local LEGACY_LOCALES = { '.1252', 'English_United States.1252', 'French_France.1252', 'fr_FR.ISO-8859-1' }

--- Passe la classification des caractères (`ctype`) sous la première locale de LEGACY_LOCALES que le système accepte.
--- Rend la locale d'avant (à redonner par helper.restoreLocale, dans un after_each) et celle obtenue (nil : aucune,
--- l'essai tourne alors sous la locale courante et fixe seulement la règle).
---@return string|nil previous
---@return string|nil legacy
function helper.legacyLocale()
    local previous = os.setlocale(nil, 'ctype')
    for _, name in ipairs(LEGACY_LOCALES) do
        local legacy = os.setlocale(name, 'ctype')
        if legacy then return previous, legacy end
    end
    return previous, nil
end

---@param previous string|nil  locale rendue par helper.legacyLocale ('C' si inconnue)
function helper.restoreLocale(previous)
    os.setlocale(previous or 'C', 'ctype')
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
