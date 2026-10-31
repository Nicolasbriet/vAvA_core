--[[
    vava_crafting/client/interact.lua
    Rôle : l'artisanat côté joueur. Invite près d'une station (nom, type, occupation, combustible), menu de station
           demandé au serveur (open) et affiché avec le focus, geste d'une pièce ou d'une réparation (animation, barre
           du HUD, fin au bout de la durée annoncée, interruption par déplacement ou nouvel appui), résultat et boîte de
           baptême d'un chef-d'œuvre, focus partagé entre le menu et la boîte. À terre (vava_health), ni invite ni
           demande. Le client ne décide de rien : il montre, joue et demande ; le serveur notifie les résultats.
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua, client/nui.lua, client/props.lua
]]

local type, tostring, pcall = type, tostring, pcall
local CreateThread, Wait, SetTimeout, GetGameTimer = CreateThread, Wait, SetTimeout, GetGameTimer
local PlayerPedId, GetEntityCoords, GetResourceState = PlayerPedId, GetEntityCoords, GetResourceState
local TaskStartScenarioInPlace, TaskPlayAnim, ClearPedTasks = TaskStartScenarioInPlace, TaskPlayAnim, ClearPedTasks
local RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict = RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict
local sqrt = math.sqrt

local core = VavaCrafting.core
if not core then return end

local cfg = VavaCrafting.config
local nui = VavaCrafting.nui
local props = VavaCrafting.props
local RPC = VavaCrafting.RPC

local HUD = 'vava_hud'
local HEALTH = 'vava_health'
local PROGRESS_ID = 'vava_crafting:work'
local MOVE_POLL_MS = 250
local ANIM_LOAD_MS = 5000
local ANIM_BLEND = 8.0

local interact = {}
VavaCrafting.interact = interact

---@class vAvA.CraftingWork
---@field token integer
---@field stationId string
---@field kind 'craft'|'repair'
---@field anim string|nil   dictionnaire chargé, à libérer
---@field x number
---@field y number
---@field z number

---@type vAvA.CraftingWork|nil
local work = nil
-- menu ouvert sur une station ; boîte de baptême affichée : les deux prennent le focus
local menuStation = nil
local naming = false
local lastPrompt = ''

-- Animation ---------------------------------------------------------------------------------------------------------

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

-- Focus et invite -----------------------------------------------------------------------------------------------------

--- Le focus de l'interface suit le menu et la boîte de baptême.
local function refocus()
    nui.setFocus(menuStation ~= nil or naming)
end

local function healthState()
    return exports[HEALTH]:get()
end

--- Le joueur local est-il à terre ? (export client de vava_health, lu à l'appui et à l'invite, donc au rythme de la
--- boucle des props et seulement près d'une station) Module absent ou en erreur : pas à terre. À terre, la touche ne
--- sert qu'à rendre l'âme ; le serveur refuse de toute façon.
---@return boolean
local function isDowned()
    if GetResourceState(HEALTH) ~= 'started' then return false end
    local called, health = pcall(healthState)
    return called and type(health) == 'table' and health.downed == true
end

--- Invite pour la station la plus proche (ou rien) ; envoyée à l'interface seulement si elle change. Nom du type et
--- réserve : lus dans le dessin de la station (T-144).
---@param stationId string|nil
function interact.refreshPrompt(stationId)
    local station = stationId and props.station(stationId)
    if not station or work or menuStation or isDowned() then
        if lastPrompt ~= '' then
            lastPrompt = ''
            nui.send('prompt', { hidden = true })
        end
        return
    end
    local state = props.state(station.id)
    local payload = {
        key = cfg.keys.interact, label = station.label, typeLabel = station.typeLabel, busy = state.busy,
        fuel = station.capacity and { stock = state.fuel, capacity = station.capacity } or nil,
    }
    local signature = table.concat({
        station.id, station.label, station.typeLabel, tostring(station.capacity), tostring(state.busy), tostring(state.fuel),
    }, '|')
    if signature == lastPrompt then return end
    lastPrompt = signature
    nui.send('prompt', payload)
end

--- Codes que le serveur a déjà commentés au joueur (notification) : l'interface ne les répète pas.
local SERVER_NOTIFIED = {
    no_tool = true, wrong_tool = true, broken_tool = true, no_fuel = true, missing_items = true, no_space = true,
    busy = true, no_access = true,
}

--- Refus ou erreur de transport : code traduit et affiché par l'interface (textes dans web/js/strings.js).
---@param ok boolean
---@param success any
---@param code any
function interact.report(ok, success, code)
    if not ok then
        nui.send('error', { code = tostring(success) })
    elseif not success and not SERVER_NOTIFIED[code] then
        nui.send('error', { code = tostring(code) })
    end
end

-- Menu ---------------------------------------------------------------------------------------------------------------

---@return string|nil
function interact.menuStation()
    return menuStation
end

--- Ferme le menu (l'interface est prévenue, le focus rendu si rien d'autre ne le garde).
function interact.closeMenu()
    if not menuStation then return end
    menuStation = nil
    nui.send('menuClose')
    refocus()
    interact.refreshPrompt((props.nearest()))
end

--- Ouvre le menu d'une station : le serveur dit ce que le joueur peut y faire.
---@param stationId string
function interact.openMenu(stationId)
    if menuStation or work then return end
    CreateThread(function()
        local ok, success, menu = core.rpc.call(RPC.OPEN, stationId)
        if not ok or not success or type(menu) ~= 'table' then
            interact.report(ok, success, menu)
            return
        end
        -- le joueur a pu changer d'avis pendant l'attente
        if menuStation or work or not core.characters.current() then return end
        menuStation = stationId
        menu.key = cfg.keys.interact
        nui.send('menu', menu)
        refocus()
        interact.refreshPrompt(nil)
    end)
end

--- Relit le menu de la station ouverte. Bloque le thread appelant.
---@return table réponse pour l'interface
function interact.refreshMenu()
    if not menuStation then return { ok = false, error = 'not_found' } end
    local ok, success, menu = core.rpc.call(RPC.OPEN, menuStation)
    if not ok then return { ok = false, error = tostring(success) } end
    if not success or type(menu) ~= 'table' then return { ok = false, error = tostring(menu) } end
    menu.key = cfg.keys.interact
    return { ok = true, menu = menu }
end

--- La station ouverte a changé (combustible, occupation, reçus par sa zone) : l'interface la met à jour.
---@param payload table
function interact.onStation(payload)
    if type(payload) == 'table' and menuStation and payload.id == menuStation then nui.send('station', payload) end
end

-- Geste --------------------------------------------------------------------------------------------------------------

---@return vAvA.CraftingWork|nil
function interact.work()
    return work
end

local function clear()
    if not work then return end
    local current = work
    work = nil
    stopAnim(current.anim)
    interact.refreshPrompt((props.nearest()))
end

--- Interrompt le geste en cours : le serveur est prévenu, l'animation et la barre s'arrêtent.
function interact.cancel()
    if not work then return end
    local token = work.token
    progressCancel()
    clear()
    core.rpc.emit(RPC.CANCEL, token)
end

---@param current vAvA.CraftingWork
local function watchMovement(current)
    CreateThread(function()
        while work == current do
            Wait(MOVE_POLL_MS)
            if work ~= current then return end
            local coords = GetEntityCoords(PlayerPedId())
            local dx, dy, dz = coords.x - current.x, coords.y - current.y, coords.z - current.z
            if sqrt(dx * dx + dy * dy + dz * dz) > cfg.interact.moveCancel then
                interact.cancel()
                return
            end
        end
    end)
end

--- Fin du geste : l'animation s'arrête, le serveur décide du résultat (et le notifie).
---@param current vAvA.CraftingWork
local function finish(current)
    if work ~= current then return end
    local token = current.token
    clear()
    -- l'appel attend la réponse du serveur : dans son propre thread, quel que soit le contexte d'appel
    CreateThread(function()
        local ok, success, code = core.rpc.call(RPC.FINISH, token)
        interact.report(ok, success, code)
    end)
end

--- Le serveur a accepté une pièce ou une réparation : le menu se ferme, le geste commence.
---@param stationId string
---@param kind 'craft'|'repair'
---@param result table  { token, durationMs, anim, label }
function interact.startWork(stationId, kind, result)
    if work then return end
    if menuStation then
        menuStation = nil
        nui.send('menuClose')
        refocus()
    end
    local coords = GetEntityCoords(PlayerPedId())
    local current = { token = result.token, stationId = stationId, kind = kind, anim = nil, x = coords.x, y = coords.y, z = coords.z }
    work = current
    interact.refreshPrompt(nil)
    CreateThread(function()
        current.anim = playAnim(type(result.anim) == 'string' and result.anim or '')
        if work ~= current then return end
        local durationMs = result.durationMs or cfg.repair.durationMs
        progressStart(result.label or '', durationMs)
        SetTimeout(durationMs, function() finish(current) end)
        watchMovement(current)
    end)
end

-- Résultat et baptême --------------------------------------------------------------------------------------------------

--- Résultat d'une pièce ou d'une réparation (évènement du serveur) : l'interface le montre ; un chef-d'œuvre peut
--- être baptisé, la boîte prend le focus.
---@param payload table
function interact.onCrafted(payload)
    if type(payload) ~= 'table' then return end
    payload.nameMin, payload.nameMax = cfg.masterpiece.nameMin, cfg.masterpiece.nameMax
    nui.send('crafted', payload)
    if payload.nameable and payload.instanceId then
        naming = true
        refocus()
    end
end

--- La boîte de baptême s'est fermée (baptisé, plus tard, ou délai écoulé).
function interact.onNamingClosed()
    if not naming then return end
    naming = false
    refocus()
end

--- Appui sur la touche : un geste en cours est interrompu, un menu ouvert se ferme, sinon la station la plus proche
--- s'ouvre. À terre, rien : la touche sert à rendre l'âme.
function interact.press()
    if isDowned() then return end
    if work then
        interact.cancel()
        return
    end
    if menuStation then
        interact.closeMenu()
        return
    end
    local stationId = props.nearest()
    if stationId then interact.openMenu(stationId) end
end

--- Tout fermer (déchargement du personnage).
function interact.reset()
    interact.cancel()
    naming = false
    if menuStation then
        menuStation = nil
        nui.send('menuClose')
    end
    nui.send('namingClose')
    refocus()
end

props.onNearest(interact.refreshPrompt)
-- combustible et occupation reçus par la zone de la station : le menu ouvert sur elle suit
props.onStatus(function(stationId, status)
    interact.onStation({ id = stationId, fuel = status.fuel, busy = status.busy })
end)
-- station oubliée (le joueur s'en est éloigné, elle a été retirée) : son menu ne reste pas ouvert, figé
props.onForget(function(stationId)
    if menuStation == stationId then interact.closeMenu() end
end)
