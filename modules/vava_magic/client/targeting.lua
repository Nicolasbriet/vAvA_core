--[[
    vava_magic/client/targeting.lua
    Rôle : verrouillage d'une cible pour les sorts d'attaque (config `lockOn`), commun à tous.
      - Touche (Tab) : appui court = verrouiller le joueur le plus proche du centre de l'écran, à portée du sort
        d'attaque connu et en vue ; nouvel appui = cible suivante ; touche maintenue = relâcher.
      - Le verrou saute hors de portée, hors de vue (quelques vérifications de suite), cible morte, ou sans attaque
        depuis un moment. Un anneau sous la cible n'est vu que du lanceur : rien ne passe par le réseau.
      - Pendant l'appui, la roue d'armes de GTA (même touche) est bloquée : seule boucle par image avec celle de
        l'anneau, et seulement le temps de l'appui ou du verrou.
      - Cible prévenue par le serveur (au début de l'incantation) : le bord de son écran rougit un instant.
    Le serveur revérifie la cible au lancer : ceci n'est qu'une proposition.
    Dépendances : shared/, config.lua, client/nui.lua, client/state.lua, client/messages.lua, client/keys.lua,
                  client/aim.lua
]]

local ipairs, sort = ipairs, table.sort
local CreateThread, Wait, GetGameTimer, RegisterNetEvent = CreateThread, Wait, GetGameTimer, RegisterNetEvent
local PlayerId, PlayerPedId, GetActivePlayers, GetPlayerPed, GetPlayerServerId, GetEntityCoords, GetGameplayCamCoord =
    PlayerId, PlayerPedId, GetActivePlayers, GetPlayerPed, GetPlayerServerId, GetEntityCoords, GetGameplayCamCoord
local DoesEntityExist, IsEntityDead, HasEntityClearLosToEntity = DoesEntityExist, IsEntityDead, HasEntityClearLosToEntity
local DisableControlAction, HideHudComponentThisFrame, DrawMarker = DisableControlAction, HideHudComponentThisFrame, DrawMarker

local nui = VavaMagic.nui
local state = VavaMagic.state
local messages = VavaMagic.messages
local keys = VavaMagic.keys
local aim = VavaMagic.aim
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config.targeting
local ring = cfg.ring
local EVENTS = VavaMagic.EVENTS
-- vue dégagée : décor et objets (pas les peds ni les véhicules)
local LOS_FLAGS = 17
local CONTROL_WEAPON_WHEEL = 37
local HUD_WEAPON_WHEEL, HUD_WEAPON_WHEEL_STATS = 19, 20
local MS_PER_SECOND = 1000

local targeting = {}
VavaMagic.targeting = targeting

---@type { player: integer, serverId: integer, ped: integer, lastUse: integer, unseen: integer }|nil
local locked = nil
local pressedAt = nil
local watching = false

--- Portée du sort d'attaque connu qui porte le plus loin (0 : aucun sort d'attaque).
---@return number
local function lockRange()
    local best = 0
    if not state.isMage() then return best end
    for _, name in ipairs(state.knownSpells()) do
        local spellCfg = state.spellConfig(name)
        local level = state.level(name)
        local range = spellCfg.lockOn and level and spellCfg.levels[level].range
        if range and range > best then best = range end
    end
    return best
end

--- Joueurs verrouillables, du plus proche du centre de l'écran au plus excentré.
---@param range number
---@return table[]
local function candidates(range)
    local me = PlayerId()
    local myPed = PlayerPedId()
    local origin = GetEntityCoords(myPed)
    local camera = GetGameplayCamCoord()
    local direction = aim.direction()
    local list = {}
    for _, player in ipairs(GetActivePlayers()) do
        local ped = player ~= me and GetPlayerPed(player)
        if ped and ped ~= 0 and not IsEntityDead(ped) then
            local position = GetEntityCoords(ped)
            local distance = geometry.distance(origin, position)
            local angle = distance <= range and geometry.angle(direction, camera, position)
            if angle and angle <= cfg.coneDeg and HasEntityClearLosToEntity(myPed, ped, LOS_FLAGS) then
                list[#list + 1] = { player = player, ped = ped, angle = angle, distance = distance }
            end
        end
    end
    sort(list, function(a, b)
        if a.angle ~= b.angle then return a.angle < b.angle end
        return a.distance < b.distance
    end)
    return list
end

--- Anneau sous la cible (à chaque image) et revérification du verrou (toutes les `checkMs`).
local function watch()
    if watching then return end
    watching = true
    CreateThread(function()
        local nextCheck = 0
        -- boucle par image justifiée : seulement tant qu'une cible est verrouillée
        while locked do
            local now = GetGameTimer()
            local ped = locked.ped
            if now >= nextCheck then
                nextCheck = now + cfg.checkMs
                local range = lockRange()
                local myPed = PlayerPedId()
                if not DoesEntityExist(ped) or IsEntityDead(ped) or now - locked.lastUse > cfg.idleMs
                    or geometry.distance(GetEntityCoords(myPed), GetEntityCoords(ped)) > range + cfg.rangeMargin then
                    locked = nil
                    break
                end
                locked.unseen = HasEntityClearLosToEntity(myPed, ped, LOS_FLAGS) and 0 or locked.unseen + 1
                if locked.unseen >= cfg.lostChecks then
                    locked = nil
                    break
                end
            end
            local feet = GetEntityCoords(ped)
            DrawMarker(ring.marker, feet.x, feet.y, feet.z - ring.groundOffset, 0.0, 0.0, 0.0, 0.0, 0.0, (now / MS_PER_SECOND * ring.spin) % 360.0,
                ring.size, ring.size, 1.0, ring.r, ring.g, ring.b, ring.alpha, false, false, 2, false, nil, nil, false)
            Wait(0)
        end
        watching = false
    end)
end

--- Appui court : verrouiller, ou passer à la cible suivante.
function targeting.cycle()
    local range = lockRange()
    if range <= 0 then return end
    local list = candidates(range)
    if #list == 0 then
        messages.refuse('no_lock_target')
        return
    end
    local index = 1
    if locked then
        for i, candidate in ipairs(list) do
            if candidate.player == locked.player then
                index = i % #list + 1
                break
            end
        end
    end
    local choice = list[index]
    locked = { player = choice.player, serverId = GetPlayerServerId(choice.player), ped = choice.ped, lastUse = GetGameTimer(), unseen = 0 }
    watch()
end

function targeting.release()
    locked = nil
end

--- Numéro serveur de la cible verrouillée, ou nil.
---@return integer|nil
function targeting.current()
    return locked and locked.serverId or nil
end

--- Ped de la cible verrouillée, ou nil.
---@return integer|nil
function targeting.ped()
    return locked and locked.ped or nil
end

--- Une attaque vient d'être lancée sur la cible : le verrou reste.
function targeting.used()
    if locked then locked.lastUse = GetGameTimer() end
end

local function pressed()
    pressedAt = GetGameTimer()
    CreateThread(function()
        local mine = pressedAt
        -- boucle par image justifiée : le temps de l'appui seulement, la roue d'armes de GTA ne s'ouvre pas
        while pressedAt == mine do
            DisableControlAction(0, CONTROL_WEAPON_WHEEL, true)
            HideHudComponentThisFrame(HUD_WEAPON_WHEEL)
            HideHudComponentThisFrame(HUD_WEAPON_WHEEL_STATS)
            Wait(0)
        end
    end)
end

local function released()
    if not pressedAt then return end
    local held = GetGameTimer() - pressedAt
    pressedAt = nil
    if held >= cfg.holdMs then targeting.release() else targeting.cycle() end
end

-- prise pour cible : un frisson (bord de l'écran qui rougit), envoyé par le serveur à la seule cible
RegisterNetEvent(EVENTS.TARGETED, function()
    nui.send('threat', { ms = cfg.warnMs })
end)

keys.bindHold('cible', pressed, released)
