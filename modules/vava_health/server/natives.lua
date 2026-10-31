--[[
    vava_health/server/natives.lua
    Rôle : annulation, côté serveur, des dégâts natifs de GTA venus d'un joueur (spec T-110 § 7.4) : aucun coup ne
           passe hors de la chaîne. Évènements du moteur OneSync branchés par AddEventHandler (pas des évènements
           réseau de module) :
             - weaponDamageEvent : coup d'arme ou de poing dont la victime est un autre joueur, ou introuvable côté
               serveur → annulé ; un PNJ, un animal, un objet, soi-même → laissé ;
             - explosionEvent, fireEvent, startProjectileEvent venus d'un joueur → annulés (aucun module n'en crée).
           Chaque annulation compte pour le joueur émetteur ; au plus une ligne de console par joueur et par minute.
           Ce qui reste natif (chute, noyade, feu du décor, PNJ) est lu par la boucle de server/life.lua.
           Logique pure exposée pour les tests : natives.victims(data), natives.decide(victimes, émetteur, lookup,
           réglages).
    Dépendances : config.lua, server/core.lua
]]

local type, ipairs, tonumber = type, ipairs, tonumber
local tointeger, concat = math.tointeger, table.concat
local AddEventHandler, CancelEvent, GetGameTimer = AddEventHandler, CancelEvent, GetGameTimer
local NetworkGetEntityFromNetworkId, DoesEntityExist = NetworkGetEntityFromNetworkId, DoesEntityExist
local GetEntityType, IsPedAPlayer, NetworkGetEntityOwner = GetEntityType, IsPedAPlayer, NetworkGetEntityOwner

local cfg = VavaHealth.config.natives
local ENTITY_PED = 1
-- nature des annulations comptées, dans l'ordre de la ligne de console
local COUNTED = { 'weapons', 'explosions', 'fires', 'projectiles' }
local LABELS = { weapons = 'coup(s) d\'arme ou de poing', explosions = 'explosion(s)', fires = 'feu(x)',
    projectiles = 'projectile(s)' }

local natives = {}
VavaHealth.natives = natives

-- joueur → annulations comptées depuis sa dernière ligne : { weapons, explosions, fires, projectiles, loggedAt }
---@type table<integer, table>
local counts = {}

--- Identifiants réseau des victimes d'un weaponDamageEvent : `hitGlobalIds` (liste) et `hitGlobalId`, sans doublon.
--- Un identifiant 0 (victime introuvable) est gardé s'il est seul.
---@param data any
---@return integer[]
function natives.victims(data)
    local out, seen = {}, {}
    if type(data) ~= 'table' then return out end
    local function add(id)
        local int = type(id) == 'number' and tointeger(id) or nil
        if not int or seen[int] then return end
        seen[int] = true
        out[#out + 1] = int
    end
    if type(data.hitGlobalIds) == 'table' then
        for _, id in ipairs(data.hitGlobalIds) do add(id) end
    end
    local single = data.hitGlobalId
    if type(single) == 'number' and (single ~= 0 or #out == 0) then add(single) end
    return out
end

---@class vAvA.HealthVictim
---@field ped boolean
---@field player boolean
---@field owner integer

--- Décision pour un weaponDamageEvent : 'player' (un autre joueur touché : annuler), 'unresolved' (victime
--- introuvable et `unresolved` actif : annuler), ou nil (laisser).
---@param victims integer[]
---@param sender integer
---@param lookup fun(netId: integer): vAvA.HealthVictim|nil
---@param settings table  config.natives
---@return string|nil
function natives.decide(victims, sender, lookup, settings)
    if not settings.weaponDamage then return nil end
    if #victims == 0 then return settings.unresolved and 'unresolved' or nil end
    local unresolved = false
    for _, id in ipairs(victims) do
        local victim = id ~= 0 and lookup(id) or nil
        if not victim then
            unresolved = true
        elseif victim.ped and victim.player and victim.owner ~= sender then
            return 'player'
        end
    end
    if unresolved and settings.unresolved then return 'unresolved' end
    return nil
end

--- Victime d'après son identifiant réseau, lue côté serveur.
---@param netId integer
---@return vAvA.HealthVictim|nil
local function lookup(netId)
    local entity = NetworkGetEntityFromNetworkId(netId)
    if not entity or entity == 0 or not DoesEntityExist(entity) then return nil end
    local ped = GetEntityType(entity) == ENTITY_PED
    return { ped = ped, player = ped and IsPedAPlayer(entity) == true, owner = NetworkGetEntityOwner(entity) }
end

--- Compte une annulation ; une ligne de console par joueur et par `natives.logMs`.
---@param sender integer
---@param nature string
local function count(sender, nature)
    local entry = counts[sender]
    if not entry then
        entry = { weapons = 0, explosions = 0, fires = 0, projectiles = 0 }
        counts[sender] = entry
    end
    entry[nature] = entry[nature] + 1
    local now = GetGameTimer()
    if entry.loggedAt and now - entry.loggedAt < cfg.logMs then return end
    entry.loggedAt = now
    local parts = {}
    for _, name in ipairs(COUNTED) do
        if entry[name] > 0 then parts[#parts + 1] = entry[name] .. ' ' .. LABELS[name] end
        entry[name] = 0
    end
    VavaHealth.log.info('joueur %d : dégâts natifs annulés : %s', sender, concat(parts, ', '))
end

--- Oublie un joueur parti.
---@param src integer
function natives.forget(src)
    counts[src] = nil
end

--- Branche les évènements du moteur. Appelé pendant le setup du module.
function natives.start()
    AddEventHandler('weaponDamageEvent', function(sender, data)
        local src = tonumber(sender)
        if not src then return end
        if natives.decide(natives.victims(data), src, lookup, cfg) then
            CancelEvent()
            count(src, 'weapons')
        end
    end)
    AddEventHandler('explosionEvent', function(sender)
        local src = tonumber(sender)
        if src and cfg.explosions then
            CancelEvent()
            count(src, 'explosions')
        end
    end)
    AddEventHandler('fireEvent', function(sender)
        local src = tonumber(sender)
        if src and cfg.fires then
            CancelEvent()
            count(src, 'fires')
        end
    end)
    AddEventHandler('startProjectileEvent', function(sender)
        local src = tonumber(sender)
        if src and cfg.projectiles then
            CancelEvent()
            count(src, 'projectiles')
        end
    end)
end
