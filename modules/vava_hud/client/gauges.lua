--[[
    vava_hud/client/gauges.lua
    Rôle : jauges déclarées par les modules. Un module ne gère que les siennes (identifiant préfixé par son nom de
           ressource) ; elles disparaissent à son arrêt. Valeurs de 0 à 1, et un état « actif » (lueur de laiton :
           parole, effet en cours…) ; l'interface n'est prévenue que d'un changement réel.
    Dépendances : config.lua, client/nui.lua
]]

local type, pairs, sort = type, pairs, table.sort
local mathType = math.type
local find, sub = string.find, string.sub

local cfg = VavaHud.config
local nui = VavaHud.nui

local ID_PATTERN = '^[%w_%-%.]+:[%w_%-%.]+$'
-- images locales uniquement : une adresse externe ferait sortir une requête de chaque client
local ICON_PREFIX = 'nui://'

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
---@field value number
---@field active boolean   lueur de laiton

---@type table<string, vAvA.Gauge>
local list = {}
local count = 0

---@param gauge vAvA.Gauge
---@return table
local function public(gauge)
    return {
        id = gauge.id, label = gauge.label, icon = gauge.icon, order = gauge.order,
        low = gauge.low, critical = gauge.critical, value = gauge.value, active = gauge.active,
    }
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

--- Déclare (ou redéclare) une jauge.
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
        active = existing ~= nil and existing.active,
    }
    if not existing then count = count + 1 end
    list[id] = gauge
    nui.send('define', public(gauge))
    return true
end

---@param owner string
---@param id any
---@param value any  0 à 1
---@return boolean ok
---@return string|nil code
function gauges.set(owner, id, value)
    local gauge = type(id) == 'string' and list[id]
    if not gauge then return false, 'not_found' end
    if gauge.owner ~= owner then return false, 'not_owner' end
    if type(value) ~= 'number' or value ~= value then return false, 'invalid_value' end
    if value < 0 then value = 0 elseif value > 1 then value = 1 end
    if value == gauge.value then return true end
    gauge.value = value
    nui.send('value', { id = id, value = value })
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

--- Toutes les jauges, dans l'ordre d'affichage.
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
