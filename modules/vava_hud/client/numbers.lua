--[[
    vava_hud/client/numbers.lua
    Rôle : chiffres des coups (T-155) : export hitText, projection de l'ancre, suivi tous les followMs tant qu'un
           chiffre vit (aucune boucle au repos), envois à la page (number, numbersMove, numbersClear).
    Dépendances : config_client.lua, shared/numbers.lua, client/core.lua, client/nui.lua, client/pause.lua
]]

local ipairs, pairs, random, floor, abs = ipairs, pairs, math.random, math.floor, math.abs
local remove = table.remove
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local PlayerId, PlayerPedId, GetPlayerServerId, GetPlayerFromServerId, GetPlayerPed, DoesEntityExist =
    PlayerId, PlayerPedId, GetPlayerServerId, GetPlayerFromServerId, GetPlayerPed, DoesEntityExist
local GetPedBoneCoords, GetFinalRenderedCamCoord, GetScreenCoordFromWorldCoord =
    GetPedBoneCoords, GetFinalRenderedCamCoord, GetScreenCoordFromWorldCoord

local core = VavaHud.core
if not core then return end

local cfg = VavaHud.config.numbers
local rules = VavaHud.numberRules
local nui, pause = VavaHud.nui, VavaHud.pause

local numbers = {}
VavaHud.numbers = numbers

local enabled = cfg.enabled
local invalid = rules.checkConfig(cfg)
if invalid then
    core.log.warn('chiffres des coups coupés : %s', invalid)
    enabled = false
end

-- chiffres suivis, du plus ancien au plus récent : { id, key, ped?, x?, y?, z?, side, endsAt, sx, sy, hidden }
local alive = {}
-- ancre → { at, step } (cascade)
local lastByAnchor = {}
local window = { at = -1e12, count = 0 }
local nextId = 0
local looping = false
local visible = false
-- un chiffre envoyé depuis le dernier numbersClear
local shown = false

local function clamp01(value)
    if value < 0 then return 0 end
    if value > 1 then return 1 end
    return value
end

--- Ped d'un joueur ancre (le sien pour un chiffre reçu), ou nil.
local function pedOf(player, side)
    if side == 'taken' or player == GetPlayerServerId(PlayerId()) then return PlayerPedId() end
    local client = GetPlayerFromServerId(player)
    if not client or client == -1 then return nil end
    local ped = GetPlayerPed(client)
    if not ped or ped == 0 then return nil end
    return ped
end

--- Point au-dessus de la tête d'un ped, ou nil.
local function headOf(ped)
    if not DoesEntityExist(ped) then return nil end
    local bone = GetPedBoneCoords(ped, cfg.headBone, 0.0, 0.0, 0.0)
    return bone.x, bone.y, bone.z + cfg.headOffset
end

--- Projection d'une entrée : sx, sy à l'écran, ou nil (hors de l'écran : position de repli d'un chiffre reçu).
local function project(entry)
    local x, y, z = entry.x, entry.y, entry.z
    if entry.ped then x, y, z = headOf(entry.ped) end
    if x then
        local onScreen, sx, sy = GetScreenCoordFromWorldCoord(x, y, z)
        if onScreen then return clamp01(sx), clamp01(sy) end
    end
    if entry.side == 'taken' then return cfg.takenFallback.x, cfg.takenFallback.y end
    return nil
end

local function follow()
    while #alive > 0 do
        Wait(cfg.followMs)
        local now = GetGameTimer()
        local kept, moves = {}, nil
        for _, entry in ipairs(alive) do
            if now < entry.endsAt then
                kept[#kept + 1] = entry
                local sx, sy = project(entry)
                local move = nil
                if not sx then
                    if not entry.hidden then move = { id = entry.id, hidden = true } end
                    entry.hidden = true
                elseif entry.hidden or abs(sx - entry.sx) > cfg.followEpsilon or abs(sy - entry.sy) > cfg.followEpsilon then
                    entry.hidden, entry.sx, entry.sy = false, sx, sy
                    move = { id = entry.id, x = sx, y = sy }
                end
                if move then
                    moves = moves or {}
                    moves[#moves + 1] = move
                end
            end
        end
        alive = kept
        if moves then nui.send('numbersMove', { list = moves }) end
        for key, last in pairs(lastByAnchor) do
            if now - last.at >= cfg.stackMs then lastByAnchor[key] = nil end
        end
    end
    looping = false
end

--- Montre un chiffre (export hitText). Rend true, ou false et le code (docs/api.md, vava_hud).
function numbers.hit(side, anchor, issue, tenths)
    local code = rules.check(side, anchor, issue, tenths)
    if code then return false, code end
    if not enabled or not rules.allowed(pause.numbersMode(), side, cfg.defaultMode) then return false, 'off' end
    if not visible then return false, 'hidden' end
    local now = GetGameTimer()
    if not rules.window(window, now, cfg.maxPerSecond) then return false, 'too_many' end
    local entry = { side = side, endsAt = now + cfg.durationMs, hidden = false }
    local player = rules.player(anchor)
    local x, y, z
    if player then
        local ped = pedOf(player, side)
        if not ped then return false, 'invalid_anchor' end
        entry.ped, entry.key = ped, 'p:' .. player
        x, y, z = headOf(ped)
        if not x and side == 'dealt' then return false, 'invalid_anchor' end
    else
        x, y, z = rules.point(anchor)
        entry.x, entry.y, entry.z = x, y, z
        entry.key = 'c:' .. floor(x + 0.5) .. ':' .. floor(y + 0.5)
    end
    if x then
        local cam = GetFinalRenderedCamCoord()
        local dx, dy, dz = x - cam.x, y - cam.y, z - cam.z
        if dx * dx + dy * dy + dz * dz > cfg.maxDistance * cfg.maxDistance then return false, 'far' end
    end
    local sx, sy = project(entry)
    if not sx then return false, 'offscreen' end
    local shift, last = rules.stack(lastByAnchor[entry.key], now, cfg, random)
    lastByAnchor[entry.key] = last
    local view = rules.compose(side, issue, rules.tenths(tenths), cfg)
    if #alive >= cfg.maxAlive then remove(alive, 1) end
    nextId = nextId + 1
    entry.id, entry.sx, entry.sy = nextId, sx, sy
    alive[#alive + 1] = entry
    shown = true
    nui.send('number', { id = nextId, x = sx, y = sy, dx = shift.dx, dy = shift.dy, text = view.text, sub = view.sub,
        cls = view.cls })
    if not looping then
        looping = true
        CreateThread(follow)
    end
    return true
end

--- Efface tout (HUD masqué, personnage déchargé) : un numbersClear s'il y avait des chiffres ; la boucle s'arrête.
function numbers.clear()
    alive, lastByAnchor = {}, {}
    if shown then
        shown = false
        nui.send('numbersClear', {})
    end
end

--- Visibilité du HUD (main.lua) : masqué → effacé.
function numbers.setVisible(show)
    visible = show == true
    if not visible then numbers.clear() end
end

--- Rythme pour la page (init.numbers).
function numbers.settings()
    return { durationMs = cfg.durationMs, riseVh = cfg.riseVh, followMs = cfg.followMs, maxAlive = cfg.maxAlive,
        maxPerSecond = cfg.maxPerSecond }
end
