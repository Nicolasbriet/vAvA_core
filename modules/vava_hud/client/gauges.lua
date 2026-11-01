--[[
    vava_hud/client/gauges.lua
    Rôle : jauges déclarées par les modules. Un module ne gère que les siennes (identifiant préfixé par son nom de
           ressource) ; elles disparaissent à son arrêt. Valeurs de 0 à 1, remontée que la page anime seule (1.8.0,
           T-114), et un état « actif » (lueur de laiton : parole, effet en cours…) ; l'interface n'est prévenue que
           d'un changement réel.
    Dépendances : config_client.lua, client/nui.lua
]]

local type, pairs, sort = type, pairs, table.sort
local mathType, floor, huge, max, abs = math.type, math.floor, math.huge, math.max, math.abs
local find, sub = string.find, string.sub
local GetGameTimer = GetGameTimer

local cfg = VavaHud.config
local nui = VavaHud.nui

local ID_PATTERN = '^[%w_%-%.]+:[%w_%-%.]+$'
-- images locales uniquement : une adresse externe ferait sortir une requête de chaque client
local ICON_PREFIX = 'nui://'
-- même remontée qu'au dernier envoi : départ à 1 ms près
local SAME_START_MS = 1
local REFILL_KEYS = { perSecond = true, delayMs = true }

local gauges = {}
VavaHud.gauges = gauges

---@class vAvA.Gauge
---@field id string
---@field owner string
---@field label string
---@field icon string
---@field order integer
---@field low number       palier bas (0 à 1)
---@field critical number  palier critique (0 à 1)
---@field value number     valeur de départ (0 à 1)
---@field refill { perSecond: number, startAt: integer }|nil  remontée linéaire jusqu'à 1 (horloge GetGameTimer)
---@field active boolean   lueur de laiton

---@type table<string, vAvA.Gauge>
local list = {}
local count = 0

--- Valeur projetée à `now` et remontée restante (`{ perSecond, delayMs }`), ou la valeur seule (pleine, sans remontée).
---@param gauge vAvA.Gauge
---@param now integer
---@return number value
---@return table|nil refill
local function projected(gauge, now)
    local refill = gauge.refill
    if not refill then return gauge.value, nil end
    local value = gauge.value + max(0, now - refill.startAt) / 1000 * refill.perSecond
    if value >= 1 then return 1, nil end
    return value, { perSecond = refill.perSecond, delayMs = max(0, refill.startAt - now) }
end

---@param gauge vAvA.Gauge
---@return table
local function public(gauge)
    local value, refill = projected(gauge, GetGameTimer())
    return {
        id = gauge.id, label = gauge.label, icon = gauge.icon, order = gauge.order,
        low = gauge.low, critical = gauge.critical, value = value, active = gauge.active, refill = refill,
    }
end

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Remontée demandée : nil, ou `{ perSecond, delayMs }` aux seules clés connues, `0 < perSecond ≤ refill.maxPerSecond`
--- (part de la jauge par seconde), `delayMs` entier de 0 à `refill.maxDelayMs`. Rend vrai si elle est valable.
---@param refill any
---@return boolean
local function validRefill(refill)
    if refill == nil then return true end
    if type(refill) ~= 'table' then return false end
    for key in pairs(refill) do
        if not REFILL_KEYS[key] then return false end
    end
    local perSecond, delayMs, bounds = refill.perSecond, refill.delayMs, cfg.refill
    if not finite(perSecond) or perSecond <= 0 or perSecond > bounds.maxPerSecond then return false end
    return finite(delayMs) and delayMs == floor(delayMs) and delayMs >= 0 and delayMs <= bounds.maxDelayMs
end

---@param value any
---@return boolean
local function isRatio(value)
    return type(value) == 'number' and value >= 0 and value <= 1
end

---@param owner string
---@param id any
---@return boolean
local function owns(owner, id)
    return type(id) == 'string' and #id <= cfg.maxIdLength and find(id, ID_PATTERN) ~= nil
        and sub(id, 1, #owner + 1) == owner .. ':'
end

--- Déclare (ou redéclare : valeur et remontée gardées) une jauge.
---@param owner string
---@param id any
---@param options any  { label, icon, order?, low?, critical? }
---@return boolean ok
---@return string|nil code
function gauges.define(owner, id, options)
    if not owns(owner, id) then return false, 'invalid_id' end
    if type(options) ~= 'table' then return false, 'invalid_options' end
    local label, icon, order = options.label, options.icon, options.order or 0
    if type(label) ~= 'string' or #label == 0 or #label > cfg.maxLabelLength then return false, 'invalid_label' end
    if type(icon) ~= 'string' or #icon > cfg.maxIconLength or sub(icon, 1, #ICON_PREFIX) ~= ICON_PREFIX then return false, 'invalid_icon' end
    if mathType(order) ~= 'integer' or order < 0 or order > cfg.maxOrder then return false, 'invalid_order' end
    local low, critical = options.low or 0, options.critical or 0
    if not isRatio(low) or not isRatio(critical) or critical > low then return false, 'invalid_thresholds' end
    local existing = list[id]
    if not existing and count >= cfg.maxGauges then return false, 'too_many_gauges' end

    local gauge = {
        id = id, owner = owner, label = label, icon = icon, order = order,
        low = low, critical = critical, value = existing and existing.value or 1,
        refill = existing and existing.refill or nil, active = existing ~= nil and existing.active,
    }
    if not existing then count = count + 1 end
    list[id] = gauge
    nui.send('define', public(gauge))
    return true
end

--- Met une jauge à `value` (0 à 1). `refill` (1.8.0) : `{ perSecond, delayMs }`, la jauge remonte seule, linéairement
--- jusqu'à 1, `delayMs` après l'appel (la page l'anime : aucun envoi pendant la remontée) ; absent : toute remontée en
--- cours s'arrête (comportement de 1.7.0). Même valeur et même remontée qu'au dernier envoi : rien n'est envoyé.
---@param owner string
---@param id any
---@param value any  0 à 1
---@param refill any  nil ou { perSecond, delayMs }
---@return boolean ok
---@return string|nil code
function gauges.set(owner, id, value, refill)
    local gauge = type(id) == 'string' and list[id]
    if not gauge then return false, 'not_found' end
    if gauge.owner ~= owner then return false, 'not_owner' end
    if type(value) ~= 'number' or value ~= value then return false, 'invalid_value' end
    if not validRefill(refill) then return false, 'invalid_refill' end
    if value < 0 then value = 0 elseif value > 1 then value = 1 end
    -- une jauge pleine n'a rien à remonter
    local wanted = nil
    if refill and value < 1 then
        wanted = { perSecond = refill.perSecond, startAt = GetGameTimer() + floor(refill.delayMs) }
    end
    local old = gauge.refill
    if value == gauge.value and ((old == nil and wanted == nil) or (old and wanted and old.perSecond == wanted.perSecond
        and abs(old.startAt - wanted.startAt) <= SAME_START_MS)) then
        return true
    end
    gauge.value, gauge.refill = value, wanted
    local payload = { id = id, value = value }
    if wanted then payload.refill = { perSecond = wanted.perSecond, delayMs = floor(refill.delayMs) } end
    nui.send('value', payload)
    return true
end

--- Allume ou éteint la lueur d'une jauge.
---@param owner string
---@param id any
---@param active any
---@return boolean ok
---@return string|nil code
function gauges.setActive(owner, id, active)
    local gauge = type(id) == 'string' and list[id]
    if not gauge then return false, 'not_found' end
    if gauge.owner ~= owner then return false, 'not_owner' end
    if type(active) ~= 'boolean' then return false, 'invalid_value' end
    if active == gauge.active then return true end
    gauge.active = active
    nui.send('active', { id = id, active = active })
    return true
end

---@param owner string
---@param id any
---@return boolean ok
---@return string|nil code
function gauges.remove(owner, id)
    local gauge = type(id) == 'string' and list[id]
    if not gauge then return false, 'not_found' end
    if gauge.owner ~= owner then return false, 'not_owner' end
    list[id] = nil
    count = count - 1
    nui.send('remove', { id = id })
    return true
end

--- Retire les jauges d'une ressource arrêtée.
---@param owner string
function gauges.purgeOwner(owner)
    for id, gauge in pairs(list) do
        if gauge.owner == owner then
            list[id] = nil
            count = count - 1
            nui.send('remove', { id = id })
        end
    end
end

--- Toutes les jauges, dans l'ordre d'affichage (valeur projetée et remontée restante : page rechargée).
---@return table[]
function gauges.all()
    local out = {}
    for _, gauge in pairs(list) do out[#out + 1] = public(gauge) end
    sort(out, function(a, b)
        if a.order ~= b.order then return a.order < b.order end
        return a.id < b.id
    end)
    return out
end
