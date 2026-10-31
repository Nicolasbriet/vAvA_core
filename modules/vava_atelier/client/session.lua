--[[
    vava_atelier/client/session.lua
    Rôle : ouverture et fermeture de l'Atelier côté joueur, focus, versions gardées (empreintes de l'accueil et des
           descripteurs que la page a reçus : le serveur ne renvoie que ce qui a changé), évènements du serveur
           (`revoked` : l'interface se ferme ; `editorGone` : retour à l'accueil ; T-101 : `entryChanged`, une fiche
           de l'atelier ouvert a changé ailleurs → message `entryChanged` à la page ; fin d'un essai hors de
           l'Atelier → notification). Aucune boucle : tout part d'une touche, d'une commande, d'un évènement ou d'un
           retour de la page.
    Dépendances : shared/constants.lua, config.lua, client/core.lua, client/nui.lua
]]

local type, pcall, tostring = type, pcall, tostring
local find = string.find
local CreateThread, RegisterNetEvent, GetResourceState, IsPauseMenuActive, TriggerEvent =
    CreateThread, RegisterNetEvent, GetResourceState, IsPauseMenuActive, TriggerEvent
local BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker =
    BeginTextCommandThefeedPost, AddTextComponentSubstringPlayerName, EndTextCommandThefeedPostTicker

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local texts = cfg.texts
local RPC, EVENTS, HOOKS = VavaAtelier.RPC, VavaAtelier.EVENTS, VavaAtelier.HOOKS
local nui = VavaAtelier.nui

local HUD = 'vava_hud'
local CHAT, CHAT_EVENT = 'vava_chat', 'chat:addMessage'
local SAY_MAX = 480
local FEED_TEXT = 'STRING'

local session = {}
VavaAtelier.session = session

local open, pending = false, false
-- atelier dont la page a demandé le descripteur en dernier (avis `entryChanged`)
local currentEditor = nil
-- ce qu'a pu changer une fiche (évènement entryChanged)
local CHANGES = {
    saved = true, published = true, restored = true, removed = true, discarded = true, taken = true, trialEnded = true,
}

-- Ce que la page garde entre deux ouvertures : empreinte de l'accueil, et pour chaque atelier dont elle a reçu le
-- descripteur, son empreinte et son nom (bandeau du volet). '' ou absent : rien de gardé.
local known = { home = '', editors = {} }

local function hudNotify(message, kind)
    return exports[HUD]:notify(message, kind)
end

--- Message hors de l'interface : notification de vava_hud, sinon celle du jeu.
---@param message string
---@param kind? string  info | warning | danger
function session.feed(message, kind)
    if GetResourceState(HUD) == 'started' then
        local called, ok = pcall(hudNotify, message, kind)
        if called and ok then return end
        if not called then core.log.warn('%s.notify en erreur : %s', HUD, tostring(ok)) end
    end
    BeginTextCommandThefeedPost(FEED_TEXT)
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

--- Texte d'un refus (code du serveur ou du transport).
---@param code any
---@return string
function session.refusal(code)
    return texts.refused[code] or texts.refused.unavailable
end

---@return boolean
function session.isOpen()
    return open
end

--- Versions gardées (lues et tenues par client/relay.lua).
---@return { home: string, editors: table<string, { version: string, label: string }> }
function session.known()
    return known
end

--- Atelier ouvert par la page (descripteur demandé), ou nil.
---@param editorId string|nil
function session.setEditor(editorId)
    currentEditor = editorId
end

--- Oublie tout ce que la page garde : la prochaine demande renverra tout.
function session.forget()
    known.home = ''
    known.editors = {}
end

--- Range la réponse du RPC `home` et compose le message de la page ; nil si la réponse est incohérente (rien n'est
--- gardé : la prochaine demande renverra tout).
---@param answer any  { version, content?, tags, drafts, journal, rank }
---@return table|nil
function session.absorbHome(answer)
    if type(answer) ~= 'table' or type(answer.version) ~= 'string' then
        known.home = ''
        return nil
    end
    local content = answer.content
    if type(content) == 'table' then
        known.home = answer.version
    elseif answer.version ~= known.home then
        known.home = ''
        return nil
    else
        content = nil
    end
    return {
        version = known.home, content = content,
        -- étiquettes des cartes (« 2 panneaux », « 1 en essai ») : hors du contenu gardé, à chaque réponse
        tags = type(answer.tags) == 'table' and answer.tags or {},
        drafts = type(answer.drafts) == 'table' and answer.drafts or {},
        journal = type(answer.journal) == 'table' and answer.journal or {},
        rank = type(answer.rank) == 'string' and answer.rank or '',
    }
end

local function stillWanted()
    return not open and core.characters.current() ~= nil and not IsPauseMenuActive()
end

--- Ouvre l'Atelier : RPC `home` avec la version gardée, puis la page s'affiche. Refusée sans personnage, menu pause
--- ouvert, ou Atelier déjà ouvert ; un refus du serveur s'affiche en notification.
function session.open()
    if open or pending or not stillWanted() then return end
    pending = true
    CreateThread(function()
        local ok, success, answer = core.rpc.call(RPC.HOME, known.home)
        pending = false
        if not ok or not success then
            session.feed(session.refusal(ok and answer or success), 'warning')
            return
        end
        if not stillWanted() then
            -- ouverte côté serveur, mais plus voulue ici (menu pause, sélection) : la session est rendue
            core.rpc.emit(RPC.CLOSE)
            return
        end
        local message = session.absorbHome(answer)
        if not message then
            core.log.warn('Atelier : réponse incomplète, tout sera redemandé')
            session.feed(texts.refused.unavailable, 'warning')
            core.rpc.emit(RPC.CLOSE)
            return
        end
        message.closeKey = cfg.keys.open
        open = true
        nui.send('open', message)
        nui.setFocus(true)
        core.hooks.runAfter(HOOKS.STATE, { open = true })
    end)
end

--- Ferme l'Atelier : page fermée, focus rendu au jeu, session rendue au serveur (sauf `tellServer == false`).
---@param tellServer? boolean
function session.close(tellServer)
    if not open then return end
    open = false
    currentEditor = nil
    nui.send('close')
    nui.setFocus(false)
    if tellServer ~= false then core.rpc.emit(RPC.CLOSE) end
    core.hooks.runAfter(HOOKS.STATE, { open = false })
end

--- Arrêt de la ressource Atelier ouvert : la page disparaît avec elle, mais souris et clavier resteraient pris.
function session.release()
    if not open then return end
    open = false
    nui.setFocus(false)
end

-- Le membre a perdu le droit d'ouvrir l'Atelier : le serveur a déjà fermé sa session.
RegisterNetEvent(EVENTS.REVOKED, function()
    session.forget()
    if not open then return end
    session.close(false)
    session.feed(texts.revoked, 'warning')
end)

-- L'atelier ouvert a quitté le registre (module arrêté) : la page revient à l'accueil avec son message.
RegisterNetEvent(EVENTS.EDITOR_GONE, function(editorId)
    if type(editorId) ~= 'string' or #editorId > VavaAtelier.MAX_EDITOR
        or not find(editorId, VavaAtelier.EDITOR_PATTERN) then
        return
    end
    known.editors[editorId] = nil
    if currentEditor == editorId then currentEditor = nil end
    if open then nui.send('editorGone', { editor = editorId }) end
end)

--- Valeur d'identifiant reçue du serveur, bornée.
local function isId(value, pattern, max)
    return type(value) == 'string' and #value <= max and find(value, pattern) ~= nil
end

-- Réponse d'une commande de l'Atelier (/atelier_archives) : au chat s'il est là, sinon en notification.
RegisterNetEvent(EVENTS.SAY, function(line)
    if type(line) ~= 'string' or #line > SAY_MAX then return end
    if GetResourceState(CHAT) == 'started' then
        TriggerEvent(CHAT_EVENT, { args = { texts.archives.author, line } })
    else
        session.feed(line, 'info')
    end
end)

-- Une fiche de l'atelier ouvert a changé ailleurs (publication, reprise, fin d'essai…) : la page relit la fiche ou
-- avertit. Fin d'un essai alors que l'Atelier est fermé ou sur un autre atelier : notification.
RegisterNetEvent(EVENTS.ENTRY_CHANGED, function(editorId, kindId, id, what, title)
    if not isId(editorId, VavaAtelier.EDITOR_PATTERN, VavaAtelier.MAX_EDITOR)
        or not isId(kindId, VavaAtelier.KEY_PATTERN, VavaAtelier.MAX_KEY)
        or not isId(id, VavaAtelier.ENTRY_PATTERN, VavaAtelier.MAX_ENTRY) or not CHANGES[what] then
        return
    end
    if open and currentEditor == editorId then
        nui.send('entryChanged', { editor = editorId, kind = kindId, id = id, what = what })
        if what == 'trialEnded' and VavaAtelier.relay then VavaAtelier.relay.bannerFor(editorId, nil) end
    elseif what == 'trialEnded' then
        local name = type(title) == 'string' and #title <= 64 and title or id
        session.feed(texts.trialEndedFeed:format(name), 'info')
    end
end)
