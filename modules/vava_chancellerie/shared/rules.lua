--[[
    vava_chancellerie/shared/rules.lua
    Rôle : règles pures du pont, testées hors jeu (tests/spec/chancellerie_rules_spec.lua) : forme de la clé reçue de
           la Chancellerie, rangs du Conseil qu'elle peut appliquer à un compte de jeu.
           Chargé côté serveur seulement (le pont n'a pas de partie client).
    Dépendances : shared/constants.lua
]]

local type, find = type, string.find

local rules = {}
VavaBridge.rules = rules

--- Clé du pont acceptable ? Une chaîne hexadécimale, de longueur bornée.
---@param value any
---@param min integer
---@param max integer
---@return boolean
function rules.validKey(value, min, max)
    return type(value) == 'string' and #value >= min and #value <= max and find(value, '^%x+$') ~= nil
end

--- Le panneau peut-il appliquer ce rang à ce compte de jeu ? Retirer un rang (`''`) : toujours, c'est le sens sûr ;
--- donner un rang : seulement à un compte que le pont a lui-même vu relié en jeu (code juste tapé par le joueur et
--- confirmé par la Chancellerie), jamais sur la seule parole de qui détient la clé.
---@param rankName any  '' : aucun rang (retrait)
---@param known boolean  compte vu relié en jeu
---@return boolean ok
---@return string|nil err  not_linked_in_game
function rules.canSync(rankName, known)
    if rankName == '' or known == true then return true end
    return false, 'not_linked_in_game'
end
