--[[
    vava_example_atelier/shared/guard.lua
    Rôle : garde du mode développement, logique pure (testée dans tests/spec/examples_atelier_spec.lua) : la convar
           serveur `vava_env` doit valoir exactement `dev` (`set vava_env dev`) ; absente ou autre valeur, le module
           refuse de démarrer et ne déclare rien. Forme de examples/vava_example/shared/guard.lua ; l'accès d'un
           membre est ensuite celui de l'Atelier (droit effectif de l'atelier, relu à chaque appel).
    Dépendances : config.lua
]]

local guard = {
    CONVAR = 'vava_env',            -- convar serveur lue par GetConvar (pas de `setr` : rien n'est envoyé aux joueurs)
    DEV = 'dev',                    -- seule valeur qui ouvre l'exemple
    FALLBACK = 'prod',              -- valeur lue quand la convar est absente
    REFUSAL = 'mode développement absent (convar vava_env ≠ dev) : aucun atelier d\'exemple déclaré',
}

--- Vrai seulement si la convar vaut exactement `dev` (ni ` dev`, ni `DEV`, ni `development`).
---@param value any  valeur de GetConvar(guard.CONVAR, guard.FALLBACK)
---@return boolean
function guard.isDevMode(value)
    return value == guard.DEV
end

VavaExampleAtelier.guard = guard
