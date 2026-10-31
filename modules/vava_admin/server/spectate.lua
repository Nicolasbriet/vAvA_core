--[[
    vava_admin/server/spectate.lua
    Rôle : retour d'un membre du Conseil parti en pleine observation. Pendant une observation, son corps est caché
           sous le joueur observé (client/tools.lua : OneSync ne transmet que les entités proches) ; le core relève
           cette position et la garderait au départ. La place d'où part le membre, lue par le serveur au moment où
           l'observation est accordée, est donc gardée dans un champ privé de son personnage (écrit avec lui) :
             - chaque observation accordée reçoit un numéro ; seule la fin annoncée avec le dernier numéro
               (RPC vava_admin:spectateEnd) efface la place, jamais celle d'une observation remplacée depuis ;
             - au déchargement en pleine observation (départ, retour à la sélection), la place est marquée « parti » ;
             - au chargement suivant, il est replacé dès l'apparition confirmée de ce même personnage, et la place
               n'est effacée qu'une fois le replacement accordé : jamais sous terre, même après un redémarrage.
           Pendant l'observation, le membre est invulnérable pour le serveur (server/invulnerability.lua) : la fin de
           la dernière observation le retire.
    Dépendances : shared/constants.lua, server/core.lua, server/invulnerability.lua
]]

local type, ipairs, tonumber, tostring = type, ipairs, tonumber, tostring
local GetPlayers, GetPlayerPed, GetEntityCoords, GetEntityHeading = GetPlayers, GetPlayerPed, GetEntityCoords, GetEntityHeading

local invulnerability = VavaAdmin.invulnerability

local FIELD = VavaAdmin.SPECTATE_FIELD
local MAX_COORD = VavaAdmin.MAX_COORD
local MAX_SESSION = VavaAdmin.MAX_ID
local COORD = { type = 'number', min = -MAX_COORD, max = MAX_COORD, optional = true }
local HEADING = { type = 'number', min = -360, max = 720, optional = true }

local spectate = {}
VavaAdmin.spectate = spectate

-- dernier numéro d'observation accordé à chaque joueur : seule sa fin compte
local current = {}
local counter = 0
-- personnages chargés à replacer dès leur apparition confirmée : source → { characterId, place }
local pending = {}

---@param src integer
---@return integer|nil
local function characterOf(src)
    local character = VavaAdmin.core.characters.getActive(src)
    return character and character.id or nil
end

--- Place gardée d'un personnage chargé, et si son membre est parti en pleine observation ; nil si le champ est vide.
---@param characterId integer
---@return table|nil place
---@return boolean departed
local function placeOf(characterId)
    local value = VavaAdmin.core.characters.get(characterId, FIELD)
    if type(value) ~= 'table' or type(value.x) ~= 'number' or type(value.y) ~= 'number' or type(value.z) ~= 'number' then
        return nil, false
    end
    local place = { x = value.x, y = value.y, z = value.z, heading = type(value.heading) == 'number' and value.heading or 0.0 }
    return place, value.departed == true
end

---@param characterId integer
---@param value table
local function write(characterId, value)
    local ok, err = VavaAdmin.core.characters.set(characterId, FIELD, value)
    if not ok then VavaAdmin.log.warn('place d\'observation non écrite (personnage n° %d) : %s', characterId, tostring(err)) end
end

--- Marque la place « parti » : la fin de l'observation n'arrivera plus, le replacement est dû.
---@param characterId integer
---@param place table
local function markDeparted(characterId, place)
    write(characterId, { x = place.x, y = place.y, z = place.z, heading = place.heading, departed = true })
end

--- Replace le personnage et n'efface la place qu'une fois le replacement accordé ; sinon elle reste pour la suite.
---@param src integer
---@param characterId integer
---@param place table
local function restore(src, characterId, place)
    local ok, err = VavaAdmin.core.characters.spawn(src, place)
    if ok then
        write(characterId, {})
        VavaAdmin.log.info('personnage n° %d replacé là où il a commencé une observation', characterId)
    else
        VavaAdmin.log.warn('personnage n° %d non replacé après une observation (place gardée) : %s', characterId, tostring(err))
    end
end

--- Observation accordée : garde la place d'où part le membre, lue ici sur son ped (jamais reçue du client), et rend le
--- numéro de cette observation. Une observation encore ouverte (seconde demande, double clic) garde la place de la
--- première : le ped est peut-être déjà caché sous l'observé. Nil sans personnage ni ped.
---@param src integer
---@return integer|nil session
function spectate.begin(src)
    local characterId = characterOf(src)
    local ped = GetPlayerPed(src)
    if not characterId or ped == 0 then return nil end
    local place, departed = placeOf(characterId)
    if not (current[src] and place and not departed) then
        local coords = GetEntityCoords(ped)
        write(characterId, { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) })
    end
    counter = counter % MAX_SESSION + 1
    current[src] = counter
    return counter
end

--- Fin d'une observation annoncée par le client du membre (il est revenu à sa place). Seule la fin de la dernière
--- observation accordée efface la place ; une place « parti » (déchargé entre-temps, autre personnage) n'est jamais
--- effacée ici.
---@param src integer
---@param session integer
---@return boolean ok
function spectate.finish(src, session)
    if current[src] ~= session then return true end
    current[src] = nil
    -- revenu à sa place : l'observation ne le protège plus (server/invulnerability.lua)
    invulnerability.drop(src, 'spectate', 'finished')
    local characterId = characterOf(src)
    if not characterId then return true end
    local place, departed = placeOf(characterId)
    if place and not departed then write(characterId, {}) end
    return true
end

--- Déchargement (départ, retour à la sélection) : une place encore gardée veut dire que l'observation n'est pas finie.
--- Elle est marquée « parti » avant l'écriture du personnage (le core attend ce hook).
---@param payload { source: integer, characterId: integer }
local function onUnloading(payload)
    pending[payload.source] = nil
    current[payload.source] = nil
    local place, departed = placeOf(payload.characterId)
    if place and not departed then markDeparted(payload.characterId, place) end
end

--- Chargement d'un personnage avec une place gardée : il est parti en pleine observation (ou le serveur est tombé
--- pendant). La place reste écrite, marquée « parti », jusqu'au replacement réussi.
---@param payload { source: integer, characterId: integer }
local function onLoaded(payload)
    pending[payload.source] = nil
    local place, departed = placeOf(payload.characterId)
    if not place then return end
    if not departed then markDeparted(payload.characterId, place) end
    pending[payload.source] = { characterId = payload.characterId, place = place }
end

--- Apparition confirmée : replacement, seulement pour le personnage chargé avec la place (un client qui décharge avant
--- de confirmer puis choisit un autre personnage du compte n'y est jamais envoyé).
---@param payload { source: integer, characterId: integer }
local function onSpawned(payload)
    local entry = pending[payload.source]
    if not entry then return end
    pending[payload.source] = nil
    if entry.characterId ~= payload.characterId then return end
    restore(payload.source, entry.characterId, entry.place)
end

--- Déclare le champ et branche les hooks. Au (re)démarrage du module, pour chaque personnage en jeu :
---   - une place sans marque : son observation a pris fin avec la ressource cliente (client/main.lua remet le ped en
---     place) sans que la fin ait pu arriver : effacée ;
---   - une place « parti » : il est revenu pendant l'arrêt du module, ou entre chargement et apparition : replacé.
--- Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function spectate.start()
    local core = VavaAdmin.core
    local ok, err = core.characters.defineField(FIELD, {
        schema = { type = 'table', fields = {
            x = COORD, y = COORD, z = COORD, heading = HEADING, departed = { type = 'boolean', optional = true },
        } },
        default = {},
        visibility = 'private',
    })
    if not ok then return false, err end
    for _, hook in ipairs({
        { 'core:character:unloading', onUnloading }, { 'core:character:loaded', onLoaded }, { 'core:character:spawned', onSpawned },
    }) do
        local id, hookErr = core.hooks.after(hook[1], hook[2])
        if not id then return false, hookErr end
    end
    for _, value in ipairs(GetPlayers()) do
        local src = tonumber(value)
        local characterId = src and characterOf(src)
        if characterId then
            local place, departed = placeOf(characterId)
            if place and departed then
                restore(src, characterId, place)
            elseif place then
                write(characterId, {})
            end
        end
    end
    return true
end

--- Le joueur parti : ce numéro de session ne désigne plus personne.
---@param src integer
function spectate.forget(src)
    pending[src] = nil
    current[src] = nil
end
