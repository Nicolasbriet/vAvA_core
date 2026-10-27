--[[
    vava_magic/bridge/client.lua
    Rôle : SEUL point de contact, côté client, entre la magie et les autres modules : notifications et médaillon de
           mana (vava_hud), état « à terre » (vava_health), lignes et suggestions du chat, blessure appliquée par la
           victime quand vava_health manque (implémentation par défaut de Bridge.ApplyDamage côté serveur).
           Pour un autre core, réécrire ces fonctions (et bridge/server.lua).
    Implémentation : modules officiels vAvA ; appels isolés, chaque module est facultatif (sans vava_hud : notification
           de GTA, pas de médaillon).
    Dépendances : shared/constants.lua, config.lua, client/core.lua
]]

local type, pcall, tostring, ipairs, floor = type, pcall, tostring, ipairs, math.floor
local GetResourceState, TriggerEvent, RegisterNetEvent = GetResourceState, TriggerEvent, RegisterNetEvent
local PlayerPedId, GetEntityHealth, GetEntityMaxHealth, ApplyDamageToPed = PlayerPedId, GetEntityHealth, GetEntityMaxHealth, ApplyDamageToPed
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local cfg = VavaMagic.config
local LINKS = VavaMagic.LINKS
local EVENTS = VavaMagic.EVENTS
local hudCfg = cfg.mana.hud
local GAUGE = VavaMagic.resource .. ':mana'
-- vie sous laquelle GTA met un joueur à terre (seuil de vava_health)
local DOWN_THRESHOLD = 100
-- natures de notification comprises par vava_hud
local NATURES = { info = 'info', success = 'info', warning = 'warning', danger = 'danger' }
local CHAT_COLOR = { 220, 192, 138 }

local Bridge = {}
VavaMagic.bridge = Bridge

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

--- Export d'une autre ressource, isolé : ok (appel réussi), puis ses valeurs.
---@return boolean called
local function call(resource, fn, ...)
    if GetResourceState(resource) ~= 'started' then return false end
    local ok, a, b = pcall(invoke, resource, fn, ...)
    if not ok then
        VavaMagic.log.warn('%s.%s en erreur : %s', resource, fn, tostring(a))
        return false
    end
    return true, a, b
end

--- Message au joueur ; nature : info, success, warning, danger.
---@param message string
---@param kind? string
function Bridge.Notify(message, kind)
    local called, ok = call(LINKS.HUD, 'notify', message, NATURES[kind] or 'info')
    if called and ok ~= false then return end
    BeginTextCommandThefeedPost('STRING')
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

--- Le joueur est-il à terre (vava_health) ?
---@return boolean
function Bridge.IsDowned()
    local called, health = call(LINKS.HEALTH, 'get')
    return called and type(health) == 'table' and health.downed == true
end

--- Lignes dans le chat (réponses des commandes).
---@param lines string[]
function Bridge.ChatLines(lines)
    for _, line in ipairs(lines) do
        TriggerEvent('chat:addMessage', { color = CHAT_COLOR, multiline = true, args = { cfg.texts.chat.prefix, line } })
    end
end

--- Suggestion d'une commande dans le chat.
---@param command string
---@param help string
---@param params? table
function Bridge.ChatSuggestion(command, help, params)
    TriggerEvent('chat:addSuggestion', '/' .. command, help, params or {})
end

-- Médaillon de mana (vava_hud) ------------------------------------------------------------------------------------

local gaugeDefined = false

--- Montre le médaillon (rempli de 0 à 1).
---@param ratio number
function Bridge.GaugeSet(ratio)
    if not gaugeDefined then
        local called, ok = call(LINKS.HUD, 'defineGauge', GAUGE, {
            label = hudCfg.label, icon = hudCfg.icon, order = hudCfg.order, low = hudCfg.low, critical = hudCfg.critical,
        })
        gaugeDefined = called and ok ~= false
        if not gaugeDefined then return end
    end
    call(LINKS.HUD, 'setGauge', GAUGE, ratio)
end

--- Lueur de laiton autour du médaillon (incantation en cours).
---@param active boolean
function Bridge.GaugeActive(active)
    if gaugeDefined then call(LINKS.HUD, 'setGaugeActive', GAUGE, active) end
end

function Bridge.GaugeHide()
    if gaugeDefined then call(LINKS.HUD, 'removeGauge', GAUGE) end
    gaugeDefined = false
end

--- vava_hud a (re)démarré : le médaillon est à redéclarer.
function Bridge.HudRestarted()
    gaugeDefined = false
end

Bridge.HUD_RESOURCE = LINKS.HUD

-- Blessure sans vava_health : ordre du seul serveur, appliquée au ped du joueur (sa vie lui appartient dans GTA)
RegisterNetEvent(EVENTS.DAMAGE, function(part)
    if type(part) ~= 'number' or part <= 0 or part > 1 then return end
    local ped = PlayerPedId()
    local amount = floor(part * (GetEntityMaxHealth(ped) - DOWN_THRESHOLD) + 0.5)
    if amount > 0 and GetEntityHealth(ped) > 0 then ApplyDamageToPed(ped, amount, false) end
end)
