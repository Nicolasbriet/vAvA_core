--[[
    vava_magic/bridge/client.lua
    Rôle : SEUL point de contact, côté client, entre la magie et les autres modules : notifications (vava_hud), état
           « à terre » (vava_health), droit d'incanter (CanUseMagic), cible verrouillée (GetLockedTarget), lignes et
           suggestions du chat, blessure appliquée par la victime quand vava_health manque (ApplyMagicDamage,
           implémentation par défaut de Bridge.ApplyDamage côté serveur).
           Pour un autre core, réécrire ces fonctions (et bridge/server.lua).
    Implémentation : modules officiels vAvA ; appels isolés, chaque module est facultatif (sans vava_hud : notification
           de GTA). Le verrouillage de cible est celui de ce module (client/targeting.lua, clic molette).
    Dépendances : shared/constants.lua, config.lua, client/core.lua
]]

local type, pcall, tostring, ipairs, floor = type, pcall, tostring, ipairs, math.floor
local GetResourceState, TriggerEvent, RegisterNetEvent = GetResourceState, TriggerEvent, RegisterNetEvent
local PlayerPedId, GetEntityHealth, GetEntityMaxHealth, ApplyDamageToPed, IsEntityDead, IsPedCuffed, IsPedBeingStunned =
    PlayerPedId, GetEntityHealth, GetEntityMaxHealth, ApplyDamageToPed, IsEntityDead, IsPedCuffed, IsPedBeingStunned
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local cfg = VavaMagic.config
local LINKS = VavaMagic.LINKS
local EVENTS = VavaMagic.EVENTS
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

-- Magie et combat ------------------------------------------------------------------------------------------------

--- Le personnage peut-il incanter ? Ni mort, ni à terre, ni entravé (menottes de GTA), ni assommé. Le serveur
--- revérifie ce qui dépend de lui (à terre, véhicule, états).
---@return boolean
function Bridge.CanUseMagic()
    local ped = PlayerPedId()
    if IsEntityDead(ped) or IsPedCuffed(ped) or IsPedBeingStunned(ped, 0) then return false end
    return not Bridge.IsDowned()
end

--- Cible verrouillée par le système de verrouillage du serveur : numéro serveur du joueur, ou nil (visée libre).
--- Ici, celui de la magie (clic molette).
---@return integer|nil
function Bridge.GetLockedTarget()
    local targeting = VavaMagic.targeting
    return targeting and targeting.current() or nil
end

--- Blessure sur le ped local, sur ordre du seul serveur, quand vava_health manque : `part` de la vie (0 à 1),
--- au-dessus du seuil où GTA met à terre.
---@param part number
---@param attacker? integer  numéro serveur du lanceur
---@param spell? string
function Bridge.ApplyMagicDamage(part, attacker, spell)
    local ped = PlayerPedId()
    local amount = floor(part * (GetEntityMaxHealth(ped) - DOWN_THRESHOLD) + 0.5)
    if amount > 0 and GetEntityHealth(ped) > 0 then ApplyDamageToPed(ped, amount, false) end
end

RegisterNetEvent(EVENTS.DAMAGE, function(part, attacker, spell)
    if type(part) ~= 'number' or part <= 0 or part > 1 then return end
    Bridge.ApplyMagicDamage(part, attacker, spell)
end)
