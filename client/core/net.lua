--[[
    client/core/net.lua
    Rôle : réception de l'essai du réseau lancé depuis la console du serveur (vava_reseau_essai) : heure d'arrivée de
           chaque message, débit du message latent et ordre d'arrivée, écrits en console F8. Rien n'est montré au
           joueur ailleurs. Aucune boucle : un gestionnaire d'évènement et une minuterie par essai.
    Dépendances : shared/init.lua, config/shared.lua
]]

local type, print = type, print
local mathType, floor = math.type, math.floor
local format, reverse, gsub, concat = string.format, string.reverse, string.gsub, table.concat
local RegisterNetEvent, GetGameTimer, SetTimeout = RegisterNetEvent, GetGameTimer, SetTimeout

local EVENTS = vAvA.EVENTS
local cfg = vAvA.config.shared.net

local netprobe = {}
vAvA.netprobe = netprobe

-- essai en cours : { startAt, arrivals = { [n°] = ms }, order = { n°… }, bytes, done }
local current

--- Entier écrit à la française : « 1 640 ».
---@param value number
---@return string
local function group(value)
    local digits = format('%d', floor(value + 0.5))
    return (reverse((gsub(reverse(digits), '(%d%d%d)', '%1 '))):gsub('^ ', ''))
end

---@param probe table
local function report(probe)
    if probe.done then return end
    probe.done = true
    local order = concat(probe.order, ', ')
    local bulkAt = probe.arrivals[2]
    if not bulkAt then
        print(format('[vAvA] essai réseau : le message latent n\'est pas arrivé en %d s ; ordre d\'arrivée %s',
            cfg.probeTimeoutMs // 1000, order))
        return
    end
    local ms = bulkAt - probe.startAt
    local kb = probe.bytes / 1024
    local rate = ms > 0 and kb * 1000 / ms or kb * 1000
    print(format('[vAvA] essai réseau : latent de %s Ko reçu %s ms après le début (≈ %s Ko/s) ; ordre d\'arrivée %s',
        group(kb), group(ms), group(rate), order))
end

---@param number any  1 : début, 2 : message latent, 3 : après, ou de proximité
---@param nature any  'start' | 'bulk' | 'after' | 'near'
---@param payload any charge du message latent
local function onProbe(number, nature, payload)
    if mathType(number) ~= 'integer' or number < 1 or number > 3 or type(nature) ~= 'string' then return end
    local now = GetGameTimer()
    if number == 1 then
        if nature ~= 'start' then return end
        -- un nouvel essai remplace celui en cours
        local probe = { startAt = now, arrivals = { [1] = now }, order = { 1 }, bytes = 0, done = false }
        current = probe
        SetTimeout(cfg.probeTimeoutMs, function()
            if current == probe then report(probe) end
        end)
        return
    end
    local probe = current
    if nature == 'near' and (not probe or probe.done) then
        print('[vAvA] essai réseau : message de proximité reçu')
        return
    end
    if not probe or probe.done or probe.arrivals[number] then return end
    if number == 2 then
        if nature ~= 'bulk' or type(payload) ~= 'string' then return end
        probe.bytes = #payload
    elseif nature ~= 'after' and nature ~= 'near' then
        return
    end
    probe.arrivals[number] = now
    probe.order[#probe.order + 1] = number
    if probe.arrivals[2] and probe.arrivals[3] then report(probe) end
end

--- Branche la réception de l'essai. Appelé par client/init.lua.
function netprobe.start()
    RegisterNetEvent(EVENTS.NET_PROBE, onProbe)
end
