--[[
    vava_voice/client/ring.lua
    Rôle : cercle au sol, à la distance de la portée, montré au seul joueur quand il change de portée ; il le suit
           puis s'efface. Un marqueur se dessine à chaque image : la boucle par image ne vit que le temps du cercle.
    Dépendances : config.lua
]]

local floor, min = math.floor, math.min
local CreateThread, Wait, GetGameTimer = CreateThread, Wait, GetGameTimer
local PlayerPedId, GetEntityCoords, DrawMarker = PlayerPedId, GetEntityCoords, DrawMarker

local cfg = VavaVoice.config.ring
local R, G, B = cfg.color[1], cfg.color[2], cfg.color[3]
local FADE_MS = cfg.durationMs * cfg.fadeShare

local ring = {}
VavaVoice.ring = ring

local untilMs = 0
local radius = 0.0
local drawing = false

---@param meters number  rayon du cercle
function ring.show(meters)
    radius = meters
    untilMs = GetGameTimer() + cfg.durationMs
    if drawing then return end
    drawing = true
    CreateThread(function()
        -- boucle par image justifiée : 1,5 s au plus, et seulement après un appui sur la touche
        while true do
            local left = untilMs - GetGameTimer()
            if left <= 0 then break end
            local alpha = floor(cfg.alpha * min(1, left / FADE_MS))
            local coords = GetEntityCoords(PlayerPedId())
            local diameter = radius * 2.0
            DrawMarker(cfg.marker, coords.x, coords.y, coords.z - cfg.groundOffset, 0.0, 0.0, 0.0, 0.0, 0.0, 0.0,
                diameter, diameter, cfg.thickness, R, G, B, alpha, false, false, 2, false, nil, nil, false)
            Wait(0)
        end
        drawing = false
    end)
end
