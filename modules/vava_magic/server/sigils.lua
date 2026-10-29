--[[
    vava_magic/server/sigils.lua
    Rôle : sigils (contacts du Murmure), décidés par le serveur.
      - Échange face à face : le joueur tend son sigil au plus proche (3 m, positions lues côté serveur), qui accepte
        en le nommant ou refuse dans les 30 s ; distance revérifiée à l'acceptation. À sens unique par défaut :
        l'autre peut confier le sien en retour, que le premier nomme à son tour. Après un refus, le donneur attend
        `sigils.refusedMs` avant de tendre de nouveau son sigil au même joueur (oublié au départ de l'un ou l'autre).
      - Mage ou non, chacun donne et reçoit des sigils ; le nombre gardé dépend du niveau du Murmure.
      - Liste, renommer, oublier ; brouiller son sigil (mage connaissant le Murmure, mana, longue recharge gardée
        dans la fiche) : ceux qui connaissaient l'ancien perdent le lien, sa propre liste reste.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/world.lua, server/sheets.lua,
                  server/mana.lua
]]

local ipairs, pairs = ipairs, pairs
local ceil = math.ceil
local time = os.time
local GetGameTimer, SetTimeout, TriggerClientEvent = GetGameTimer, SetTimeout, TriggerClientEvent

local bridge = VavaMagic.bridge
local world = VavaMagic.world
local sheets = VavaMagic.sheets
local mana = VavaMagic.mana
local text = VavaMagic.text
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config.sigils
local notify = VavaMagic.config.texts.notify
local EVENTS = VavaMagic.EVENTS
local MS_PER_SECOND = 1000
local OFFER_SECONDS = ceil(cfg.offerMs / MS_PER_SECOND)

local sigils = {}
VavaMagic.sigils = sigils

---@class vAvA.SigilOffer
---@field id integer
---@field from integer    joueur qui tend son sigil
---@field to integer      joueur qui le reçoit
---@field stage 'offer'|'naming'
---@field expiresAt integer

---@type table<integer, vAvA.SigilOffer>
local offers = {}
---@type table<integer, integer>  joueur → offre en cours (donneur ou receveur)
local byPlayer = {}
---@type table<integer, table<integer, integer>>  donneur → receveur qui l'a refusé → fin du délai
local refusals = {}
local nextOffer = 0

--- Le receveur refuse : le donneur ne pourra lui retendre son sigil qu'après le délai.
---@param offer vAvA.SigilOffer
local function refused(offer)
    local byReceiver = refusals[offer.from]
    if not byReceiver then
        byReceiver = {}
        refusals[offer.from] = byReceiver
    end
    byReceiver[offer.to] = GetGameTimer() + cfg.refusedMs
end

--- Millisecondes avant que `src` puisse retendre son sigil à `target` (0 : rien ne l'en empêche).
---@param src integer
---@param target integer
---@return integer
local function refusedLeft(src, target)
    local byReceiver = refusals[src]
    local untilMs = byReceiver and byReceiver[target]
    if not untilMs then return 0 end
    local left = untilMs - GetGameTimer()
    if left > 0 then return left end
    byReceiver[target] = nil
    return 0
end

--- Liste des contacts : { contacts = { { index, name } }, limit }.
---@param src integer
---@return table|nil
function sigils.list(src)
    local sheet = sheets.get(src)
    if not sheet then return nil end
    local contacts = {}
    for index, contact in ipairs(sheet.sigils) do contacts[index] = { index = index, name = contact.name } end
    return { contacts = contacts, limit = sheets.sigilLimit(sheet) }
end

--- Ajoute (ou renomme) un sigil dans la liste d'un joueur. Renvoie false, code si sa mémoire est pleine.
---@param src integer
---@param sigil string
---@param name string
---@return boolean ok
---@return string|nil code
local function remember(src, sigil, name)
    local sheet = sheets.get(src)
    if not sheet then return false, 'not_ready' end
    local index = sheets.contactIndex(sheet, sigil)
    if index then
        sheet.sigils[index].name = name
    else
        if #sheet.sigils >= sheets.sigilLimit(sheet) then return false, 'sigils_full' end
        sheet.sigils[#sheet.sigils + 1] = { sigil = sigil, name = name }
    end
    sheets.touch(src, true)
    return true
end

--- Les deux joueurs sont-ils encore face à face ?
---@param offer vAvA.SigilOffer
---@return boolean
local function stillNear(offer)
    local a, b = world.position(offer.from), world.position(offer.to)
    return a ~= nil and b ~= nil and geometry.distance(a, b) <= cfg.offerRange + cfg.rangeMargin
end

--- Clôt une offre ; la fenêtre ouverte chez celui qui devait répondre se ferme.
---@param offer vAvA.SigilOffer
local function close(offer)
    if offers[offer.id] ~= offer then return end
    offers[offer.id] = nil
    if byPlayer[offer.from] == offer.id then byPlayer[offer.from] = nil end
    if byPlayer[offer.to] == offer.id then byPlayer[offer.to] = nil end
    TriggerClientEvent(EVENTS.SIGIL_CLOSED, offer.stage == 'offer' and offer.to or offer.from, offer.id)
end

--- Arme l'expiration de l'étape en cours.
---@param offer vAvA.SigilOffer
local function arm(offer)
    offer.expiresAt = GetGameTimer() + cfg.offerMs
    local expires = offer.expiresAt
    SetTimeout(cfg.offerMs, function()
        if offers[offer.id] ~= offer or offer.expiresAt ~= expires then return end
        bridge.Notify(offer.stage == 'offer' and offer.from or offer.to, notify.sigilExpired, 'warning')
        close(offer)
    end)
end

--- Tend son sigil au joueur le plus proche.
---@param src integer
---@return boolean ok
---@return string|nil code
---@return integer|nil seconds  délai restant après un refus de ce joueur
function sigils.offer(src)
    if not sheets.get(src) then return false, 'not_ready' end
    if byPlayer[src] then return false, 'offer_pending' end
    local position = world.position(src)
    if not position then return false, 'no_position' end
    local nearest = world.near(position, cfg.offerRange, src)[1]
    if not nearest or not sheets.get(nearest.source) then return false, 'nobody_near' end
    local target = nearest.source
    local left = refusedLeft(src, target)
    if left > 0 then return false, 'offer_refused', ceil(left / MS_PER_SECOND) end
    if byPlayer[target] then return false, 'offer_pending' end
    nextOffer = nextOffer + 1
    local offer = { id = nextOffer, from = src, to = target, stage = 'offer', expiresAt = 0 }
    offers[offer.id] = offer
    byPlayer[src], byPlayer[target] = offer.id, offer.id
    arm(offer)
    TriggerClientEvent(EVENTS.SIGIL_OFFER, target, offer.id, OFFER_SECONDS)
    return true
end

--- Réponse de celui à qui l'on tend un sigil.
---@param src integer
---@param offerId integer
---@param accept boolean
---@param name string
---@param giveBack boolean
---@return boolean ok
---@return string|nil code
function sigils.answer(src, offerId, accept, name, giveBack)
    local offer = offers[offerId]
    if not offer or offer.stage ~= 'offer' or offer.to ~= src then return false, 'no_offer' end
    if not accept then
        refused(offer)
        bridge.Notify(offer.from, notify.sigilRefused, 'warning')
        close(offer)
        return true
    end
    local contactName = text.name(name, cfg.nameMax)
    if not contactName then return false, 'name_invalid' end
    if not stillNear(offer) then
        close(offer)
        return false, 'too_far'
    end
    local giver = sheets.get(offer.from)
    if not giver then
        close(offer)
        return false, 'no_offer'
    end
    local ok, code = remember(src, giver.sigil, contactName)
    if not ok then
        close(offer)
        return false, code
    end
    bridge.Notify(src, notify.sigilKept:format(contactName), 'success')
    bridge.Notify(offer.from, notify.sigilAccepted, 'success')
    if not giveBack then
        close(offer)
        return true
    end
    -- le receveur confie le sien : au donneur de le nommer
    offer.stage = 'naming'
    arm(offer)
    TriggerClientEvent(EVENTS.SIGIL_NAMING, offer.from, offer.id, OFFER_SECONDS)
    return true
end

--- Le donneur nomme le sigil reçu en retour (ou le refuse).
---@param src integer
---@param offerId integer
---@param accept boolean
---@param name string
---@return boolean ok
---@return string|nil code
function sigils.nameBack(src, offerId, accept, name)
    local offer = offers[offerId]
    if not offer or offer.stage ~= 'naming' or offer.from ~= src then return false, 'no_offer' end
    if not accept then
        bridge.Notify(offer.to, notify.sigilRefused, 'warning')
        close(offer)
        return true
    end
    local contactName = text.name(name, cfg.nameMax)
    if not contactName then return false, 'name_invalid' end
    if not stillNear(offer) then
        close(offer)
        return false, 'too_far'
    end
    local receiver = sheets.get(offer.to)
    if not receiver then
        close(offer)
        return false, 'no_offer'
    end
    local ok, code = remember(src, receiver.sigil, contactName)
    close(offer)
    if not ok then return false, code end
    bridge.Notify(src, notify.sigilKept:format(contactName), 'success')
    bridge.Notify(offer.to, notify.sigilAccepted, 'success')
    return true
end

---@param src integer
---@param index integer
---@param name string
---@return boolean ok
---@return string|nil code
function sigils.rename(src, index, name)
    local sheet = sheets.get(src)
    if not sheet then return false, 'not_ready' end
    local contact = sheet.sigils[index]
    if not contact then return false, 'unknown_index' end
    local contactName = text.name(name, cfg.nameMax)
    if not contactName then return false, 'name_invalid' end
    contact.name = contactName
    sheets.touch(src, true)
    bridge.Notify(src, notify.sigilRenamed:format(contactName), 'success')
    return true
end

---@param src integer
---@param index integer
---@return boolean ok
---@return string|nil code
function sigils.forget(src, index)
    local sheet = sheets.get(src)
    if not sheet then return false, 'not_ready' end
    local contact = sheet.sigils[index]
    if not contact then return false, 'unknown_index' end
    table.remove(sheet.sigils, index)
    sheets.touch(src, true)
    bridge.Notify(src, notify.sigilForgotten:format(contact.name), 'info')
    return true
end

--- Brouille le sigil du joueur. Bloque le thread (base de données).
---@param src integer
---@return boolean ok
---@return string|nil code
---@return integer|nil seconds  recharge restante
function sigils.scramble(src)
    local sheet = sheets.get(src)
    if not sheet then return false, 'not_ready' end
    if not sheet.isMage then return false, 'not_mage' end
    if not sheet.spells[cfg.spell] then return false, 'unknown_spell' end
    local cooldown = cfg.scramble.cooldownMs // MS_PER_SECOND
    local elapsed = sheet.scrambledAt and (time() - sheet.scrambledAt) or cooldown
    if elapsed < cooldown then return false, 'cooldown', cooldown - elapsed end
    if not mana.spend(src, cfg.scramble.cost) then return false, 'no_mana' end
    if not sheets.scramble(src) then
        mana.give(src, cfg.scramble.cost)
        return false, 'db_error'
    end
    sheet.scrambledAt = time()
    sheets.touch(src)
    bridge.Notify(src, notify.sigilScrambled, 'success')
    return true
end

--- Départ du joueur : ses offres en cours sont closes, les refus qui le concernent oubliés.
---@param src integer
function sigils.forgetPlayer(src)
    local id = byPlayer[src]
    if id and offers[id] then close(offers[id]) end
    refusals[src] = nil
    for _, byReceiver in pairs(refusals) do byReceiver[src] = nil end
end
