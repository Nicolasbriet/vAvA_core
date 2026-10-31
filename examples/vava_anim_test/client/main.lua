--[[
    vava_anim_test/client/main.lua
    Rôle : commandes de test des animations, locales au joueur :
      /anim <dictionnaire> [clip] [drapeau] [durée ms]   charge le dictionnaire, trouve le clip (sondage de noms
                                                          courants si on ne le donne pas) et le joue ;
      /anim                                               rejoue la dernière animation ;
      /epee (et les autres raccourcis de la config)       joue une animation donnée sans rien taper ;
      /animstop                                           arrête l'animation ;
      /animprop [modèle] [os] [x y z] [rx ry rz]          accroche un accessoire à la main pour juger la pose ;
      /animprop                                           le retire ;
      /animflags                                          rappelle les drapeaux utiles.
    Chaque commande demande d'abord l'accès au serveur (vava_anim_test:access : mode développement et droit du
    Conseil ou ACE), réponse positive gardée `accessCacheMs` ; sans vAvA_core, aucune commande n'est enregistrée.
    Un .ycd posé dans stream/ se joue sous le nom de son fichier. Retours dans le chat (chat:addMessage) et la console F8.
    Dépendances : vAvA_core (API v1), config_client.lua
]]

local tonumber, tostring, ipairs, pcall = tonumber, tostring, ipairs, pcall
local tointeger = math.tointeger
local format, concat = string.format, table.concat
local CreateThread, Wait, RegisterCommand, TriggerEvent, AddEventHandler = CreateThread, Wait, RegisterCommand, TriggerEvent, AddEventHandler
local PlayerPedId, GetEntityCoords, GetGameTimer = PlayerPedId, GetEntityCoords, GetGameTimer
local DoesAnimDictExist, RequestAnimDict, HasAnimDictLoaded, GetAnimDuration = DoesAnimDictExist, RequestAnimDict, HasAnimDictLoaded, GetAnimDuration
local RemoveAnimDict = RemoveAnimDict
local TaskPlayAnim, IsEntityPlayingAnim, ClearPedTasks = TaskPlayAnim, IsEntityPlayingAnim, ClearPedTasks
local GetHashKey, IsModelInCdimage, RequestModel, HasModelLoaded, SetModelAsNoLongerNeeded = GetHashKey, IsModelInCdimage, RequestModel, HasModelLoaded, SetModelAsNoLongerNeeded
local CreateObject, AttachEntityToEntity, GetPedBoneIndex, DoesEntityExist, DeleteObject = CreateObject, AttachEntityToEntity, GetPedBoneIndex, DoesEntityExist, DeleteObject

local RESOURCE = GetCurrentResourceName()
local cfg = VavaAnimTest.config
local C = cfg.commands
local USAGE = format('/%s <dictionnaire> [clip] [drapeau] [durée ms] — /%s pour rejouer la dernière', C.play, C.play)
local RPC_ACCESS = RESOURCE .. ':access'

local called, core = pcall(function() return exports.vAvA_core:getApi(1) end)
if not called or not core then
    print(('^3[%s] vAvA_core absent : outil inactif^7'):format(RESOURCE))
    return
end

-- dernière animation jouée et accessoire accroché
local last = nil
local prop = nil
-- dictionnaire chargé à la demande de l'outil (jamais un dictionnaire déjà chargé par un autre module)
local requested = nil
-- accès accordé par le serveur jusqu'à cette heure (GetGameTimer)
local grantedUntil = 0

---@param message string
local function say(message, ...)
    local text = format(message, ...)
    print(('[%s] %s'):format(RESOURCE, text))
    TriggerEvent('chat:addMessage', { args = { cfg.chatAuthor, text } })
end

--- Le serveur décide : mode développement et droit. Réponse positive gardée `accessCacheMs`. Bloque le thread courant.
---@return boolean
local function granted()
    if GetGameTimer() < grantedUntil then return true end
    local ok, success, code = core.rpc.call(RPC_ACCESS)
    if ok and success then
        grantedUntil = GetGameTimer() + cfg.accessCacheMs
        return true
    end
    local reason = ok and code or success
    say('%s', cfg.refusals[reason] or ('accès impossible (' .. tostring(reason) .. ').'))
    return false
end

--- Enregistre une commande qui ne s'exécute qu'avec l'accès du serveur, dans son propre thread.
---@param name string
---@param handler fun(args: string[])
local function command(name, handler)
    RegisterCommand(name, function(_, args)
        CreateThread(function()
            if granted() then handler(args) end
        end)
    end, false)
end

--- Rend au jeu le dictionnaire que l'outil a demandé.
local function releaseDict()
    if requested then RemoveAnimDict(requested) end
    requested = nil
end

--- Charge un dictionnaire d'animations (et rend le précédent demandé par l'outil). Bloque le thread courant jusqu'au
--- chargement ou au délai.
---@param dict string
---@return boolean
local function loadDict(dict)
    if requested and requested ~= dict then releaseDict() end
    if not DoesAnimDictExist(dict) then
        say('dictionnaire « %s » inconnu du jeu : le fichier %s.ycd est-il dans stream/ de cette ressource, et la ressource a-t-elle été (re)démarrée ?', dict, dict)
        return false
    end
    if HasAnimDictLoaded(dict) then return true end
    RequestAnimDict(dict)
    requested = dict
    local deadline = GetGameTimer() + cfg.loadTimeoutMs
    while not HasAnimDictLoaded(dict) do
        if GetGameTimer() > deadline then
            say('dictionnaire « %s » : chargement trop long.', dict)
            return false
        end
        Wait(10)
    end
    return true
end

--- Clips qui répondent dans un dictionnaire chargé : un clip existe si le jeu lui connaît une durée.
---@param dict string
---@return string[]
local function probe(dict)
    local found, seen = {}, {}
    for _, candidate in ipairs(cfg.clipCandidates) do
        local clip = format(candidate, dict)
        if not seen[clip] then
            seen[clip] = true
            if GetAnimDuration(dict, clip) > 0 then found[#found + 1] = clip end
        end
    end
    return found
end

--- Joue un clip et vérifie qu'il a démarré.
---@param dict string
---@param clip string
---@param flag integer
---@param duration integer   -1 : durée du clip (ou sans fin en boucle)
local function play(dict, clip, flag, duration)
    local ped = PlayerPedId()
    local length = GetAnimDuration(dict, clip)
    TaskPlayAnim(ped, dict, clip, cfg.blendIn, cfg.blendOut, duration, flag, 0.0, false, false, false)
    Wait(cfg.startCheckMs)
    if IsEntityPlayingAnim(ped, dict, clip, 3) then
        last = { dict = dict, clip = clip, flag = flag, duration = duration }
        say('joue %s / %s — durée du clip %.2f s, drapeau %d%s.', dict, clip, length, flag, duration > 0 and format(', pendant %d ms', duration) or '')
    elseif length <= 0 then
        say('%s / %s : ce clip n\'existe pas dans le dictionnaire (durée nulle). /%s %s sans clip pour sonder les noms courants.', dict, clip, C.play, dict)
    else
        say('%s / %s : le clip existe (%.2f s) mais n\'a pas démarré — le personnage est-il libre (pas en véhicule, pas à terre) ?', dict, clip, length)
    end
end

--- Charge, trouve le clip s'il n'est pas donné, joue. Bloque le thread courant.
---@param dict string
---@param clip string|nil
---@param flag integer
---@param duration integer
local function playFrom(dict, clip, flag, duration)
    if not loadDict(dict) then return end
    if clip then
        play(dict, clip, flag, duration)
        return
    end
    local found = probe(dict)
    if #found == 0 then
        say('%s : aucun clip trouvé parmi les noms courants. Ouvrez %s.ycd dans CodeWalker pour lire le nom du clip, puis /%s %s <clip>.', dict, dict, C.play, dict)
        return
    end
    if #found > 1 then say('%s : clips trouvés — %s. Le premier est joué ; /%s %s <clip> pour un autre.', dict, concat(found, ', '), C.play, dict) end
    play(dict, found[1], flag, duration)
end

command(C.play, function(args)
    local dict = args[1]
    if not dict then
        if last then
            if loadDict(last.dict) then play(last.dict, last.clip, last.flag, last.duration) end
        else
            say(USAGE)
        end
        return
    end
    playFrom(dict, args[2], tointeger(tonumber(args[3] or '')) or cfg.defaultFlag, tointeger(tonumber(args[4] or '')) or -1)
end)

-- raccourcis : une commande par animation à tester, rien à taper
for _, shortcut in ipairs(cfg.shortcuts) do
    command(shortcut.command, function()
        playFrom(shortcut.dict, shortcut.clip, shortcut.flag or cfg.defaultFlag, shortcut.duration or -1)
    end)
end

command(C.stop, function()
    ClearPedTasks(PlayerPedId())
    say('animation arrêtée.')
end)

local function removeProp()
    if prop and DoesEntityExist(prop) then DeleteObject(prop) end
    prop = nil
end

command(C.prop, function(args)
    removeProp()
    if not args[1] and not last then
        say('accessoire retiré. /%s <modèle> [os] [x y z] [rx ry rz] pour en accrocher un (défaut : %s).', C.prop, cfg.prop.defaultModel)
        return
    end
    if not args[1] then
        say('accessoire retiré.')
        return
    end
    local model = args[1]
    local hash = GetHashKey(model)
    if not IsModelInCdimage(hash) then
        say('modèle « %s » inconnu du jeu.', model)
        return
    end
    RequestModel(hash)
    local deadline = GetGameTimer() + cfg.loadTimeoutMs
    while not HasModelLoaded(hash) do
        if GetGameTimer() > deadline then
            say('modèle « %s » : chargement trop long.', model)
            return
        end
        Wait(10)
    end
    local ped = PlayerPedId()
    local bone = tointeger(tonumber(args[2] or '')) or cfg.prop.bone
    local o, r = cfg.prop.offset, cfg.prop.rotation
    local x, y, z = tonumber(args[3]) or o[1], tonumber(args[4]) or o[2], tonumber(args[5]) or o[3]
    local rx, ry, rz = tonumber(args[6]) or r[1], tonumber(args[7]) or r[2], tonumber(args[8]) or r[3]
    local at = GetEntityCoords(ped)
    prop = CreateObject(hash, at.x, at.y, at.z, false, false, false)
    AttachEntityToEntity(prop, ped, GetPedBoneIndex(ped, bone), x + 0.0, y + 0.0, z + 0.0, rx + 0.0, ry + 0.0, rz + 0.0, true, true, false, true, 1, true)
    SetModelAsNoLongerNeeded(hash)
    say('%s accroché à l\'os %d, décalage %.2f %.2f %.2f, rotation %.0f %.0f %.0f.', model, bone, x, y, z, rx, ry, rz)
end)

command(C.flags, function()
    for _, entry in ipairs(cfg.flags) do say('%d : %s', entry[1], entry[2]) end
end)

-- À l'arrêt : l'accessoire est retiré ; l'animation n'est coupée que si c'est celle de l'outil (jamais une mise à
-- terre ou le geste d'un autre module).
AddEventHandler('onResourceStop', function(resource)
    if resource ~= RESOURCE then return end
    removeProp()
    local ped = PlayerPedId()
    if last and IsEntityPlayingAnim(ped, last.dict, last.clip, 3) then ClearPedTasks(ped) end
    releaseDict()
end)
