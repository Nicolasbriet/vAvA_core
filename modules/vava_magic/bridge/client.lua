--[[
    vava_magic/bridge/client.lua
    Rôle : SEUL point de contact, côté client, entre la magie et les autres modules : notifications et chiffres des
           sorts (vava_hud), état « à terre » (vava_health), droit d'incanter (CanUseMagic), arme en main
           (CombatHands, IsArmed, vava_combat : affichage seulement), cible verrouillée (GetLockedTarget), lignes et
           suggestions du chat. Aucune blessure n'est appliquée ici : les sorts blessent par la chaîne de dégâts de
           vava_health, côté serveur (sans lui, ils ne blessent personne).
           Pour un autre core, réécrire ces fonctions (et bridge/server.lua).
    Implémentation : modules officiels vAvA ; appels isolés, chaque module est facultatif (sans vava_hud : notification
           de GTA). Le verrouillage de cible est celui de ce module (client/targeting.lua, clic molette).
    Dépendances : shared/constants.lua, config_client.lua, shared/hands.lua, client/core.lua
]]

local type, pcall, tostring, ipairs = type, pcall, tostring, ipairs
local GetResourceState, TriggerEvent, GetGameTimer = GetResourceState, TriggerEvent, GetGameTimer
local PlayerPedId, IsEntityDead, IsPedCuffed, IsPedBeingStunned = PlayerPedId, IsEntityDead, IsPedCuffed, IsPedBeingStunned
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local cfg = VavaMagic.config
local LINKS = VavaMagic.LINKS
local HANDS = VavaMagic.hands
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

local hitTextWarnedAt = nil

local function hudHitText(side, anchor, issue, tenths)
    return exports[LINKS.HUD]:hitText(side, anchor, issue, tenths)
end

--- Chiffre d'un sort (vava_hud:hitText, T-155) ; sans vava_hud : rien. Erreur : une ligne de console par minute.
---@param side string  dealt | taken
---@param anchor integer
---@param issue string
---@param tenths integer|nil
function Bridge.HitText(side, anchor, issue, tenths)
    if GetResourceState(LINKS.HUD) ~= 'started' then return end
    local ok, err = pcall(hudHitText, side, anchor, issue, tenths)
    if ok then return end
    local now = GetGameTimer()
    if hitTextWarnedAt and now - hitTextWarnedAt < 60000 then return end
    hitTextWarnedAt = now
    VavaMagic.log.warn('%s.hitText en erreur : %s', LINKS.HUD, tostring(err))
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

--- Arme du royaume du personnage local (`vava_combat:armed()`, appel isolé) : `weapon`, `sheathing` (qu'on rengaine),
--- ou nil ; vava_combat absent ou en erreur : nil, sans bruit. Affichage seulement.
---@return string|nil
function Bridge.CombatHands()
    if GetResourceState(LINKS.COMBAT) ~= 'started' then return nil end
    local ok, weapon = pcall(invoke, LINKS.COMBAT, 'armed')
    if not ok or type(weapon) ~= 'table' then return nil end
    return weapon.sheathing == true and HANDS.SHEATHING or HANDS.WEAPON
end

---@return boolean
function Bridge.IsArmed()
    return Bridge.CombatHands() ~= nil
end

--- Prévient `handler()` quand ce que tient le personnage local change (champ `vava_inventory:hands`, hook local
--- `core:character:fieldChanged` du core) : un rappel « rangez votre arme » par arme sortie. Aucune lecture du
--- personnage ici : seul le nom du champ est comparé.
---@param handler fun()
function Bridge.OnHandsChanged(handler)
    VavaMagic.core.hooks.after('core:character:fieldChanged', function(payload)
        if type(payload) == 'table' and payload.field == LINKS.INVENTORY_HANDS then handler() end
    end)
end

--- Cible verrouillée par le système de verrouillage du serveur : numéro serveur du joueur, ou nil (visée libre).
--- Ici, celui de la magie (clic molette).
---@return integer|nil
function Bridge.GetLockedTarget()
    local targeting = VavaMagic.targeting
    return targeting and targeting.current() or nil
end
