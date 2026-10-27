--[[
    vava_magic/client/controls.lua
    Rôle : le mode magie et les contrôles à la souris.
      - Sort prêt dans les mains : choisi dans la roue (ou /sort), gardé par le serveur dans la fiche.
      - Mode magie : sort prêt, mains vides, à pied, debout, droit d'incanter (bridge), aucune fenêtre ouverte. Éveillé
        par la roue, le clic droit ou un sort ; il s'endort après `controls.idleMs` sans viser ni lancer. Éveillé et
        actif, il coupe à chaque image l'attaque, la visée et le changement d'arme de GTA (seule boucle par image du
        fichier) ; endormi, rien ne tourne. Sortir une arme ou monter en véhicule le coupe, le sort reste choisi.
      - Clic droit maintenu : visée (réticule aux couleurs de l'élément, grisé hors de portée ; allure un peu
        ralentie ; aperçu au sol du point, du disque ou de la ligne visés, ou du rayon autour de soi pour une zone
        centrée sur le lanceur). Clic gauche : le sort fait son geste (chaque sort
        déclare le sien, `controls.register`). Molette : sort suivant ou précédent du même élément.
    Le serveur revérifie tout : la visée n'est qu'une proposition.
    Dépendances : shared/, config.lua, client/core.lua, bridge/client.lua, client/nui.lua, client/state.lua,
                  client/hud.lua, client/messages.lua, client/keys.lua, client/aim.lua, client/casting.lua
]]

local ipairs, sort, concat, lower = ipairs, table.sort, table.concat, string.lower
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local PlayerPedId, GetEntityCoords, GetSelectedPedWeapon, IsPedInAnyVehicle, IsPedRagdoll, IsPedFalling, IsEntityDead =
    PlayerPedId, GetEntityCoords, GetSelectedPedWeapon, IsPedInAnyVehicle, IsPedRagdoll, IsPedFalling, IsEntityDead
local IsNuiFocused, IsPauseMenuActive, GetGameplayCamCoord, GetHashKey = IsNuiFocused, IsPauseMenuActive, GetGameplayCamCoord, GetHashKey
local StartShapeTestLosProbe, GetShapeTestResult, DrawMarker, DrawPoly, DrawLine =
    StartShapeTestLosProbe, GetShapeTestResult, DrawMarker, DrawPoly, DrawLine
local DisableControlAction, SetPedMaxMoveBlendRatio = DisableControlAction, SetPedMaxMoveBlendRatio

local core = VavaMagic.core
local bridge = VavaMagic.bridge
local nui = VavaMagic.nui
local state = VavaMagic.state
local hud = VavaMagic.hud
local messages = VavaMagic.messages
local keys = VavaMagic.keys
local aim = VavaMagic.aim
local casting = VavaMagic.casting
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config
local controlsCfg = cfg.controls
local preview = controlsCfg.preview
local RPC = VavaMagic.RPC

local UNARMED = GetHashKey('WEAPON_UNARMED')
-- contrôles de GTA coupés en mode magie : attaque, visée, corps à corps, roue et changement d'arme
local BLOCKED = { 24, 25, 37, 140, 141, 142, 257, 263, 264, 14, 15, 16, 17 }
local CONTROL_SPRINT = 21
-- sonde de visée : décor, objets (le lanceur exclu)
local AIM_FLAGS = 1 + 16
local AIM_OPTIONS = 4
local PROBE_DONE, PROBE_INVALID = 2, 0
local MARKER_SPHERE, MARKER_CYLINDER = 28, 1
local OUT_OF_RANGE = { r = 140, g = 140, b = 140 }

local controls = {}
VavaMagic.controls = controls

---@type table<string, { cast: fun(info: table) }>
local controllers = {}
local awake, active, aiming = false, false, false
-- visée du sort choisi, relue au début de la visée et au changement de sort (pas à chaque image)
local aimSpec = nil
local lastActivity = 0
local running = false
local probe = nil
-- dernier point visé : { point, inRange, hit }
local aimed = { point = nil, inRange = false, hit = false }
local reticleKey = nil

--- Geste d'un sort au clic gauche : `controller.cast(info)` avec info = { aiming, point, inRange, direction, target }.
---@param name string
---@param controller table
function controls.register(name, controller)
    controllers[name] = controller
end

local function touch()
    lastActivity = GetGameTimer()
end

--- La roue des sorts est-elle ouverte ? (le clavier et la souris vont alors à la roue, pas aux sorts)
---@return boolean
local function wheelOpen()
    local wheel = VavaMagic.wheel
    return wheel ~= nil and wheel.isOpen()
end

--- Visée du sort à son niveau : { kind, range, shape, radius, length, width, color } ; nil s'il ne se vise pas
--- (encore).
---@param name string|nil
---@return table|nil
function controls.aimOf(name)
    local spellCfg = name and state.spellConfig(name)
    local level = name and state.level(name)
    if not spellCfg or not level or type(spellCfg.aim) ~= 'table' or spellCfg.aim.kind == 'none' then return nil end
    local spec = spellCfg.aim
    if spec.minLevel and level < spec.minLevel then return nil end
    local levelCfg = spellCfg.levels[level]
    local element = cfg.elements[spellCfg.element]
    return {
        kind = spec.kind, range = spec.reach or levelCfg.reach or levelCfg.range or 0, shape = spec.shape,
        radius = spec.radius and levelCfg[spec.radius] or nil, length = spec.length and levelCfg[spec.length] or nil,
        width = spec.width and levelCfg[spec.width] or nil, color = element and element.color,
    }
end

--- Réticule de la page : montré en visant, aux couleurs de l'élément, grisé hors de portée (envoyé s'il change).
---@param spec table|nil
---@param inRange boolean
local function reticle(spec, inRange)
    local key = spec and (('%d,%d,%d:%s'):format(spec.color.r, spec.color.g, spec.color.b, inRange and 'in' or 'out')) or 'off'
    if key == reticleKey then return end
    reticleKey = key
    if spec then
        nui.send('reticle', { visible = true, color = spec.color, out = not inRange })
    else
        nui.send('reticle', { visible = false })
    end
end

---@param ped integer
---@return boolean
local function conditionsMet(ped)
    if not state.isMage() or not state.selected() or not state.level(state.selected()) then return false end
    if IsEntityDead(ped) or IsPedInAnyVehicle(ped, false) or IsPedRagdoll(ped) or IsPedFalling(ped) then return false end
    if GetSelectedPedWeapon(ped) ~= UNARMED then return false end
    -- la roue a le focus de la page : le mode reste actif derrière elle
    if (IsNuiFocused() and not wheelOpen()) or IsPauseMenuActive() then return false end
    return bridge.CanUseMagic()
end

---@param value boolean
local function setActive(value)
    if active == value then return end
    active = value
    hud.setAwake(value)
    if not value then reticle(nil, false) end
end

--- Quadrilatère au sol (deux triangles, vus de dessus et de dessous) et son contour.
local function groundQuad(c1, c2, c3, c4, color, alpha)
    DrawPoly(c1.x, c1.y, c1.z, c2.x, c2.y, c2.z, c3.x, c3.y, c3.z, color.r, color.g, color.b, alpha)
    DrawPoly(c1.x, c1.y, c1.z, c3.x, c3.y, c3.z, c4.x, c4.y, c4.z, color.r, color.g, color.b, alpha)
    DrawPoly(c3.x, c3.y, c3.z, c2.x, c2.y, c2.z, c1.x, c1.y, c1.z, color.r, color.g, color.b, alpha)
    DrawPoly(c4.x, c4.y, c4.z, c3.x, c3.y, c3.z, c1.x, c1.y, c1.z, color.r, color.g, color.b, alpha)
    for _, edge in ipairs({ { c1, c2 }, { c2, c3 }, { c3, c4 }, { c4, c1 } }) do
        DrawLine(edge[1].x, edge[1].y, edge[1].z, edge[2].x, edge[2].y, edge[2].z, color.r, color.g, color.b, 255)
    end
end

--- Ligne au sol perpendiculaire au regard (mur de flammes) : longueur et largeur du niveau.
local function lineAt(body, point, spec, color)
    local forward = geometry.direction2d(body, point)
    if not forward or not spec.length or not spec.width then return end
    local half, depth = spec.length / 2, (spec.width or 1.0) / 2
    local z = point.z + preview.groundOffset
    local function corner(side, ahead)
        return { x = point.x - forward.y * half * side + forward.x * depth * ahead, y = point.y + forward.x * half * side + forward.y * depth * ahead, z = z }
    end
    groundQuad(corner(1, -1), corner(-1, -1), corner(-1, 1), corner(1, 1), color, preview.alpha)
end

--- Disque au sol (zone en cercle, ou rayon autour de soi).
local function circleAt(point, radius, color)
    local size = radius * 2
    DrawMarker(MARKER_CYLINDER, point.x, point.y, point.z + preview.groundOffset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
        size, size, preview.height, color.r, color.g, color.b, preview.alpha, false, false, 2, false, nil, nil, false)
end

--- Une image de visée : résultat de la sonde lancée à l'image précédente, nouvelle sonde, aperçu au sol.
---@param ped integer
---@param spec table
local function aimFrame(ped, spec)
    local body = GetEntityCoords(ped)
    DisableControlAction(0, CONTROL_SPRINT, true)
    SetPedMaxMoveBlendRatio(ped, controlsCfg.aimMoveBlend)
    -- zone centrée sur le lanceur : pas de sonde, l'aperçu suit ses pieds
    if spec.kind == 'self' then
        aimed.point, aimed.hit, aimed.inRange = { x = body.x, y = body.y, z = body.z - preview.feetOffset }, true, true
        reticle(nil, false)
        if spec.radius then circleAt(aimed.point, spec.radius, spec.color) end
        return
    end
    if probe then
        local status, hit, coords = GetShapeTestResult(probe)
        if status == PROBE_DONE then
            probe = nil
            if hit == 1 or hit == true then
                aimed.point = { x = coords.x, y = coords.y, z = coords.z }
                aimed.hit = true
                aimed.inRange = geometry.distance(body, aimed.point) <= spec.range
            else
                aimed.point, aimed.hit, aimed.inRange = nil, false, false
            end
        elseif status == PROBE_INVALID then
            probe = nil
        end
    end
    if not probe then
        local from = GetGameplayCamCoord()
        local direction = aim.direction()
        local length = spec.range + geometry.distance(from, body)
        probe = StartShapeTestLosProbe(from.x, from.y, from.z, from.x + direction.x * length, from.y + direction.y * length,
            from.z + direction.z * length, AIM_FLAGS, ped, AIM_OPTIONS)
    end
    reticle(spec, aimed.inRange)
    local point = aimed.point
    if spec.kind ~= 'point' or not point then return end
    local color = aimed.inRange and spec.color or OUT_OF_RANGE
    if spec.shape == 'circle' and spec.radius then
        circleAt(point, spec.radius, color)
    elseif spec.shape == 'line' then
        lineAt(body, point, spec, color)
    else
        local size = preview.pointSize
        DrawMarker(MARKER_SPHERE, point.x, point.y, point.z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, size, size, size,
            color.r, color.g, color.b, preview.alpha, false, false, 2, false, nil, nil, false)
    end
end

local function run()
    if running then return end
    running = true
    CreateThread(function()
        local nextCheck, ok = 0, false
        while awake do
            local now = GetGameTimer()
            if aiming then touch() end
            if now - lastActivity > controlsCfg.idleMs and not casting.isCasting() then
                awake = false
                break
            end
            local ped = PlayerPedId()
            if now >= nextCheck then
                nextCheck = now + controlsCfg.conditionsMs
                ok = conditionsMet(ped)
                setActive(ok)
            end
            if ok then
                -- boucle par image justifiée : seulement mode magie éveillé et actif
                for _, control in ipairs(BLOCKED) do DisableControlAction(0, control, true) end
                if aiming and aimSpec then aimFrame(ped, aimSpec) else reticle(nil, false) end
                Wait(0)
            else
                Wait(controlsCfg.conditionsMs)
            end
        end
        aiming = false
        probe = nil
        setActive(false)
        running = false
    end)
end

--- Réveille le mode magie (roue, clic droit, sort lancé).
function controls.wake()
    if not state.isMage() or not state.selected() then return end
    touch()
    if awake then return end
    awake = true
    run()
end

--- Endort le mode magie (sort rangé, retour à la sélection du personnage).
function controls.sleep()
    awake = false
    aiming = false
end

---@return boolean
function controls.isActive()
    return awake and active
end

--- Visée en cours, pour un sort : { aiming, point, inRange, direction, target }.
---@return table
function controls.aimInfo()
    local spec = aiming and controls.aimOf(state.selected())
    return {
        aiming = spec ~= nil, point = spec and aimed.point or nil, inRange = spec ~= nil and aimed.inRange,
        direction = aim.direction(), target = bridge.GetLockedTarget(),
    }
end

--- Choisit le sort prêt dans les mains (nil : ranger la magie) ; le serveur le garde dans la fiche.
---@param name string|nil
---@return boolean
function controls.select(name)
    if name and not state.level(name) then return false end
    local previous = state.selected()
    if not state.setSelected(name) then return false end
    if name ~= previous then core.rpc.emit(RPC.SELECT, name or '') end
    if aiming then aimSpec = controls.aimOf(name) end
    if name then controls.wake() else controls.sleep() end
    return true
end

--- Lance le sort choisi (ou `name`) sans passer par le mode magie : commande de secours, sans visée.
---@param name string|nil
function controls.castNow(name)
    name = name or state.selected()
    if not name then
        messages.refuse('no_spell')
        return
    end
    local controller = controllers[name]
    if not controller or not state.level(name) then
        messages.refuse('unknown_spell')
        return
    end
    controller.cast({ aiming = false, inRange = false, direction = aim.direction(), target = bridge.GetLockedTarget() })
end

--- Sorts connus du même groupe de la roue, dans l'ordre.
---@param name string
---@return string[]
local function siblings(name)
    local spellCfg = state.spellConfig(name)
    local element = spellCfg and cfg.elements[spellCfg.element]
    local group = element and element.group
    local list = {}
    for _, other in ipairs(state.knownSpells()) do
        local otherCfg = state.spellConfig(other)
        local otherElement = cfg.elements[otherCfg.element]
        if otherElement and otherElement.group == group then list[#list + 1] = other end
    end
    sort(list, function(a, b) return (state.spellConfig(a).order or 1000) < (state.spellConfig(b).order or 1000) end)
    return list
end

---@param step integer
local function scroll(step)
    if not controlsCfg.scrollSpells or not controls.isActive() or wheelOpen() then return end
    local name = state.selected()
    local list = name and siblings(name) or {}
    if #list < 2 then return end
    for index, other in ipairs(list) do
        if other == name then
            controls.select(list[(index - 1 + step) % #list + 1])
            return
        end
    end
end

local function onCast()
    -- le clic qui choisit un sort dans la roue ne lance rien
    if not controls.isActive() or wheelOpen() then return end
    local name = state.selected()
    local controller = name and controllers[name]
    if not controller then return end
    touch()
    controller.cast(controls.aimInfo())
end

local function onAimDown()
    if not state.isMage() or not state.selected() or wheelOpen() then return end
    controls.wake()
    aimSpec = controls.aimOf(state.selected())
    aiming = aimSpec ~= nil
end

local function onAimUp()
    aiming = false
    probe = nil
    aimed = { point = nil, inRange = false, hit = false }
    reticle(nil, false)
end

-- le sort choisi n'est plus connu (oublié, plus mage) : le mode s'endort
state.onChange(function()
    if awake and (not state.isMage() or not state.selected()) then controls.sleep() end
end)

keys.bindHold('viser', onAimDown, onAimUp)
keys.bind('lancer', onCast)
keys.bind('suivant', function() scroll(1) end)
keys.bind('precedent', function() scroll(-1) end)

--- Sort désigné dans une commande : son nom (boule_de_feu) ou son libellé, parmi les sorts connus.
---@param word string|nil
---@return string|nil
local function spellNamed(word)
    if not word or word == '' then return nil end
    word = lower(word)
    for _, name in ipairs(state.knownSpells()) do
        if name == word or lower(state.spellConfig(name).label) == word then return name end
    end
    return nil
end

-- /sort <nom> | aucun : choisir le sort prêt sans la roue (secours)
keys.command(cfg.commands.sort, cfg.texts.suggestions.sort, function(args)
    local word = concat(args, ' ')
    if lower(word) == cfg.commands.none then
        controls.select(nil)
        bridge.Notify(cfg.texts.notify.deselected, 'info')
        return
    end
    local name = spellNamed(word)
    if not name then
        local labels = {}
        for _, known in ipairs(state.knownSpells()) do labels[#labels + 1] = known end
        bridge.ChatLines({ cfg.texts.chat.spellUsage:format(concat(labels, ', ')) })
        return
    end
    controls.select(name)
    bridge.Notify(cfg.texts.notify.selected:format(state.spellConfig(name).label), 'info')
end)

-- /lancer [sort] : lancer sans visée (secours)
keys.command(cfg.commands.lancer, cfg.texts.suggestions.lancer, function(args)
    local word = concat(args, ' ')
    local name = word ~= '' and spellNamed(word) or nil
    if word ~= '' and not name then
        messages.refuse('unknown_spell')
        return
    end
    controls.castNow(name)
end)
