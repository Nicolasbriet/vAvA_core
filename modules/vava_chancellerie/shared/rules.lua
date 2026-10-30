--[[
    vava_chancellerie/shared/rules.lua
    Rôle : règles pures du pont, testées hors jeu (tests/spec/chancellerie_rules_spec.lua) : forme de la clé reçue de
           la Chancellerie et de son adresse, rangs du Conseil qu'elle peut appliquer à un compte de jeu, déliaison.
           Chargé côté serveur seulement (le pont n'a pas de partie client).
    Dépendances : shared/constants.lua
]]

local type, find, tonumber = type, string.find, tonumber

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

--- Ce retrait vient-il d'une déliaison (le compte du panneau n'est plus relié à ce joueur) ? Le pont oublie alors le
--- compte de jeu : il devra être relié de nouveau en jeu pour recevoir un rang.
---@param rankName any
---@param unlinked any
---@return boolean
function rules.forgetsLink(rankName, unlinked)
    return rankName == '' and unlinked == true
end

--- Adresse de la Chancellerie acceptable ? Seulement la machine elle-même : http://127.0.0.1:<port>, port 1 à 65535.
---@param value any
---@return boolean
function rules.validPanelUrl(value)
    if type(value) ~= 'string' then return false end
    local port = value:match('^http://127%.0%.0%.1:(%d%d?%d?%d?%d?)$')
    port = port and tonumber(port)
    return port ~= nil and port >= 1 and port <= 65535
end
