--[[
    vava_chat/server/links.lua
    Rôle : liens avec le core et les autres modules : personnage actif du joueur (numéro, nom), droits du Conseil
           (vava_admin, sinon une permission ACE). Appels inter-ressources isolés : un module absent ou en erreur ne
           fait qu'ôter le lien.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local type, pcall, tostring = type, pcall, tostring
local pack, unpack = table.pack, table.unpack
local GetResourceState, IsPlayerAceAllowed = GetResourceState, IsPlayerAceAllowed

local core = VavaChat.core
if not core then return end

local cfg = VavaChat.config
local ADMIN = VavaChat.ADMIN

local links = {}
VavaChat.links = links

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

--- Export d'une autre ressource, isolé. Renvoie ok (appel réussi) puis ses valeurs.
---@return boolean called
local function call(resource, fn, ...)
    if GetResourceState(resource) ~= 'started' then return false end
    local results = pack(pcall(invoke, resource, fn, ...))
    if not results[1] then
        VavaChat.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

--- Personnage actif du joueur, ou nil (en sélection, pas de personnage).
---@param src integer
---@return integer|nil
function links.characterId(src)
    local session = core.players.get(src)
    if not session or session.state ~= 'active' then return nil end
    return session.characterId
end

--- Nom affiché dans le chat : celui du personnage (prénom nom), jamais le pseudo FiveM.
---@param src integer
---@return string|nil
function links.characterName(src)
    local character = core.characters.getActive(src)
    if not character then return nil end
    return character.firstName .. ' ' .. character.lastName
end

--- Membre du Conseil ? Renvoie aussi le libellé de son rang (vava_admin). Sans vava_admin : la permission ACE de la
--- config, sans rang.
---@param src integer
---@return boolean staff
---@return string|nil rank
function links.staff(src)
    if GetResourceState(ADMIN) == 'started' then
        local called, rank = call(ADMIN, 'rankOf', src)
        if called and type(rank) == 'table' and type(rank.label) == 'string' then return true, rank.label end
        return false, nil
    end
    return IsPlayerAceAllowed(src, cfg.staff.ace) == true, nil
end
