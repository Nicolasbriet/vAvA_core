--[[
    vava_farming/client/interact.lua
    Rôle : l'agriculture côté joueur. Invite près d'un emplacement (culture, état, stade), d'un puits ou d'un grenier ;
           menu d'emplacement demandé au serveur (open) et affiché avec le focus ; geste (planter, arroser, fertiliser,
           récolter, arracher) : animation, barre du HUD, fin au bout de la durée annoncée, interruption par déplacement
           ou nouvel appui ; remplissage du seau au puits (courte animation locale) ; ouverture du grenier commun. Le
           client ne décide de rien : il montre, joue et demande ; le serveur applique et notifie.
    Dépendances : shared/constants.lua, config.lua, client/core.lua, client/nui.lua, client/props.lua
]]

local type, tostring, pcall = type, tostring, pcall
local CreateThread, Wait, SetTimeout, GetGameTimer = CreateThread, Wait, SetTimeout, GetGameTimer
local PlayerPedId, GetEntityCoords, GetResourceState = PlayerPedId, GetEntityCoords, GetResourceState
local TaskStartScenarioInPlace, TaskPlayAnim, ClearPedTasks = TaskStartScenarioInPlace, TaskPlayAnim, ClearPedTasks
local RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict = RequestAnimDict, HasAnimDictLoaded, RemoveAnimDict
local sqrt = math.sqrt

local core = VavaFarming.core
if not core then return end

local cfg = VavaFarming.config
local nui = VavaFarming.nui
local props = VavaFarming.props
local RPC = VavaFarming.RPC

local HUD = 'vava_hud'
local PROGRESS_ID = 'vava_farming:work'
local MOVE_POLL_MS = 250
local ANIM_LOAD_MS = 5000
local ANIM_BLEND = 8.0
-- remplissage du seau : geste court joué localement, le serveur applique tout de suite
local FILL_ANIM_MS = 1500

local interact = {}
VavaFarming.interact = interact

---@class vAvA.FarmingWork
---@field token integer
---@field parcel string
---@field index integer
---@field action string
---@field anim string|nil   dictionnaire chargé, à libérer
---@field x number
---@field y number
---@field z number

---@type vAvA.FarmingWork|nil
local work = nil
-- menu ouvert sur un emplacement : { parcel, index }
local menuSlot = nil
-- geste local de remplissage en cours
local filling = false
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

-- Invite ------------------------------------------------------------------------------------------------------------

--- Invite pour la cible la plus proche (ou rien) ; envoyée à l'interface seulement si elle change.
---@param target table|nil
function interact.refreshPrompt(target)
    if not target or work or menuSlot or filling then
        if lastPrompt ~= '' then
            lastPrompt = ''
            nui.send('prompt', { hidden = true })
        end
        return
    end
    local payload, signature
    if target.kind == 'slot' then
        local parcel = props.parcel(target.parcel)
        local slot = props.slot(target.parcel, target.index)
        local crop = props.crop(slot.crop)
        if not parcel then return end
        payload = {
            kind = 'slot', key = cfg.keys.interact, parcelLabel = parcel.label, index = target.index,
            crop = slot.crop, cropLabel = crop and crop.label or nil, state = slot.state,
            stage = slot.stage, stages = crop and #crop.stages or 0,
        }
        signature = table.concat({ 'slot', target.parcel, target.index, tostring(slot.crop), tostring(slot.state), tostring(slot.stage) }, '|')
    elseif target.kind == 'well' then
        local well = props.well(target.well)
        if not well then return end
        payload = { kind = 'well', key = cfg.keys.interact, label = well.label }
        signature = 'well|' .. target.well
    elseif target.kind == 'granary' then
        local parcel = props.parcel(target.parcel)
        if not parcel or not parcel.granary then return end
        payload = { kind = 'granary', key = cfg.keys.interact, label = parcel.granary.label or parcel.label }
        signature = 'granary|' .. target.parcel
    else
        return
    end
    if signature == lastPrompt then return end
    lastPrompt = signature
    nui.send('prompt', payload)
end

--- Codes que le serveur a déjà commentés au joueur (notification) : l'interface ne les répète pas.
local SERVER_NOTIFIED = {
    occupied = true, empty = true, no_seed = true, no_bucket = true, bucket_empty = true, no_compost = true,
    not_ripe = true, dead = true, no_space = true, no_access = true,
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

---@return table|nil  { parcel, index }
function interact.menuSlot()
    return menuSlot
end

--- Ferme le menu (l'interface est prévenue, le focus rendu).
function interact.closeMenu()
    if not menuSlot then return end
    menuSlot = nil
    nui.send('menuClose')
    nui.setFocus(false)
    interact.refreshPrompt(props.nearest())
end

--- Ouvre le menu d'un emplacement : le serveur dit ce que le joueur peut y faire.
---@param parcelId string
---@param index integer
function interact.openMenu(parcelId, index)
    if menuSlot or work then return end
    CreateThread(function()
        local ok, success, menu = core.rpc.call(RPC.OPEN, parcelId, index)
        if not ok or not success or type(menu) ~= 'table' then
            interact.report(ok, success, menu)
            return
        end
        -- le joueur a pu changer d'avis pendant l'attente
        if menuSlot or work or not core.characters.current() then return end
        menuSlot = { parcel = parcelId, index = index }
        menu.key = cfg.keys.interact
        nui.send('menu', menu)
        nui.setFocus(true)
        interact.refreshPrompt(nil)
    end)
end

--- Relit le menu de l'emplacement ouvert. Bloque le thread appelant.
---@return table réponse pour l'interface
function interact.refreshMenu()
    if not menuSlot then return { ok = false, error = 'not_found' } end
    local ok, success, menu = core.rpc.call(RPC.OPEN, menuSlot.parcel, menuSlot.index)
    if not ok then return { ok = false, error = tostring(success) } end
    if not success or type(menu) ~= 'table' then return { ok = false, error = tostring(menu) } end
    menu.key = cfg.keys.interact
    return { ok = true, menu = menu }
end

--- L'emplacement ouvert a changé (évènement du serveur) : l'interface le met à jour.
---@param payload table
function interact.onSlot(payload)
    if type(payload) ~= 'table' or not menuSlot then return end
    if payload.parcel == menuSlot.parcel and payload.index == menuSlot.index then nui.send('slot', payload) end
end

-- Geste --------------------------------------------------------------------------------------------------------------

---@return vAvA.FarmingWork|nil
function interact.work()
    return work
end

local function clear()
    if not work then return end
    local current = work
    work = nil
    stopAnim(current.anim)
    interact.refreshPrompt(props.nearest())
end

--- Interrompt le geste en cours : le serveur est prévenu, l'animation et la barre s'arrêtent.
function interact.cancel()
    if not work then return end
    local token = work.token
    progressCancel()
    clear()
    core.rpc.emit(RPC.CANCEL, token)
end

---@param current vAvA.FarmingWork
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

--- Fin du geste : l'animation s'arrête, le serveur applique et rend le résultat (montré par l'interface).
---@param current vAvA.FarmingWork
local function finish(current)
    if work ~= current then return end
    local token = current.token
    clear()
    -- l'appel attend la réponse du serveur : dans son propre thread, quel que soit le contexte d'appel
    CreateThread(function()
        local ok, success, result = core.rpc.call(RPC.FINISH, token)
        if ok and success and type(result) == 'table' then
            nui.send('result', result)
        else
            interact.report(ok, success, result)
        end
    end)
end

--- Le serveur a accepté un geste : le menu se ferme, le geste commence.
---@param parcelId string
---@param index integer
---@param action string
---@param result table  { token, durationMs, anim, label }
function interact.startWork(parcelId, index, action, result)
    if work then return end
    if menuSlot then
        menuSlot = nil
        nui.send('menuClose')
        nui.setFocus(false)
    end
    local coords = GetEntityCoords(PlayerPedId())
    local current = { token = result.token, parcel = parcelId, index = index, action = action, anim = nil, x = coords.x, y = coords.y, z = coords.z }
    work = current
    interact.refreshPrompt(nil)
    CreateThread(function()
        local actionCfg = cfg.actions[action]
        current.anim = playAnim(result.anim or (actionCfg and actionCfg.anim) or 'plant')
        if work ~= current then return end
        local durationMs = result.durationMs or (actionCfg and actionCfg.durationMs) or 3000
        progressStart(result.label or '', durationMs)
        SetTimeout(durationMs, function() finish(current) end)
        watchMovement(current)
    end)
end

-- Puits et grenier -------------------------------------------------------------------------------------------------------

--- Remplit le seau tenu au puits : courte animation locale, le serveur applique aussitôt.
---@param wellId string
function interact.fill(wellId)
    if work or menuSlot or filling then return end
    filling = true
    interact.refreshPrompt(nil)
    CreateThread(function()
        local dict = playAnim('fill')
        local ok, success, result = core.rpc.call(RPC.FILL, wellId)
        -- le geste dure au moins le temps de l'animation, même si le serveur a déjà répondu
        Wait(FILL_ANIM_MS)
        stopAnim(dict)
        filling = false
        interact.refreshPrompt(props.nearest())
        if ok and success and type(result) == 'table' then
            nui.send('filled', result)
        else
            interact.report(ok, success, result)
        end
    end)
end

--- Ouvre le grenier commun d'une parcelle : le serveur ouvre le conteneur dans l'inventaire.
---@param parcelId string
function interact.granary(parcelId)
    if work or menuSlot or filling then return end
    CreateThread(function()
        local ok, success, code = core.rpc.call(RPC.GRANARY, parcelId)
        interact.report(ok, success, code)
    end)
end

--- Appui sur la touche : un geste en cours est interrompu, un menu ouvert se ferme, sinon la cible la plus proche.
function interact.press()
    if work then
        interact.cancel()
        return
    end
    if menuSlot then
        interact.closeMenu()
        return
    end
    local target = props.nearest()
    if not target then return end
    if target.kind == 'slot' then
        interact.openMenu(target.parcel, target.index)
    elseif target.kind == 'well' then
        interact.fill(target.well)
    elseif target.kind == 'granary' then
        interact.granary(target.parcel)
    end
end

--- Tout fermer (déchargement du personnage).
function interact.reset()
    interact.cancel()
    if menuSlot then
        menuSlot = nil
        nui.send('menuClose')
    end
    nui.setFocus(false)
end

props.onNearest(interact.refreshPrompt)
