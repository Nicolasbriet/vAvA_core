--[[
    vava_admin/server/players.lua
    Rôle : les joueurs vus par le Conseil : liste des connectés et fiche d'un joueur (identité du personnage, compte,
           latence, temps de jeu du personnage, santé, besoins, avertissements ; identifiants sauf l'adresse IP pour la
           seule Chancellerie). Calculées à la demande, jamais envoyées en continu ; le pseudo FiveM et les
           identifiants ne sont lus qu'au moment de l'affichage (rien n'est conservé). État « immobilisé » en mémoire,
           levé pour tous à l'arrêt du module (server/actions.lua).
    Dépendances : config.lua, server/core.lua, server/staff.lua, server/store.lua
]]

local ipairs, tonumber, type, floor = ipairs, tonumber, type, math.floor
local sort = table.sort
local GetPlayers, GetPlayerName, GetPlayerPing, GetPlayerPed, GetEntityCoords, GetPlayerIdentifierByType =
    GetPlayers, GetPlayerName, GetPlayerPing, GetPlayerPed, GetEntityCoords, GetPlayerIdentifierByType

local staff = VavaAdmin.staff
local store = VavaAdmin.store
local call = VavaAdmin.call

-- avertissements montrés dans une fiche
local WARNINGS_SHOWN = 10

local players = {}
VavaAdmin.players = players

-- joueurs immobilisés par le Conseil (état montré dans la liste)
local frozen = {}
players.frozen = frozen

--- Cible d'une action : joueur connecté et chargé (compte connu).
---@param src any
---@return vAvA.AdminTarget|nil
---@return string|nil code
function players.resolve(src)
    local session = type(src) == 'number' and VavaAdmin.core.players.get(src)
    if not session or not session.accountId then return nil, 'not_found' end
    local name = staff.characterName(src)
    return {
        source = src, accountId = session.accountId, characterId = session.characterId,
        label = name or ('compte n° ' .. session.accountId),
    }
end

---@param src integer
---@return boolean|nil
local function isDowned(src)
    local ok, downed = call('vava_health', 'isDowned', src)
    if ok then return downed == true end
    return nil
end

--- Temps de jeu du personnage actif (secondes), ou nil : en sélection, ou core antérieur à 0.6.0.
---@param src integer
---@return integer|nil
local function playSecondsOf(src)
    local character = VavaAdmin.core.characters.getActive(src)
    return character and character.playSeconds or nil
end

--- Joueurs connectés, pour la liste du panneau.
---@return table[]
function players.list()
    local out = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        local session = src and VavaAdmin.core.players.get(src)
        if session and session.accountId then
            local rank = staff.rankOfAccount(session.accountId)
            out[#out + 1] = {
                source = src, name = GetPlayerName(src), accountId = session.accountId,
                character = staff.characterName(src), ping = GetPlayerPing(src), playSeconds = playSecondsOf(src),
                rank = rank and rank.label or nil, frozen = frozen[src] == true,
                downed = session.characterId and isDowned(src) or false,
            }
        end
    end
    sort(out, function(a, b) return a.source < b.source end)
    return out
end

-- identifiants montrés dans la fiche, dans cet ordre ; jamais l'adresse IP (ip:), ni rien d'autre
local IDENTIFIER_TYPES = { 'license', 'license2', 'fivem', 'discord', 'steam', 'xbl', 'live' }

--- Identifiants d'un joueur connecté, lus à l'instant pour la fiche, jamais conservés : { { type, value } }.
---@param src integer
---@return table[]
local function identifiersOf(src)
    local out = {}
    for _, kind in ipairs(IDENTIFIER_TYPES) do
        local value = GetPlayerIdentifierByType(src, kind)
        if value then out[#out + 1] = { type = kind, value = value } end
    end
    return out
end

--- Fiche d'un joueur. Les identifiants (license, discord, steam…) ne sont joints que pour la Chancellerie, qui les
--- affiche : le Registre en jeu ne les montre pas, ils ne partent donc jamais vers le jeu d'un membre du Conseil.
---@param target vAvA.AdminTarget
---@param withIdentifiers? boolean
---@return table
function players.details(target, withIdentifiers)
    local src = target.source
    local ped = GetPlayerPed(src)
    local coords = ped ~= 0 and GetEntityCoords(ped)
    local rank = staff.rankOfAccount(target.accountId)
    local healthOk, health = call('vava_health', 'get', src)
    local needsOk, needs = call('vava_needs', 'get', src)
    local warnings = store.warningsOf(target.accountId, WARNINGS_SHOWN) or {}
    return {
        source = src, name = GetPlayerName(src), accountId = target.accountId, characterId = target.characterId,
        character = staff.characterName(src), ping = GetPlayerPing(src), playSeconds = playSecondsOf(src),
        rank = rank and rank.name or nil, rankLabel = rank and rank.label or nil, frozen = frozen[src] == true,
        position = coords and { x = floor(coords.x * 10) / 10, y = floor(coords.y * 10) / 10, z = floor(coords.z * 10) / 10 } or nil,
        health = healthOk and type(health) == 'table' and health or nil,
        needs = needsOk and type(needs) == 'table' and needs or nil,
        warnings = warnings,
        identifiers = withIdentifiers and identifiersOf(src) or nil,
    }
end

--- Le joueur parti : son numéro de session ne le désigne plus.
---@param src integer
function players.forget(src)
    frozen[src] = nil
end
