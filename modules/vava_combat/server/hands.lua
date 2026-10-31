--[[
    vava_combat/server/hands.lua
    Rôle : dégainer et rengainer, tenus par le serveur (décision du porteur du projet : 0,8 s et 1,5 s). Au hook
           `vava_inventory:hold` (after) : une arme du catalogue prise en main → instant de la prise (aucune technique
           avant `draw.drawMs`) ; l'arme quitte la main (mains vides, outil, pile partie) → rengainement jusqu'à
           `draw.sheatheMs`, pendant lequel `armed(src)` dit encore « mains prises » (la magie refuse d'incanter sans
           qu'on touche à vava_magic) ; dans tous les cas, le coup en cours est annulé. Dernière arme vue en main,
           apprise au hook, à l'apparition ou à la première lecture de la main tenue (personnage apparu l'arme déjà en
           main : « en garde » d'emblée). Mémoire bornée par le nombre de joueurs, oubliée au déchargement et au départ.
    Dépendances : shared/constants.lua, config_client.lua, config.lua, server/core.lua, bridge/server.lua,
                  server/catalog.lua
]]

local type = type
local tointeger = math.tointeger

local bridge = VavaCombat.bridge
local catalog = VavaCombat.catalog
local cfg = VavaCombat.config
local SHIELD = VavaCombat.SHIELD_CATEGORY

local hands = {}
VavaCombat.hands = hands

-- source → instant où une arme est passée en main
local drawnAt = {}
-- source → { item, untilMs } : arme rangée, mains pas encore libres
local sheath = {}
-- source → dernière arme vue en main
local lastWeapon = {}

--- Vrai si l'objet est une arme du catalogue qui frappe (pas un bouclier).
---@param item any
---@return boolean
function hands.isWeapon(item)
    local def = catalog.weapon(item)
    return def ~= nil and def.category ~= SHIELD
end

--- Hook `vava_inventory:hold` (after) : dégainer, rengainer, coup en cours annulé.
---@param payload { source: integer, instanceId: integer, item?: string, previous?: integer, reason?: string }
function hands.onHold(payload)
    if type(payload) ~= 'table' then return end
    local src = type(payload.source) == 'number' and tointeger(payload.source) or nil
    if not src then return end
    local now = bridge.Timer()
    if payload.instanceId ~= 0 and hands.isWeapon(payload.item) then
        drawnAt[src], sheath[src], lastWeapon[src] = now, nil, payload.item
    else
        if lastWeapon[src] then sheath[src] = { item = lastWeapon[src], untilMs = now + cfg.draw.sheatheMs } end
        drawnAt[src], lastWeapon[src] = nil, nil
    end
    local swings = VavaCombat.swings
    if swings then swings.cancel(src, 'hands') end
end

--- Arme encore en train d'être dégainée : millisecondes avant de pouvoir frapper, ou nil (en garde).
---@param src integer
---@param now integer
---@return integer|nil
function hands.drawingLeft(src, now)
    local at = drawnAt[src]
    if not at then return nil end
    local left = at + cfg.draw.drawMs - now
    if left <= 0 then
        drawnAt[src] = nil
        return nil
    end
    return left
end

--- Arme rangée dont les mains ne sont pas encore libres : { item, untilMs }, ou nil (échu : oublié).
---@param src integer
---@param now integer
---@return { item: string, untilMs: integer }|nil
function hands.sheathing(src, now)
    local entry = sheath[src]
    if not entry then return nil end
    if now >= entry.untilMs then
        sheath[src] = nil
        return nil
    end
    return entry
end

--- Arme lue en main par le serveur (use, armed, apparition) : retenue comme dernière arme tenue.
---@param src integer
---@param item string
function hands.noteHeld(src, item)
    if hands.isWeapon(item) then lastWeapon[src] = item end
end

--- Apparition (ou reprise au démarrage du module) : arme déjà en main retenue, « en garde » d'emblée.
---@param src integer
function hands.learn(src)
    local held = bridge.Held(src)
    if held then hands.noteHeld(src, held.item) end
end

--- Déchargement, départ : tout est oublié.
---@param src integer
function hands.forget(src)
    drawnAt[src], sheath[src], lastWeapon[src] = nil, nil, nil
end

--- Arrêt du module.
function hands.stop()
    drawnAt, sheath, lastWeapon = {}, {}, {}
end
