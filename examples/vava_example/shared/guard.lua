--[[
    vava_example/shared/guard.lua
    Rôle : garde des outils de développement, logique pure (testée dans tests/spec/examples_guard_spec.lua) :
      - mode développement : la convar serveur `vava_env` doit valoir exactement `dev` (`set vava_env dev`) ;
        absente ou autre valeur, le module refuse de démarrer et n'offre rien ;
      - accès d'un joueur : droit vava_admin donné en config (`staff` par défaut) ou ACE donnée en config
        (`vava.dev` par défaut), jamais autre chose.
    Même fichier dans vava_dev_characters et vava_anim_test (seuls le chemin et la dernière ligne changent) : les garder identiques.
    Dépendances : aucune
]]

local type = type

local guard = {
    CONVAR = 'vava_env',            -- convar serveur lue par GetConvar (pas de `setr` : rien n'est envoyé aux joueurs)
    DEV = 'dev',                    -- seule valeur qui ouvre les outils
    FALLBACK = 'prod',              -- valeur lue quand la convar est absente
    REFUSAL = 'mode développement absent (convar vava_env ≠ dev) : rien n\'est offert',
}

--- Vrai seulement si la convar vaut exactement `dev` (ni ` dev`, ni `DEV`, ni `development`).
---@param value any  valeur de GetConvar(guard.CONVAR, guard.FALLBACK)
---@return boolean
function guard.isDevMode(value)
    return value == guard.DEV
end

---@class vAvA.DevAccessFacts
---@field devMode boolean        convar relue à l'appel (un `set vava_env prod` en console ferme aussitôt les outils)
---@field adminStarted boolean   vava_admin tourne
---@field adminCalled boolean    l'appel à son export `can` n'a pas levé d'erreur
---@field adminCan any           ce qu'il a rendu (seul `true` compte)
---@field ace any                IsPlayerAceAllowed(source, ace) (seul `true` compte)

--- Accès d'un joueur aux outils : mode développement ET (droit vava_admin OU ACE). Tout ce qui n'est pas exactement
--- `true` refuse.
---@param facts vAvA.DevAccessFacts|nil
---@return boolean
function guard.allowed(facts)
    if type(facts) ~= 'table' or facts.devMode ~= true then return false end
    if facts.adminStarted == true and facts.adminCalled == true and facts.adminCan == true then return true end
    return facts.ace == true
end

VavaExample.guard = guard
