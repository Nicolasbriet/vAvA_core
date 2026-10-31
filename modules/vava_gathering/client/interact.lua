--[[
    vava_gathering/client/interact.lua
    Rôle : le geste de récolte côté joueur. Invite près d'un nœud (verbe, ressource, charges, outil à tenir), demande au
           serveur (begin), animation et barre de progression du HUD pendant la durée annoncée, fin du geste (finish)
           ou interruption (cancel : nouvel appui, déplacement). Pour un nœud d'eau, la ligne est lancée et c'est
           client/fishing.lua qui prend la suite à la touche. À terre (vava_health), ni invite ni demande. Le client
           ne décide de rien : il montre, joue et demande ; le serveur notifie les résultats.
    Dépendances : shared/constants.lua, config_client.lua, shared/geometry.lua, client/core.lua, client/nui.lua,
                  client/props.lua
]]

local type, tostring, pcall, ipairs = type, tostring, pcall, ipairs
local CreateThread, Wait, SetTimeout, GetGameTimer = CreateThread, Wait, SetTimeout, GetGameTimer
local PlayerPedId, GetEntityCoords, GetResourceState = PlayerPedId, GetEntityCoords, GetResourceState
local TaskStartScenarioInPlace, TaskPlayAnim, ClearPedTasks = TaskStartScenarioInPlace, TaskPlayAnim, ClearPedTasks
local RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict = RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict

local core = VavaGathering.core
if not core then return end

local cfg = VavaGathering.config
local geometry = VavaGathering.geometry
local nui = VavaGathering.nui
local props = VavaGathering.props
local RPC = VavaGathering.RPC

local HUD = 'vava_hud'
local HEALTH = 'vava_health'
local PROGRESS_ID = 'vava_gathering:harvest'
-- champ de personnage de l'inventaire, reçu par le seul joueur : ce qu'il tient ({ id, item })
local HANDS_FIELD = 'vava_inventory:hands'
local MOVE_POLL_MS = 250
local ANIM_LOAD_MS = 5000
local ANIM_BLEND = 8.0

-- zones d'eau (config.waterKinds) : l'invite parle de l'eau, non de la terre
local WATER_ZONES = {}
for _, zone in ipairs(cfg.zones) do
    if type(cfg.waterKinds) == 'table' and cfg.waterKinds[zone.kind] == true then WATER_ZONES[zone.id] = true end
end

local interact = {}
VavaGathering.interact = interact

---@class vAvA.GatheringSession
---@field token integer
---@field nodeId string
---@field kind 'harvest'|'fishing'
---@field anim string|nil   dictionnaire chargé, à libérer
---@field tension boolean   barre de tension en cours (pêche)
---@field x number
---@field y number
---@field z number

---@type vAvA.GatheringSession|nil
local session = nil
local lastPrompt = ''

-- Animation ---------------------------------------------------------------------------------------------------------

--- Joue l'animation d'une clé de config (scénario, ou dictionnaire + animation en boucle). Renvoie le dictionnaire
--- chargé, à libérer à la fin.
---@param key string
---@return string|nil dict
local function playAnim(key)
    local anim = cfg.anims[key]
    if not anim then return nil end
    local ped = PlayerPedId()
    if anim.scenario then
        TaskStartScenarioInPlace(ped, anim.scenario, 0, true)
        return nil
    end
    if not HasAnimDictLoaded(anim.dict) then
        RequestAnimDict(anim.dict)
        local deadline = GetGameTimer() + ANIM_LOAD_MS
        while not HasAnimDictLoaded(anim.dict) and GetGameTimer() < deadline do Wait(50) end
        if not HasAnimDictLoaded(anim.dict) then return nil end
    end
    TaskPlayAnim(ped, anim.dict, anim.anim, ANIM_BLEND, -ANIM_BLEND, -1, anim.flag or 1, 0.0, false, false, false)
    return anim.dict
end

---@param dict string|nil
local function stopAnim(dict)
    ClearPedTasks(PlayerPedId())
    if dict then RemoveAnimDict(dict) end
end

-- Barre de progression du HUD (facultatif) ----------------------------------------------------------------------------

---@param label string
---@param durationMs integer
local function progressStart(label, durationMs)
    if GetResourceState(HUD) ~= 'started' then return end
    local called, err = pcall(function()
        return exports[HUD]:progress(PROGRESS_ID, { label = label, durationMs = durationMs, cancelable = true })
    end)
    if not called then core.log.warn('%s.progress en erreur : %s', HUD, tostring(err)) end
end

local function progressCancel()
    if GetResourceState(HUD) ~= 'started' then return end
    pcall(function() return exports[HUD]:cancelProgress(PROGRESS_ID) end)
end

-- Invite ------------------------------------------------------------------------------------------------------------

local function healthState()
    return exports[HEALTH]:get()
end

--- Le joueur local est-il à terre ? (export client de vava_health, lu à l'appui et à l'invite, donc au rythme de la
--- boucle des props et seulement près d'un nœud) Module absent ou en erreur : pas à terre. À terre, la touche ne sert
--- qu'à rendre l'âme ; le serveur refuse de toute façon.
---@return boolean
local function isDowned()
    if GetResourceState(HEALTH) ~= 'started' then return false end
    local called, health = pcall(healthState)
    return called and type(health) == 'table' and health.downed == true
end

--- L'objet en main est-il un outil du genre demandé ? (vrai si la ressource n'en demande aucun)
---@param resource table
---@return boolean
local function toolOk(resource)
    if not resource.tool then return true end
    local character = core.characters.current()
    local held = character and type(character.fields) == 'table' and character.fields[HANDS_FIELD] or nil
    local item = type(held) == 'table' and held.item or nil
    local tool = item and cfg.tools[item]
    return tool ~= nil and tool.kind == resource.tool
end

--- Invite pour le nœud le plus proche (ou rien) ; envoyée à l'interface seulement si elle change.
---@param nodeId string|nil
function interact.refreshPrompt(nodeId)
    local node = nodeId and props.node(nodeId)
    local resource = node and props.resource(node)
    if not node or not resource or session or isDowned() then
        if lastPrompt ~= '' then
            lastPrompt = ''
            nui.send('prompt', { hidden = true })
        end
        return
    end
    local charges = props.charges(node)
    local payload = {
        key = cfg.keys.interact, anim = resource.anim, label = resource.label, charges = charges,
        exhausted = charges <= 0, zoneDepleted = props.isDepleted(node.zone), water = WATER_ZONES[node.zone] == true,
        toolKind = resource.tool, toolOk = toolOk(resource),
    }
    local signature = table.concat({ node.id, charges, tostring(payload.zoneDepleted), tostring(payload.toolOk) }, '|')
    if signature == lastPrompt then return end
    lastPrompt = signature
    nui.send('prompt', payload)
end

-- Session -----------------------------------------------------------------------------------------------------------

---@return vAvA.GatheringSession|nil
function interact.session()
    return session
end

--- Codes que le serveur a déjà commentés au joueur (notification) : l'interface ne les répète pas.
local SERVER_NOTIFIED = {
    no_tool = true, wrong_tool = true, broken_tool = true, no_charges = true, no_space = true, failed = true,
    escaped = true, expired = true,
}

--- Refus ou erreur de transport : code traduit et affiché par l'interface (textes dans web/js/strings.js).
---@param ok boolean
---@param success any
---@param code any
local function report(ok, success, code)
    if not ok then
        nui.send('error', { code = tostring(success) })
    elseif not success and not SERVER_NOTIFIED[code] then
        nui.send('error', { code = tostring(code) })
    end
end
interact.report = report

--- Oublie la session en cours (après fin, interruption ou refus) et remet l'invite.
local function clear()
    if not session then return end
    local current = session
    session = nil
    stopAnim(current.anim)
    nui.send('cast', { hidden = true })
    if current.tension then nui.send('tensionStop') end
    interact.refreshPrompt((props.nearest()))
end

--- Interrompt le geste en cours : le serveur est prévenu, l'animation et la barre s'arrêtent.
function interact.cancel()
    if not session then return end
    local token = session.token
    progressCancel()
    clear()
    core.rpc.emit(RPC.CANCEL, token)
end

--- Se déplacer interrompt le geste : vérification lente, seulement pendant un geste.
---@param current vAvA.GatheringSession
local function watchMovement(current)
    CreateThread(function()
        while session == current do
            Wait(MOVE_POLL_MS)
            if session ~= current then return end
            local coords = GetEntityCoords(PlayerPedId())
            if geometry.distance(coords.x, coords.y, coords.z, current.x, current.y, current.z) > cfg.interact.moveCancel then
                interact.cancel()
                return
            end
        end
    end)
end

--- Fin du geste de récolte : l'animation s'arrête, le serveur décide du résultat (et le notifie).
---@param current vAvA.GatheringSession
local function finish(current)
    if session ~= current then return end
    local token = current.token
    clear()
    -- l'appel attend la réponse du serveur : dans son propre thread, quel que soit le contexte d'appel
    CreateThread(function()
        local ok, success, code = core.rpc.call(RPC.FINISH, token)
        report(ok, success, code)
    end)
end

--- Fin de la barre de tension (pêche) : la tenue est déclarée au serveur, qui décide.
---@param token integer
---@param held boolean
function interact.reel(token, held)
    local current = session
    if not current or current.token ~= token then return end
    clear()
    CreateThread(function()
        local ok, success, code = core.rpc.call(RPC.REEL, token, held)
        report(ok, success, code)
    end)
end

--- La touche ! (évènement du serveur) : la barre de tension prend la main.
---@param token integer
---@return vAvA.GatheringSession|nil
function interact.bite(token)
    local current = session
    if not current or current.token ~= token or current.kind ~= 'fishing' then return nil end
    current.tension = true
    nui.send('cast', { hidden = true })
    return current
end

--- Commence une récolte sur un nœud : le serveur valide tout et annonce la durée.
---@param nodeId string
function interact.begin(nodeId)
    if session then return end
    local node = props.node(nodeId)
    local resource = node and props.resource(node)
    if not node or not resource then return end
    CreateThread(function()
        local ok, success, result = core.rpc.call(RPC.BEGIN, nodeId)
        if not ok or not success or type(result) ~= 'table' then
            report(ok, success, result)
            return
        end
        -- le joueur a pu changer d'avis pendant l'attente
        if session then
            core.rpc.emit(RPC.CANCEL, result.token)
            return
        end
        local coords = GetEntityCoords(PlayerPedId())
        local current = {
            token = result.token, nodeId = nodeId, kind = result.kind == 'fishing' and 'fishing' or 'harvest',
            anim = nil, tension = false, x = coords.x, y = coords.y, z = coords.z,
        }
        session = current
        interact.refreshPrompt(nil)
        current.anim = playAnim(result.anim or resource.anim)
        if session ~= current then return end
        if current.kind == 'fishing' then
            nui.send('cast', { label = result.label or resource.label, key = cfg.keys.interact })
        else
            local durationMs = result.durationMs or resource.durationMs
            progressStart(result.label or resource.label, durationMs)
            SetTimeout(durationMs, function() finish(current) end)
        end
        watchMovement(current)
    end)
end

--- Appui sur la touche : un geste en cours est interrompu (la ligne est remontée), sinon la récolte commence.
--- Pendant la barre de tension, l'appui tend la ligne : fishing.lua le reçoit. À terre, rien : la touche sert à
--- rendre l'âme.
---@return boolean handledByFishing
function interact.press()
    if isDowned() then return false end
    if session then
        if session.tension then return true end
        interact.cancel()
        return false
    end
    local nodeId = props.nearest()
    if nodeId then interact.begin(nodeId) end
    return false
end

props.onNearest(interact.refreshPrompt)
