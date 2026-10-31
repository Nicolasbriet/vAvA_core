--[[
    vava_chat/client/overhead.lua
    Rôle : /me et /do écrits quelques secondes au-dessus de la tête de leur auteur, pour les joueurs à portée qui le
           voient (ligne de vue relue toutes les `overhead.sightMs`, pas à chaque image). Les dernières lignes
           s'empilent, les plus anciennes en haut. Le dessin tourne à chaque image seulement tant qu'une ligne est en
           vie ; sans /me ni /do récent, aucune boucle. Les codes de mise en forme de GTA (~r~…) sont retirés.
    Dépendances : shared/text.lua, config_client.lua
]]

local pairs, next, max, format, gsub, byte, sub, remove =
    pairs, next, math.max, string.format, string.gsub, string.byte, string.sub, table.remove
local CreateThread, Wait, GetGameTimer, GetPlayerFromServerId, GetPlayerPed, PlayerPedId, DoesEntityExist,
    GetEntityCoords, GetPedBoneCoords, HasEntityClearLosToEntity =
    CreateThread, Wait, GetGameTimer, GetPlayerFromServerId, GetPlayerPed, PlayerPedId, DoesEntityExist,
    GetEntityCoords, GetPedBoneCoords, HasEntityClearLosToEntity
local SetDrawOrigin, ClearDrawOrigin, SetTextScale, SetTextFont, SetTextProportional, SetTextColour, SetTextOutline,
    SetTextCentre, BeginTextCommandDisplayText, AddTextComponentSubstringPlayerName, EndTextCommandDisplayText =
    SetDrawOrigin, ClearDrawOrigin, SetTextScale, SetTextFont, SetTextProportional, SetTextColour, SetTextOutline,
    SetTextCentre, BeginTextCommandDisplayText, AddTextComponentSubstringPlayerName, EndTextCommandDisplayText

local text = VavaChat.text
local cfg = VavaChat.config.overhead
local texts = VavaChat.config.texts.overhead
-- GTA lit au plus 99 octets par morceau de texte : un message est coupé en morceaux, jamais au milieu d'un caractère
local CHUNK_BYTES = 96
local CONTINUATION_LOW, CONTINUATION_HIGH = 0x80, 0xBF
-- ligne de vue : carte, objets, végétation exclus (17 = monde + objets)
local SIGHT_FLAGS = 17
local NO_PLAYER = -1
-- codes de mise en forme de GTA (~r~, ~n~, ~INPUT_…~)
local GTA_CODES = '~[^~]*~'

local overhead = {}
VavaChat.overhead = overhead

-- [numéro de joueur] = { player, visible, lines = { { parts, color, expires } } }
local entries = {}
local drawing = false

--- Texte découpé en morceaux d'au plus CHUNK_BYTES octets.
---@param value string
---@return string[]
local function chunks(value)
    local parts, first, length = {}, 1, #value
    while first <= length do
        local last = first + CHUNK_BYTES - 1
        if last < length then
            -- recule tant que l'octet suivant continue un caractère UTF-8
            while last > first do
                local following = byte(value, last + 1)
                if following < CONTINUATION_LOW or following > CONTINUATION_HIGH then break end
                last = last - 1
            end
        end
        parts[#parts + 1] = sub(value, first, last)
        first = last + 1
    end
    return parts
end

---@param position vector3
---@param lines table[]
---@param distance number
local function draw(position, lines, distance)
    local scale = cfg.scale * max(cfg.minScale, 1 - distance / cfg.distance * (1 - cfg.minScale))
    local count = #lines
    SetDrawOrigin(position.x, position.y, position.z + cfg.headOffset, 0)
    for i = 1, count do
        local line = lines[i]
        local color = line.color
        SetTextScale(0.0, scale)
        SetTextFont(cfg.font)
        SetTextProportional(true)
        SetTextColour(color.r, color.g, color.b, color.a)
        SetTextOutline()
        SetTextCentre(true)
        BeginTextCommandDisplayText('STRING')
        local parts = line.parts
        for j = 1, #parts do AddTextComponentSubstringPlayerName(parts[j]) end
        EndTextCommandDisplayText(0.0, (i - count) * cfg.lineHeight)
    end
    ClearDrawOrigin()
end

local function run()
    drawing = true
    CreateThread(function()
        local nextSight = 0
        while next(entries) do
            local now = GetGameTimer()
            local myPed = PlayerPedId()
            local myPosition = GetEntityCoords(myPed)
            local checkSight = now >= nextSight
            if checkSight then nextSight = now + cfg.sightMs end
            for id, entry in pairs(entries) do
                local lines = entry.lines
                while lines[1] and lines[1].expires <= now do remove(lines, 1) end
                if not lines[1] then
                    entries[id] = nil
                else
                    local ped = GetPlayerPed(entry.player)
                    if ped ~= 0 and DoesEntityExist(ped) then
                        if checkSight then
                            entry.visible = ped == myPed or HasEntityClearLosToEntity(myPed, ped, SIGHT_FLAGS)
                        end
                        if entry.visible then
                            local head = GetPedBoneCoords(ped, cfg.headBone, 0.0, 0.0, 0.0)
                            local distance = #(head - myPosition)
                            if distance <= cfg.distance then draw(head, lines, distance) end
                        end
                    end
                end
            end
            Wait(0)
        end
        drawing = false
    end)
end

--- Ligne au-dessus de la tête d'un joueur (numéro de joueur du serveur), s'il est dans la zone du joueur local.
---@param serverId integer
---@param kind string   me ou do
---@param body string
function overhead.add(serverId, kind, body)
    local player = GetPlayerFromServerId(serverId)
    if player == NO_PLAYER then return end
    local cleaned = gsub(gsub(text.clean(body) or '', GTA_CODES, ''), '~', '')
    if cleaned == '' then return end
    local entry = entries[serverId]
    if not entry then
        entry = { player = player, visible = true, lines = {} }
        entries[serverId] = entry
    end
    entry.player = player
    local lines = entry.lines
    lines[#lines + 1] = {
        parts = chunks(format(texts[kind], text.truncate(cleaned, cfg.maxChars, texts.ellipsis))),
        color = cfg[kind],
        expires = GetGameTimer() + cfg.durationMs,
    }
    if #lines > cfg.maxLines then remove(lines, 1) end
    if not drawing then run() end
end

--- Tout est effacé (retour à la sélection, arrêt du module).
function overhead.clear()
    entries = {}
end
