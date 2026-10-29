--[[
    vava_magic/client/ambient.lua
    Rôle : effets de la magie vus par les joueurs proches, d'après les state bags posés par le serveur :
      - incantation : particules dans les deux mains selon l'élément du sort, plus grandes et plus vives selon son
        niveau (une seule main de loin, rien au-delà de la distance des effets) avec la lueur de l'élément ; texte
        d'ambiance au-dessus de la tête (15 m), runes au-dessus des mains ; fragments du Murmure lisibles à moins
        de 3 m (reçus du seul serveur), runes indéchiffrables au-delà ;
      - murmure reçu : « ses yeux s'illuminent » et une brève lueur au visage ;
      - Lueur : lumière dans la main ou orbe près de l'épaule, orbes ancrés (objets cachés, seule la lumière se
        voit) ; scintillement fluide (somme de sinus), jamais tiré au hasard à chaque image ;
      - états élémentaires d'un joueur : flammes (brûlure), gouttes (mouillé), givre (gelé), poussière (chancelant),
        avec la lueur des flammes ; seulement la brûlure de loin, rien au-delà de la distance des effets.
    Les state bags sont suivis par gestionnaires de changement ; une recherche toutes les 250 ms retient ce qui est à
    portée, et le dessin par image ne tourne que s'il y a quelque chose à dessiner. Lumières et particules passent
    par les plafonds de client/fx.lua. Un client peut écrire les state bags de ses propres entités : une lumière n'est
    retenue que si chacun de ses champs est un nombre dans les bornes de la config.
    Dépendances : shared/, config.lua, client/state.lua, client/fx.lua
]]

local pairs, ipairs, next, type, sin, max, pi, concat = pairs, ipairs, next, type, math.sin, math.max, math.pi, table.concat
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local AddStateBagChangeHandler, GetEntityFromStateBagName = AddStateBagChangeHandler, GetEntityFromStateBagName
local PlayerPedId, GetEntityCoords, DoesEntityExist, GetPedBoneCoords, GetOffsetFromEntityInWorldCoords, GetPedBoneIndex =
    PlayerPedId, GetEntityCoords, DoesEntityExist, GetPedBoneCoords, GetOffsetFromEntityInWorldCoords, GetPedBoneIndex
local NetworkGetPlayerIndexFromPed, GetPlayerServerId, GetFinalRenderedCamCoord, GetAspectRatio =
    NetworkGetPlayerIndexFromPed, GetPlayerServerId, GetFinalRenderedCamCoord, GetAspectRatio
local SetDrawOrigin, ClearDrawOrigin, DrawSprite, DrawMarker = SetDrawOrigin, ClearDrawOrigin, DrawSprite, DrawMarker
local SetTextScale, SetTextFont, SetTextProportional, SetTextColour, SetTextOutline, SetTextCentre =
    SetTextScale, SetTextFont, SetTextProportional, SetTextColour, SetTextOutline, SetTextCentre
local BeginTextCommandDisplayText, AddTextComponentSubstringPlayerName, EndTextCommandDisplayText =
    BeginTextCommandDisplayText, AddTextComponentSubstringPlayerName, EndTextCommandDisplayText
local SetEntityVisible, SetEntityCollision = SetEntityVisible, SetEntityCollision
local StartParticleFxLoopedOnEntityBone = StartParticleFxLoopedOnEntityBone
local CreateRuntimeTxd, CreateRuntimeTextureFromImage = CreateRuntimeTxd, CreateRuntimeTextureFromImage

local state = VavaMagic.state
local fx = VavaMagic.fx
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config
local amb = cfg.ambient
local lightCfg = cfg.spells.lueur.render
local statesCfg = cfg.states
local STATES = VavaMagic.STATES

local HEAD_BONE, RIGHT_HAND, LEFT_HAND = 31086, 57005, 18905 -- SKEL_Head, SKEL_R_Hand, SKEL_L_Hand
local MARKER_SPHERE = lightCfg.marker
local HAND_MARKER_SHARE = 0.6        -- marqueur d'une lumière tenue en main, plus petit que l'orbe
local STALE_MS = 3000                -- un state bag sans entité depuis ce délai est oublié
local SCALE_DISTANCE = 5.0           -- en deçà, textes et runes à leur taille ; au-delà, ils rapetissent
local MIN_SCALE = 0.45
local HAND_LIGHT_RANGE = 2.0         -- lueur de l'élément dans les mains pendant l'incantation (mètres, au niveau 1)
local HAND_LIGHT_INTENSITY = 3.0
local COLOR_MAX = 255

-- bornes d'une lumière lue dans un state bag : ce que le serveur peut y poser (niveaux de la Lueur)
local LIGHT_RANGE_MAX, LIGHT_INTENSITY_MAX, LIGHT_FLICKER_MAX = 0, 0, 0
for _, level in ipairs(cfg.spells.lueur.levels) do
    LIGHT_RANGE_MAX = max(LIGHT_RANGE_MAX, level.range)
    LIGHT_INTENSITY_MAX = max(LIGHT_INTENSITY_MAX, level.intensity)
    LIGHT_FLICKER_MAX = max(LIGHT_FLICKER_MAX, level.flicker)
end

local ambient = {}
VavaMagic.ambient = ambient

---@type table<string, table<string, { value: any, since: integer }>>  clé → nom du state bag → valeur
local tracked = {}
for _, key in pairs(STATES) do tracked[key] = {} end
---@type table<integer, { words: string[], untilMs: integer }>  lanceur (numéro serveur) → fragments reçus
local fragments = {}
local visible = { texts = {}, runes = {}, glows = {}, lights = {}, orbs = {}, burns = {}, hands = {} }
local drawing = false
---@type table<integer, table<string, integer>>  ped → état → particule posée sur lui
local marks = {}
-- états montrés sur un joueur, et ceux gardés de loin (effets simplifiés)
local MARKED = { 'burn', 'wet', 'frozen', 'stagger' }
local FAR_MARKED = { burn = true }
---@type table<integer, { spell: string, handles: integer[] }>  ped → particules de ses mains pendant l'incantation
local hands = {}
---@type table<integer, boolean>  orbes ancrés déjà cachés
local hidden = {}

-- texture des runes, chargée depuis le fichier de la ressource
local runesReady
do
    local txd = CreateRuntimeTxd(amb.runes.txd)
    runesReady = CreateRuntimeTextureFromImage(txd, amb.runes.texture, amb.runes.file) ~= 0
end

--- Particules de GTA (chargées à la demande, par client/fx.lua).
---@param asset string
---@return boolean
function ambient.ptfxReady(asset)
    return fx.ptfxReady(asset)
end

--- Fragments du Murmure reçus du serveur (lecteur à moins de 3 m).
---@param caster integer
---@param words string[]
---@param ms integer
function ambient.setFragments(caster, words, ms)
    fragments[caster] = { words = words, untilMs = GetGameTimer() + ms }
end

-- suivi des state bags (aucun appel périodique : FiveM prévient à chaque changement)
for key, list in pairs(tracked) do
    AddStateBagChangeHandler(key, nil, function(bagName, _, value)
        if value == nil then list[bagName] = nil else list[bagName] = { value = value, since = GetGameTimer() } end
    end)
end

---@param value any
---@param high number
---@return boolean
local function bounded(value, high)
    return type(value) == 'number' and value >= 0 and value <= high
end

--- Lumière d'un state bag (lumière portée, orbe ancré), ou nil si un champ manque ou sort des bornes : un client peut
--- écrire ceux de ses propres entités, et une valeur fausse ferait tomber le dessin de tous les effets proches.
---@param value any
---@return table|nil
local function lightOf(value)
    if type(value) ~= 'table' or not bounded(value.r, COLOR_MAX) or not bounded(value.g, COLOR_MAX)
        or not bounded(value.b, COLOR_MAX) or not bounded(value.range, LIGHT_RANGE_MAX)
        or not bounded(value.intensity, LIGHT_INTENSITY_MAX) or not bounded(value.flicker, LIGHT_FLICKER_MAX) then
        return nil
    end
    return value
end

--- Bruit fluide de -1 à 1 (somme de sinus), décalé par une phase propre à chaque lumière.
---@param t number
---@return number
local function smoothNoise(t)
    return 0.5 * sin(t * 1.7) + 0.3 * sin(t * 3.1 + 1.3) + 0.2 * sin(t * 5.9 + 0.4)
end

---@param distance number
---@return number
local function scaleAt(distance)
    if distance <= SCALE_DISTANCE then return 1.0 end
    return max(MIN_SCALE, SCALE_DISTANCE / distance)
end

local function text3d(x, y, z, value, style, scale)
    SetDrawOrigin(x, y, z, 0)
    SetTextScale(0.0, style.scale * scale)
    SetTextFont(style.font)
    SetTextProportional(true)
    SetTextColour(style.r, style.g, style.b, style.alpha)
    SetTextOutline()
    SetTextCentre(true)
    BeginTextCommandDisplayText('STRING')
    AddTextComponentSubstringPlayerName(value)
    EndTextCommandDisplayText(0.0, 0.0)
    ClearDrawOrigin()
end

---@param ped integer
---@return integer|nil
local function serverIdOf(ped)
    local player = NetworkGetPlayerIndexFromPed(ped)
    if not player or player == -1 then return nil end
    return GetPlayerServerId(player)
end

--- Entité d'un state bag suivi, ou nil (oublié s'il n'a plus d'entité depuis un moment).
local function entityOf(list, bagName, entry, now)
    local entity = GetEntityFromStateBagName(bagName)
    if entity == 0 or not DoesEntityExist(entity) then
        if now - entry.since > STALE_MS then list[bagName] = nil end
        return nil
    end
    return entity
end

--- Retire les particules d'états d'un ped (toutes, ou seulement celles qui ne sont plus dans `keep`).
---@param ped integer
---@param keep table|nil
local function stopMarks(ped, keep)
    local list = marks[ped]
    if not list then return end
    for name, handle in pairs(list) do
        if not keep or not keep[name] then
            fx.stopLooped(handle)
            list[name] = nil
        end
    end
    if not next(list) then marks[ped] = nil end
end

--- Pose sur le ped les particules de ses états visibles.
---@param ped integer
---@param shown table<string, true>
local function startMarks(ped, shown)
    local list = marks[ped] or {}
    marks[ped] = list
    for name in pairs(shown) do
        local particle = statesCfg.fx[name]
        if particle and not list[name] then
            list[name] = fx.startLooped(particle.asset, function()
                return StartParticleFxLoopedOnEntityBone(particle.name, ped, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    GetPedBoneIndex(ped, particle.bone), particle.scale, false, false, false)
            end)
        end
    end
end

local function stopHands(ped)
    local entry = hands[ped]
    if not entry then return end
    for _, handle in ipairs(entry.handles) do fx.stopLooped(handle) end
    hands[ped] = nil
end

--- Particules de l'élément dans les mains d'un mage qui incante (les deux de près, une seule de loin).
---@param ped integer
---@param spell string
---@param spellCfg table
---@param level integer
---@param detail string
local function startHands(ped, spell, spellCfg, level, detail)
    local current = hands[ped]
    if current and current.spell == spell then return end
    stopHands(ped)
    local element = cfg.elements[spellCfg.element]
    local particle = element and element.hands
    if not particle then return end
    local scale = particle.scale * ((spellCfg.levelScale and spellCfg.levelScale[level]) or 1.0)
    local bones = detail == fx.FULL and { RIGHT_HAND, LEFT_HAND } or { RIGHT_HAND }
    local entry = { spell = spell, handles = {} }
    for _, bone in ipairs(bones) do
        local handle = fx.startLooped(particle.asset, function()
            return StartParticleFxLoopedOnEntityBone(particle.name, ped, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                GetPedBoneIndex(ped, bone), scale, false, false, false)
        end)
        if handle then entry.handles[#entry.handles + 1] = handle end
    end
    hands[ped] = entry
end

--- Recherche de ce qui est à portée (toutes les `scanMs`).
local function scan()
    local now = GetGameTimer()
    local origin = GetEntityCoords(PlayerPedId())
    local found = { texts = {}, runes = {}, glows = {}, lights = {}, orbs = {}, burns = {}, hands = {} }
    local any = false

    local incanting = {}
    for bagName, entry in pairs(tracked[STATES.CASTING]) do
        local ped = entityOf(tracked[STATES.CASTING], bagName, entry, now)
        local spellCfg = ped and type(entry.value) == 'table' and state.spellConfig(entry.value.spell)
        if spellCfg then
            local position = GetEntityCoords(ped)
            local distance = geometry.distance(origin, position)
            local level = type(entry.value.level) == 'number' and entry.value.level or 1
            local detail = fx.detail(position)
            local element = cfg.elements[spellCfg.element]
            if detail and element then
                incanting[ped] = true
                startHands(ped, entry.value.spell, spellCfg, level, detail)
                found.hands[#found.hands + 1] = { ped = ped, color = element.color, scale = (spellCfg.levelScale and spellCfg.levelScale[level]) or 1.0 }
                any = true
            end
            if distance <= amb.distance then
                if spellCfg.ambientText then found.texts[#found.texts + 1] = { ped = ped, text = amb.textFormat:format(spellCfg.ambientText) } end
                if spellCfg.runes then
                    found.runes[#found.runes + 1] = { ped = ped, caster = serverIdOf(ped), near = distance <= amb.fragmentDistance }
                end
                any = true
            end
        end
    end
    for bagName, entry in pairs(tracked[STATES.GLOW]) do
        local ped = entityOf(tracked[STATES.GLOW], bagName, entry, now)
        if ped and geometry.distance(origin, GetEntityCoords(ped)) <= amb.distance then
            found.glows[#found.glows + 1] = { ped = ped, text = amb.textFormat:format(amb.glowText) }
            any = true
        end
    end
    for bagName, entry in pairs(tracked[STATES.LIGHT]) do
        local ped = entityOf(tracked[STATES.LIGHT], bagName, entry, now)
        if ped and lightOf(entry.value) and geometry.distance(origin, GetEntityCoords(ped)) <= lightCfg.distance then
            found.lights[#found.lights + 1] = { entity = ped, value = entry.value, phase = (ped % 97) * 0.37 }
            any = true
        end
    end
    for bagName, entry in pairs(tracked[STATES.ORB]) do
        local orb = entityOf(tracked[STATES.ORB], bagName, entry, now)
        if orb and lightOf(entry.value) then
            if not hidden[orb] then
                SetEntityVisible(orb, false, false)
                SetEntityCollision(orb, false, false)
                hidden[orb] = true
            end
            if geometry.distance(origin, GetEntityCoords(orb)) <= lightCfg.distance then
                found.orbs[#found.orbs + 1] = { entity = orb, value = entry.value, phase = (orb % 97) * 0.37 }
                any = true
            end
        end
    end
    local marked = {}
    for bagName, entry in pairs(tracked[STATES.CONDITIONS]) do
        local ped = entityOf(tracked[STATES.CONDITIONS], bagName, entry, now)
        local value = ped and type(entry.value) == 'table' and entry.value
        local detail = value and fx.detail(GetEntityCoords(ped))
        if detail then
            local shown = {}
            for _, name in ipairs(MARKED) do
                if value[name] and (detail == fx.FULL or FAR_MARKED[name]) then shown[name] = true end
            end
            if next(shown) then
                marked[ped] = shown
                startMarks(ped, shown)
                if shown.burn then found.burns[#found.burns + 1] = { ped = ped } end
                any = true
            end
        end
    end
    for ped in pairs(marks) do stopMarks(ped, marked[ped]) end
    for ped in pairs(hands) do
        if not incanting[ped] then stopHands(ped) end
    end
    for orb in pairs(hidden) do
        if not DoesEntityExist(orb) then hidden[orb] = nil end
    end
    for caster, entry in pairs(fragments) do
        if now > entry.untilMs then fragments[caster] = nil end
    end
    visible = found
    return any
end

local function drawRunes(x, y, z, scale, t)
    if not runesReady then return end
    local runes = amb.runes
    local size = runes.size * scale
    SetDrawOrigin(x, y, z, 0)
    DrawSprite(runes.txd, runes.texture, 0.0, 0.0, size, size * GetAspectRatio(false), (t * runes.spin) % 360.0,
        runes.r, runes.g, runes.b, runes.alpha)
    ClearDrawOrigin()
end

local function drawFragments(x, y, z, words, scale)
    local style = amb.fragments
    local lines, line = {}, {}
    for _, word in ipairs(words) do
        line[#line + 1] = word
        if #line >= style.lineWords then
            lines[#lines + 1] = concat(line, '   ')
            line = {}
        end
    end
    if #line > 0 then lines[#lines + 1] = concat(line, '   ') end
    for index, value in ipairs(lines) do
        text3d(x, y, z + style.lineHeight * index, value, style, scale)
    end
end

--- Position d'une lumière portée : main droite ou orbe près de l'épaule, qui flotte.
local function lightPosition(ped, mode, t)
    if mode == 'hand' then
        local o = lightCfg.handOffset
        return GetPedBoneCoords(ped, lightCfg.handBone, o.x, o.y, o.z)
    end
    local o = lightCfg.orbOffset
    return GetOffsetFromEntityInWorldCoords(ped, o.x, o.y, o.z + lightCfg.bob * sin(t * lightCfg.bobSpeed * 2 * pi))
end

local function drawLight(x, y, z, value, t, phase, markerShare)
    local intensity = value.intensity * (1 + value.flicker * smoothNoise(t * lightCfg.flickerSpeed + phase))
    fx.light(x, y, z, value.r, value.g, value.b, value.range, intensity)
    local s = lightCfg.markerScale * markerShare
    DrawMarker(MARKER_SPHERE, x, y, z, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0, s, s, s, value.r, value.g, value.b,
        lightCfg.markerAlpha, false, false, 2, false, nil, nil, false)
end

local function draw()
    local now = GetGameTimer()
    local t = now / 1000.0
    local camera = GetFinalRenderedCamCoord()
    local view = visible
    for _, item in ipairs(view.texts) do
        local head = GetPedBoneCoords(item.ped, HEAD_BONE, 0.0, 0.0, 0.0)
        text3d(head.x, head.y, head.z + amb.headOffset, item.text, amb.text, scaleAt(geometry.distance(camera, head)))
    end
    for _, item in ipairs(view.runes) do
        local right = GetPedBoneCoords(item.ped, RIGHT_HAND, 0.0, 0.0, 0.0)
        local left = GetPedBoneCoords(item.ped, LEFT_HAND, 0.0, 0.0, 0.0)
        local x, y, z = (right.x + left.x) / 2, (right.y + left.y) / 2, (right.z + left.z) / 2 + amb.handsOffset
        local scale = scaleAt(geometry.distance(camera, right))
        drawRunes(x, y, z, scale, t)
        local words = item.near and item.caster and fragments[item.caster]
        if words and now <= words.untilMs then drawFragments(x, y, z, words.words, scale) end
    end
    for _, item in ipairs(view.glows) do
        local head = GetPedBoneCoords(item.ped, HEAD_BONE, 0.0, 0.0, 0.0)
        local glowLight = amb.glowLight
        fx.light(head.x, head.y, head.z, glowLight.r, glowLight.g, glowLight.b, glowLight.range, glowLight.intensity)
        text3d(head.x, head.y, head.z + amb.headOffset, item.text, amb.text, scaleAt(geometry.distance(camera, head)))
    end
    for _, item in ipairs(view.lights) do
        local p = lightPosition(item.entity, item.value.mode, t + item.phase)
        drawLight(p.x, p.y, p.z, item.value, t, item.phase, item.value.mode == 'hand' and HAND_MARKER_SHARE or 1.0)
    end
    for _, item in ipairs(view.orbs) do
        local p = GetEntityCoords(item.entity)
        drawLight(p.x, p.y, p.z + lightCfg.bob * sin((t + item.phase) * lightCfg.bobSpeed * 2 * pi), item.value, t, item.phase, 1.0)
    end
    for _, item in ipairs(view.burns) do
        local p = GetEntityCoords(item.ped)
        local fire = statesCfg.burnLight
        fx.light(p.x, p.y, p.z, fire.r, fire.g, fire.b, fire.range, fire.intensity)
    end
    for _, item in ipairs(view.hands) do
        local p = GetPedBoneCoords(item.ped, RIGHT_HAND, 0.0, 0.0, 0.0)
        local color = item.color
        fx.light(p.x, p.y, p.z, color.r, color.g, color.b, HAND_LIGHT_RANGE * item.scale, HAND_LIGHT_INTENSITY * item.scale)
    end
end

CreateThread(function()
    while true do
        Wait(amb.scanMs)
        local any = scan()
        if any and not drawing then
            drawing = true
            CreateThread(function()
                -- boucle par image justifiée : seulement tant qu'un effet de magie est à portée
                while drawing do
                    draw()
                    Wait(0)
                end
            end)
        elseif not any then
            drawing = false
        end
    end
end)

--- Arrêt du module : flammes éteintes.
function ambient.stop()
    drawing = false
    for ped in pairs(marks) do stopMarks(ped) end
    for ped in pairs(hands) do stopHands(ped) end
end
