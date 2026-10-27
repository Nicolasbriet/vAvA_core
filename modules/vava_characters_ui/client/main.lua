--[[
    vava_characters_ui/client/main.lua
    Rôle : cycle de vie de l'écran de personnages et traitement des retours de l'interface.
      fermé → sélection (hook core:character:selection) ⇄ création → fermé (hook core:character:loaded)
    Le serveur reste maître : liste, création, sélection et suppression sont des intentions validées par le core.
    Dépendances : config.lua, client/core.lua, client/camera.lua, client/preview.lua, client/nui.lua
]]

local type, tostring = type, tostring
local mathType = math.type
local CreateThread = CreateThread
local SetFocusPosAndVel, ClearFocus, RequestCollisionAtCoord, ClearAreaOfPeds = SetFocusPosAndVel, ClearFocus, RequestCollisionAtCoord, ClearAreaOfPeds
local DisplayRadar, DoScreenFadeIn = DisplayRadar, DoScreenFadeIn

local ui = VavaCharactersUi
local core = ui.core
if not core then return end
local cfg = ui.config
local nui, camera, preview, appearance = ui.nui, ui.camera, ui.preview, ui.appearance

local CLEAR_ALL_PEDS = 1

---@alias UiState 'closed'|'selection'|'creator'
---@type UiState
local state = 'closed'

---@param value any
---@return boolean
local function isId(value)
    return type(value) == 'number' and value >= 1 and (mathType(value) == 'integer' or value % 1 == 0)
end

---@param value any
---@return boolean
local function isNumber(value)
    return type(value) == 'number' and value == value
end

--- Réponse homogène à partir du retour d'un appel serveur (ok de transport, succès, résultat ou code).
---@return table
local function serverResult(ok, success, result)
    if not ok then return { ok = false, error = tostring(success) } end
    if not success then return { ok = false, error = tostring(result) } end
    return { ok = true, result = result }
end

---@return table
local function listCharacters()
    local ok, success, characters, max = core.characters.list()
    if not ok or not success then return serverResult(ok, success, characters) end
    return { ok = true, characters = characters, max = max }
end

local function prepareScene()
    local scene = cfg.scene
    SetFocusPosAndVel(scene.x, scene.y, scene.z, 0.0, 0.0, 0.0)
    RequestCollisionAtCoord(scene.x, scene.y, scene.z)
    ClearAreaOfPeds(scene.x, scene.y, scene.z, cfg.clearRadius, CLEAR_ALL_PEDS)
    DisplayRadar(false)
end

local function open()
    if state ~= 'closed' then return end
    state = 'selection'
    CreateThread(function()
        prepareScene()
        camera.show('overview')
        nui.send('open', listCharacters())
        nui.setFocus(true)
        DoScreenFadeIn(cfg.fadeMs)
    end)
end

local function close()
    if state == 'closed' then return end
    state = 'closed'
    nui.send('close')
    nui.setFocus(false)
    preview.destroy()
    camera.close()
    ClearFocus()
    DisplayRadar(true)
end

--- Crée le ped d'aperçu d'un sexe avec son apparence de départ, et renvoie de quoi construire l'éditeur.
---@param sex string
---@return table
local function startModel(sex)
    if not cfg.models[sex] then return { ok = false, error = 'invalid_sex' } end
    local ped = preview.spawn(sex)
    if not ped then return { ok = false, error = 'model_unavailable' } end
    local defaults = appearance:defaultAppearance(sex)
    appearance:apply(ped, defaults)
    return { ok = true, sex = sex, appearance = defaults, limits = appearance:limits(ped) }
end

-- Retours de l'écran de sélection ------------------------------------------------------------------------

nui.on('list', function()
    return listCharacters()
end)

nui.on('play', function(data)
    if state ~= 'selection' or not isId(data.id) then return { ok = false, error = 'wrong_state' } end
    -- en cas de succès, le hook core:character:loaded ferme l'écran
    return serverResult(core.characters.select(data.id))
end)

nui.on('delete', function(data)
    if state ~= 'selection' or not isId(data.id) then return { ok = false, error = 'wrong_state' } end
    local result = serverResult(core.characters.delete(data.id))
    if not result.ok then return result end
    return listCharacters()
end)

-- Retours de l'éditeur ------------------------------------------------------------------------------------

nui.on('startCreator', function(data)
    if state ~= 'selection' then return { ok = false, error = 'wrong_state' } end
    state = 'creator'
    local result = startModel(type(data.sex) == 'string' and data.sex or 'm')
    if not result.ok then
        state = 'selection'
        return result
    end
    result.palettes = appearance:palettes()
    camera.show('body')
    return result
end)

nui.on('setSex', function(data)
    if state ~= 'creator' then return { ok = false, error = 'wrong_state' } end
    return startModel(data.sex)
end)

nui.on('preview', function(data)
    local ped = state == 'creator' and preview.get()
    if not ped or type(data.part) ~= 'string' then return { ok = false } end
    local value = data.value
    if not appearance:applyPart(ped, data.part, value) then return { ok = false } end
    -- un changement de vêtement, d'accessoire ou de coupe change le nombre de variantes disponibles
    if data.part == 'component' then
        return { ok = true, textures = appearance:textureCount(ped, 'component', value.id, value.drawable) }
    elseif data.part == 'prop' then
        return { ok = true, textures = appearance:textureCount(ped, 'prop', value.id, value.drawable) }
    elseif data.part == 'hair' then
        return { ok = true, textures = appearance:textureCount(ped, 'hair', 0, value.style) }
    end
    return { ok = true }
end)

nui.on('textures', function(data)
    local ped = state == 'creator' and preview.get()
    if not ped or type(data.kind) ~= 'string' then return { ok = false } end
    return { ok = true, textures = appearance:textureCount(ped, data.kind, data.id, data.drawable) }
end)

nui.on('applyAll', function(data)
    local ped = state == 'creator' and preview.get()
    if not ped or type(data.appearance) ~= 'table' then return { ok = false } end
    appearance:apply(ped, data.appearance)
    return { ok = true }
end)

nui.on('camera', function(data)
    if state == 'closed' or type(data.view) ~= 'string' then return { ok = false } end
    return { ok = camera.show(data.view) }
end)

nui.on('rotate', function(data)
    if state ~= 'creator' or not isNumber(data.delta) then return { ok = false } end
    local delta = data.delta
    if delta > cfg.rotationMaxStep then delta = cfg.rotationMaxStep elseif delta < -cfg.rotationMaxStep then delta = -cfg.rotationMaxStep end
    preview.rotate(delta)
    return { ok = true }
end)

nui.on('cancelCreator', function()
    if state ~= 'creator' then return { ok = false, error = 'wrong_state' } end
    preview.destroy()
    camera.show('overview')
    state = 'selection'
    return listCharacters()
end)

nui.on('create', function(data)
    if state ~= 'creator' then return { ok = false, error = 'wrong_state' } end
    if type(data.firstName) ~= 'string' or type(data.lastName) ~= 'string' or type(data.sex) ~= 'string'
        or type(data.appearance) ~= 'table' then
        return { ok = false, error = 'invalid_args' }
    end
    local created = serverResult(core.rpc.call(cfg.createRpc, data.firstName, data.lastName, data.sex, data.appearance))
    if not created.ok then return created end
    -- personnage créé : on le joue directement ; le hook core:character:loaded ferme l'écran
    state = 'selection'
    local selected = serverResult(core.characters.select(created.result.id))
    if not selected.ok then
        -- le personnage existe : l'interface revient à la liste plutôt que de rester dans l'éditeur
        selected.created = true
        preview.destroy()
        camera.show('overview')
    end
    return selected
end)

core.hooks.after('core:character:selection', open)
core.hooks.after('core:character:loaded', close)

-- ressource démarrée après la mise en attente du joueur (redémarrage en cours de session)
if core.characters.awaitingSelection() then open() end
