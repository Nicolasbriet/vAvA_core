--[[
    vava_combat/client/endurance.lua
    Rôle : jauge d'endurance vue du joueur (spec T-114 § 8.2) : état reçu du serveur, niveau projeté, médaillon du HUD
           (montré en mode combat éveillé ou tant qu'elle n'est pas pleine) ; aucune boucle, prédiction seulement.
    Dépendances : shared/constants.lua, config_client.lua, shared/endurance.lua, client/core.lua, bridge/client.lua
]]

local type, max, huge = type, math.max, math.huge
local GetGameTimer, SetTimeout = GetGameTimer, SetTimeout

local core = VavaCombat.core
if not core then return end

local bridge = VavaCombat.bridge
local endurance = VavaCombat.endurance
local gauge = VavaCombat.config.gauge
local MAX = VavaCombat.ENDURANCE_MAX
local ID = 'vava_combat:endurance'

local gaugeView = {}
VavaCombat.gaugeView = gaugeView

-- dernier état reçu, daté à son arrivée : { value, at, restAt, rate } ; nil : pleine
local view = nil
-- mode combat éveillé ; médaillon déclaré au HUD ; jeton du dernier masquage programmé (un nouveau périme l'ancien)
local awake, shown, hideToken = false, false, 0

---@param now integer
---@return integer
local function level(now)
    return endurance.level(view, now)
end

--- Valeur au HUD (part de 0 à 1) et remontée que la page anime seule (aucun envoi pendant la remontée).
---@param now integer
local function push(now)
    local value = level(now)
    if value >= MAX then
        bridge.HudGauge('setGauge', ID, 1)
        return
    end
    local refill = nil
    if view.rate > 0 then refill = { perSecond = view.rate / MAX, delayMs = max(0, view.restAt - now) } end
    bridge.HudGauge('setGauge', ID, value / MAX, refill)
end

---@param now integer
local function show(now)
    if shown then return end
    shown = bridge.HudGauge('defineGauge', ID, { label = gauge.label, icon = gauge.icon, order = gauge.order,
        low = gauge.low, critical = gauge.critical })
    if shown then push(now) end
end

local function hide()
    if not shown then return end
    shown = false
    bridge.HudGauge('removeGauge', ID)
end

--- Mode combat endormi : médaillon retiré `lingerMs` après que la jauge est redevenue pleine. Une seule minuterie vit :
--- un nouvel état ou un réveil la périme ; une jauge qui ne remonte pas attend le prochain état plein.
---@param now integer
local function scheduleHide(now)
    hideToken = hideToken + 1
    if not shown then return end
    local fullAt = endurance.fullAt(view, now)
    if fullAt == huge then return end
    local token = hideToken
    SetTimeout(max(0, fullAt - now) + gauge.lingerMs, function()
        if token ~= hideToken or awake or level(GetGameTimer()) < MAX then return end
        hide()
    end)
end

--- État reçu du serveur (réponse de vava_combat:use, évènement vava_combat:stamina) : lu dans ses bornes (sinon ignoré),
--- daté à son arrivée, montré. Rend vrai s'il est pris.
---@param value any    dixièmes
---@param restIn any   ms avant la reprise de la recharge
---@param rate any     dixièmes par seconde
---@return boolean
function gaugeView.apply(value, restIn, rate)
    local state = endurance.read(value, restIn, rate)
    if not state then return false end
    local now = GetGameTimer()
    view = nil
    if state.value < MAX then
        view = { value = state.value, at = now, restAt = now + state.restIn, rate = state.rate }
    end
    if shown then
        push(now)
    elseif view then
        show(now)
    end
    if not awake then scheduleHide(now) end
    return true
end

--- Mode combat éveillé (vrai) : médaillon montré ; endormi (faux) : retiré une fois la jauge pleine, puis `lingerMs`.
---@param flag boolean
function gaugeView.setAwake(flag)
    local now = GetGameTimer()
    if flag then
        awake = true
        hideToken = hideToken + 1
        show(now)
    elseif awake then
        awake = false
        scheduleHide(now)
    end
end

--- Vrai si la jauge vue d'ici paie `cost` points, à `gauge.margin` près (prédiction seulement : le serveur décide).
---@param cost any
---@param now integer
---@return boolean
function gaugeView.allows(cost, now)
    if type(cost) ~= 'number' or cost <= 0 then return true end
    return level(now) + gauge.margin * 10 >= cost * 10
end

--- Niveau projeté en dixièmes (essais, affichage).
---@param now integer
---@return integer
function gaugeView.level(now)
    return level(now)
end

-- personnage déchargé : jauge oubliée (pleine au prochain), médaillon retiré ; arrêt de ce module : vava_hud retire
-- lui-même ses jauges
core.hooks.after('core:character:unloaded', function()
    view = nil
    hideToken = hideToken + 1
    hide()
end)

-- vava_hud (re)démarré : ses jauges sont perdues, le médaillon est redéclaré s'il doit se voir, à sa valeur projetée
bridge.OnHudRestart(function()
    shown = false
    local now = GetGameTimer()
    if awake or level(now) < MAX then
        show(now)
        if not awake then scheduleHide(now) end
    end
end)
