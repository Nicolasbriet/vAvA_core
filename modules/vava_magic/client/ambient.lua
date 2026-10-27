--[[
    vava_magic/client/ambient.lua
    Rôle : effets de la magie vus par les joueurs proches, d'après les state bags posés par le serveur :
      - incantation : texte d'ambiance au-dessus de la tête (15 m), runes au-dessus des mains ; fragments du
        Murmure lisibles à moins de 3 m (reçus du seul serveur), runes indéchiffrables au-delà ;
      - murmure reçu : « ses yeux s'illuminent » et une brève lueur au visage ;
      - Lueur : lumière dans la main ou orbe près de l'épaule, orbes ancrés (objets cachés, seule la lumière se
        voit) ; scintillement fluide (somme de sinus), jamais tiré au hasard à chaque image ;
      - brûlure : flammes sur la cible.
    Les state bags sont suivis par gestionnaires de changement ; une recherche toutes les 250 ms retient ce qui est à
    portée, et le dessin par image ne tourne que s'il y a quelque chose à dessiner.
    Dépendances : shared/, config.lua, client/state.lua
]]

local pairs, ipairs, type, sin, max, pi, concat = pairs, ipairs, type, math.sin, math.max, math.pi, table.concat
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local AddStateBagChangeHandler, GetEntityFromStateBagName = AddStateBagChangeHandler, GetEntityFromStateBagName
local PlayerPedId, GetEntityCoords, DoesEntityExist, GetPedBoneCoords, GetOffsetFromEntityInWorldCoords, GetPedBoneIndex =
    PlayerPedId, GetEntityCoords, DoesEntityExist, GetPedBoneCoords, GetOffsetFromEntityInWorldCoords, GetPedBoneIndex
local NetworkGetPlayerIndexFromPed, GetPlayerServerId, GetFinalRenderedCamCoord, GetAspectRatio =
    NetworkGetPlayerIndexFromPed, GetPlayerServerId, GetFinalRenderedCamCoord, GetAspectRatio
local SetDrawOrigin, ClearDrawOrigin, DrawSprite, DrawLightWithRange, DrawMarker =
    SetDrawOrigin, ClearDrawOrigin, DrawSprite, DrawLightWithRange, DrawMarker
local SetTextScale, SetTextFont, SetTextProportional, SetTextColour, SetTextOutline, SetTextCentre =
    SetTextScale, SetTextFont, SetTextProportional, SetTextColour, SetTextOutline, SetTextCentre
local BeginTextCommandDisplayText, AddTextComponentSubstringPlayerName, EndTextCommandDisplayText =
    BeginTextCommandDisplayText, AddTextComponentSubstringPlayerName, EndTextCommandDisplayText
local SetEntityVisible, SetEntityCollision = SetEntityVisible, SetEntityCollision
local RequestNamedPtfxAsset, HasNamedPtfxAssetLoaded, UseParticleFxAsset = RequestNamedPtfxAsset, HasNamedPtfxAssetLoaded, UseParticleFxAsset
local StartParticleFxLoopedOnEntityBone, StopParticleFxLooped = StartParticleFxLoopedOnEntityBone, StopParticleFxLooped
local CreateRuntimeTxd, CreateRuntimeTextureFromImage = CreateRuntimeTxd, CreateRuntimeTextureFromImage

local state = VavaMagic.state
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config
local amb = cfg.ambient
local lightCfg = cfg.spells.lueur.render
local fireCfg = cfg.spells.boule_de_feu
local STATES = VavaMagic.STATES

local HEAD_BONE, RIGHT_HAND, LEFT_HAND = 31086, 57005, 18905 -- SKEL_Head, SKEL_R_Hand, SKEL_L_Hand
local MARKER_SPHERE = lightCfg.marker
local HAND_MARKER_SHARE = 0.6        -- marqueur d'une lumière tenue en main, plus petit que l'orbe
local STALE_MS = 3000                -- un state bag sans entité depuis ce délai est oublié
local SCALE_DISTANCE = 5.0           -- en deçà, textes et runes à leur taille ; au-delà, ils rapetissent
local MIN_SCALE = 0.45
local FLAME_LIGHT_SHARE = 0.5        -- lueur d'une cible qui brûle, part de celle de la boule de feu

local ambient = {}
VavaMagic.ambient = ambient

---@type table<string, table<string, { value: any, since: integer }>>  clé → nom du state bag → valeur
local tracked = {}
for _, key in pairs(STATES) do tracked[key] = {} end
---@type table<integer, { words: string[], untilMs: integer }>  lanceur (numéro serveur) → fragments reçus
local fragments = {}
local visible = { texts = {}, runes = {}, glows = {}, lights = {}, orbs = {}, burns = {} }
local drawing = false
---@type table<integer, integer>  ped → effet de flammes
local flames = {}
---@type table<integer, boolean>  orbes ancrés déjà cachés
local hidden = {}

-- texture des runes, chargée depuis le fichier de la ressource
local runesReady = false
do
    local txd = CreateRuntimeTxd(amb.runes.txd)
    runesReady = CreateRuntimeTextureFromImage(txd, amb.runes.texture, amb.runes.file) ~= 0
end

--- Particules de GTA (chargées une fois, à la demande).
---@param asset string
---@return boolean
function ambient.ptfxReady(asset)
    if HasNamedPtfxAssetLoaded(asset) then return true end
    RequestNamedPtfxAsset(asset)
    return false
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

local function stopFlame(ped)
    local handle = flames[ped]
    if handle then StopParticleFxLooped(handle, false) end
    flames[ped] = nil
end

--- Recherche de ce qui est à portée (toutes les `scanMs`).
local function scan()
    local now = GetGameTimer()
    local origin = GetEntityCoords(PlayerPedId())
    local found = { texts = {}, runes = {}, glows = {}, lights = {}, orbs = {}, burns = {} }
    local any = false

    for bagName, entry in pairs(tracked[STATES.CASTING]) do
        local ped = entityOf(tracked[STATES.CASTING], bagName, entry, now)
        local spellCfg = ped and type(entry.value) == 'table' and state.spellConfig(entry.value.spell)
        if spellCfg then
            local distance = geometry.distance(origin, GetEntityCoords(ped))
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
        if ped and type(entry.value) == 'table' and geometry.distance(origin, GetEntityCoords(ped)) <= lightCfg.distance then
            found.lights[#found.lights + 1] = { entity = ped, value = entry.value, phase = (ped % 97) * 0.37 }
            any = true
        end
    end
    for bagName, entry in pairs(tracked[STATES.ORB]) do
        local orb = entityOf(tracked[STATES.ORB], bagName, entry, now)
        if orb and type(entry.value) == 'table' then
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
    local burning = {}
    for bagName, entry in pairs(tracked[STATES.BURN]) do
        local ped = entityOf(tracked[STATES.BURN], bagName, entry, now)
        if ped and geometry.distance(origin, GetEntityCoords(ped)) <= amb.distance * 2 then
            burning[ped] = true
            found.burns[#found.burns + 1] = { ped = ped }
            any = true
            if not flames[ped] and ambient.ptfxReady(fireCfg.fx.asset) then
                UseParticleFxAsset(fireCfg.fx.asset)
                flames[ped] = StartParticleFxLoopedOnEntityBone(fireCfg.fx.burn, ped, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                    GetPedBoneIndex(ped, fireCfg.fx.burnBone), fireCfg.fx.burnScale, false, false, false)
            end
        end
    end
    for ped in pairs(flames) do
        if not burning[ped] then stopFlame(ped) end
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
    DrawLightWithRange(x, y, z, value.r, value.g, value.b, value.range, intensity)
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
        DrawLightWithRange(head.x, head.y, head.z, glowLight.r, glowLight.g, glowLight.b, glowLight.range, glowLight.intensity)
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
        local fire = fireCfg.light
        DrawLightWithRange(p.x, p.y, p.z, fire.r, fire.g, fire.b, fire.range, fire.intensity * FLAME_LIGHT_SHARE)
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
    for ped in pairs(flames) do stopFlame(ped) end
end
