--[[
    vava_admin/server/spectate.lua
    Rôle : retour d'un membre du Conseil parti en pleine observation. Pendant une observation, son corps est caché
           sous le joueur observé (client/tools.lua : OneSync ne transmet que les entités proches) ; le core relève
           cette position et la garderait au départ. La place d'où part le membre, lue par le serveur au moment où
           l'observation est accordée, est donc gardée dans un champ privé de son personnage (écrit avec lui) et
           effacée quand l'observation finit (intention du client, RPC vava_admin:spectateEnd). S'il part avant (jeu
           fermé, plantage, retour à la sélection), il y est replacé dès sa prochaine apparition : jamais sous terre.
    Dépendances : shared/constants.lua, server/core.lua
]]

local type, ipairs, tonumber, tostring = type, ipairs, tonumber, tostring
local GetPlayers, GetPlayerPed, GetEntityCoords, GetEntityHeading = GetPlayers, GetPlayerPed, GetEntityCoords, GetEntityHeading

local FIELD = VavaAdmin.SPECTATE_FIELD
local MAX_COORD = VavaAdmin.MAX_COORD
local COORD = { type = 'number', min = -MAX_COORD, max = MAX_COORD, optional = true }
local HEADING = { type = 'number', min = -360, max = 720, optional = true }

local spectate = {}
VavaAdmin.spectate = spectate

-- personnages chargés à replacer dès leur apparition confirmée : source → { x, y, z, heading }
local pending = {}

---@param src integer
---@return integer|nil
local function characterOf(src)
    local character = VavaAdmin.core.characters.getActive(src)
    return character and character.id or nil
end

--- Place gardée dans le champ, ou nil (champ vide : aucune observation en cours).
---@param value any
---@return table|nil
local function placeOf(value)
    if type(value) ~= 'table' or type(value.x) ~= 'number' or type(value.y) ~= 'number' or type(value.z) ~= 'number' then
        return nil
    end
    return { x = value.x, y = value.y, z = value.z, heading = type(value.heading) == 'number' and value.heading or 0.0 }
end

---@param characterId integer
---@param value table
local function write(characterId, value)
    local ok, err = VavaAdmin.core.characters.set(characterId, FIELD, value)
    if not ok then VavaAdmin.log.warn('place d\'observation non écrite (personnage n° %d) : %s', characterId, tostring(err)) end
end

--- Efface la place gardée d'un personnage chargé, s'il en a une.
---@param characterId integer
local function clear(characterId)
    if placeOf(VavaAdmin.core.characters.get(characterId, FIELD)) then write(characterId, {}) end
end

--- Observation accordée : garde la place d'où part le membre, lue ici sur son ped (jamais reçue du client). Une place
--- encore gardée d'une observation précédente (fin jamais arrivée) est remplacée : elle est plus ancienne.
---@param src integer
function spectate.begin(src)
    local characterId = characterOf(src)
    local ped = GetPlayerPed(src)
    if not characterId or ped == 0 then return end
    local coords = GetEntityCoords(ped)
    write(characterId, { x = coords.x, y = coords.y, z = coords.z, heading = GetEntityHeading(ped) })
end

--- Fin d'une observation, annoncée par le client du membre (il est revenu à sa place) : la place gardée ne sert plus.
--- Sans personnage chargé (retour à la sélection en pleine observation), elle reste pour la prochaine apparition.
---@param src integer
---@return boolean ok
function spectate.finish(src)
    local characterId = characterOf(src)
    if characterId then clear(characterId) end
    return true
end

--- Personnage chargé avec une place gardée : il est parti en pleine observation. La place est effacée et le
--- personnage y sera replacé dès son apparition confirmée (le core l'a fait apparaître là où il a été relevé).
---@param payload { source: integer, characterId: integer }
local function onLoaded(payload)
    local place = placeOf(VavaAdmin.core.characters.get(payload.characterId, FIELD))
    if not place then return end
    write(payload.characterId, {})
    pending[payload.source] = place
end

---@param payload { source: integer, characterId: integer }
local function onSpawned(payload)
    local place = pending[payload.source]
    if not place then return end
    pending[payload.source] = nil
    local ok, err = VavaAdmin.core.characters.spawn(payload.source, place)
    if ok then
        VavaAdmin.log.info('personnage n° %d replacé là où il a commencé une observation', payload.characterId)
    else
        VavaAdmin.log.warn('personnage n° %d non replacé après une observation : %s', payload.characterId, tostring(err))
    end
end

--- Déclare le champ et branche les hooks. Au (re)démarrage du module, les observations en cours ont pris fin chez
--- chaque client (client/main.lua, arrêt de la ressource) sans que leur fin ait pu arriver : les places gardées des
--- personnages en jeu sont effacées. Appelé pendant le setup du module.
---@return boolean ok
---@return string|nil err
function spectate.start()
    local core = VavaAdmin.core
    local ok, err = core.characters.defineField(FIELD, {
        schema = { type = 'table', fields = { x = COORD, y = COORD, z = COORD, heading = HEADING } },
        default = {},
        visibility = 'private',
    })
    if not ok then return false, err end
    local id
    id, err = core.hooks.after('core:character:loaded', onLoaded)
    if not id then return false, err end
    id, err = core.hooks.after('core:character:spawned', onSpawned)
    if not id then return false, err end
    for _, value in ipairs(GetPlayers()) do
        local characterId = characterOf(tonumber(value))
        if characterId then clear(characterId) end
    end
    return true
end

--- Le joueur parti : rien à replacer pour ce numéro de session.
---@param src integer
function spectate.forget(src)
    pending[src] = nil
end
