--[[
    vava_chancellerie/shared/rules.lua
    Rôle : règles pures du pont, testées hors jeu (tests/spec/chancellerie_rules_spec.lua) : forme de la clé reçue de
           la Chancellerie et de son adresse, rangs du Conseil qu'elle peut appliquer à un compte de jeu, déliaison,
           lecture du compteur réseau (forme de la demande, lignes du journal). Chargé côté serveur seulement (le pont n'a pas de partie client).
    Dépendances : shared/constants.lua
]]

local type, find, tonumber, tointeger = type, string.find, tonumber, math.tointeger

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

-- Compteur réseau (page Réseau) : nom de ressource comme core.net.stats l'accepte, numéro de joueur de FiveM.
local NET_RESOURCE_MAX = 48
local NET_RESOURCE_PATTERN = '^[%w_%-%.]+$'
local NET_PLAYER_MAX = 65535

--- Lecture du compteur réseau demandée par le panneau : `scope` = 'all' (valeur absente ou vide), 'resource' (nom de
--- ressource) ou 'player' (numéro de joueur, entier ou flottant entier venu du JSON) ; `opening` : ouverture de la page
--- (booléen, ou absent). Renvoie { scope, resource?, target?, opening }, ou nil, 'invalid_args'.
---@param scope any
---@param value any
---@param opening any
---@return table|nil query
---@return string|nil err
function rules.netQuery(scope, value, opening)
    if opening ~= nil and type(opening) ~= 'boolean' then return nil, 'invalid_args' end
    opening = opening == true
    if scope == 'all' then
        if value ~= nil and value ~= '' then return nil, 'invalid_args' end
        return { scope = 'all', opening = opening }
    end
    if scope == 'resource' then
        if type(value) ~= 'string' or #value > NET_RESOURCE_MAX or not find(value, NET_RESOURCE_PATTERN) then
            return nil, 'invalid_args'
        end
        return { scope = 'resource', resource = value, opening = opening }
    end
    if scope == 'player' then
        local target = type(value) == 'number' and tointeger(value) or nil
        if not target or target < 1 or target > NET_PLAYER_MAX then return nil, 'invalid_args' end
        return { scope = 'player', target = target, opening = opening }
    end
    return nil, 'invalid_args'
end

--- Quelles lignes inscrire au journal du Registre pour cette lecture ? `state` : ce qui a déjà été inscrit pour ce
--- compte du panneau ({ pageAt?, player?, playerAt? }, heures des lignes acceptées par le Registre).
--- Page : à son ouverture, à la première lecture connue du pont (page ouverte avant son redémarrage, ou client qui ne dit
--- pas l'ouverture), puis au plus tard toutes les `everyMs` ; jamais à chaque relecture. L'ouverture est dite par le
--- client : elle n'est prise qu'une fois par `openMinMs` (une page qui la répéterait n'inonde pas le journal).
--- Joueur : chaque fois qu'un autre joueur est lu, et au plus tard toutes les `everyMs` pour le même.
---@param state table
---@param query table  rendu par rules.netQuery
---@param now integer
---@param everyMs integer
---@param openMinMs integer
---@return boolean page
---@return boolean player
function rules.netJournal(state, query, now, everyMs, openMinMs)
    local since = state.pageAt and now - state.pageAt
    local page = since == nil or since >= everyMs or (query.opening and since >= openMinMs)
    local player = query.scope == 'player'
        and (state.player ~= query.target or state.playerAt == nil or now - state.playerAt >= everyMs)
    return page == true, player == true
end
