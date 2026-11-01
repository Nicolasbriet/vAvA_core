--[[
    vava_atelier/client/session.lua
    Rôle : séance de l'Atelier côté joueur : ouverture, fermeture, essai joué (page mise de côté), versions gardées,
           évènements du serveur. Livré dans le paquet du Conseil (T-157) : notifications, refus et réponse de
           /atelier_archives sont dans l'amorce (client/notice.lua) ; `revoked` efface aussi le stockage local.
    Dépendances : shared/constants.lua, config_client.lua, config_conseil.lua, client/core.lua, client/nui.lua,
                  client/notice.lua, client/loader.lua
]]

local type = type
local find = string.find
local CreateThread, RegisterNetEvent, IsPauseMenuActive = CreateThread, RegisterNetEvent, IsPauseMenuActive

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local texts = cfg.texts
local RPC, EVENTS, HOOKS = VavaAtelier.RPC, VavaAtelier.EVENTS, VavaAtelier.HOOKS
local nui, notice, loader = VavaAtelier.nui, VavaAtelier.notice, VavaAtelier.loader

local session = {}
VavaAtelier.session = session

local open, pending = false, false
-- T-102 : essai joué (page mise de côté, séance gardée ouverte côté serveur)
local suspended = false
-- atelier dont la page a demandé le descripteur en dernier (avis `entryChanged`)
local currentEditor = nil
-- ce qu'a pu changer une fiche (évènement entryChanged)
local CHANGES = {
    saved = true, published = true, restored = true, removed = true, discarded = true, taken = true, trialEnded = true,
}

-- Ce que la page garde entre deux ouvertures : empreinte de l'accueil, et pour chaque atelier dont elle a reçu le
-- descripteur, son empreinte et son nom (bandeau du volet). '' ou absent : rien de gardé.
local known = { home = '', editors = {} }

--- Message hors de l'interface, texte d'un refus : ceux de l'amorce (client/notice.lua), gardés sous ces noms.
session.feed = notice.feed
session.refusal = notice.refusal

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
        open, suspended = true, false
        nui.send('open', message)
        nui.setFocus(true)
        core.hooks.runAfter(HOOKS.STATE, { open = true, placing = false, suspended = false })
    end)
end

--- Outil de placement (client/placer.lua), chargé après ce fichier.
local function placer()
    return VavaAtelier.placer
end

--- Ferme l'Atelier : visée arrêtée, fantômes retirés, page fermée, focus rendu au jeu, session rendue au serveur (sauf
--- `tellServer == false`).
---@param tellServer? boolean
function session.close(tellServer)
    if not open then return end
    if placer() then placer().stop(true) end
    if placer() then placer().leave() end
    open, suspended = false, false
    currentEditor = nil
    nui.send('close')
    nui.setFocus(false)
    if tellServer ~= false then core.rpc.emit(RPC.CLOSE) end
    core.hooks.runAfter(HOOKS.STATE, { open = false, placing = false, suspended = false })
end

--- Arrêt de la ressource Atelier ouvert : la page disparaît avec elle, mais souris et clavier resteraient pris.
function session.release()
    if not open then return end
    open, suspended = false, false
    nui.setFocus(false)
end

--- T-102 : essai joué. La page se met de côté (seul un bandeau reste), le jeu reprend la main, la séance reste
--- ouverte côté serveur (l'essai ne prend pas fin). `F9` ou /atelier : `resume`.
---@return boolean
function session.suspend()
    if not open or suspended then return false end
    -- visée arrêtée et fantômes retirés (l'essai montre les vrais points) ; les lieux de la fiche restent gardés pour
    -- la visée suivante (`placer.hide`, `placer.show` au retour)
    if placer() then placer().hide() end
    suspended = true
    -- sans `line` : la page compose la ligne d'essai de l'atelier et la touche de retour (écart 6 du rapport T-102-nui)
    nui.send('suspended', { on = true })
    nui.setFocus(false)
    core.hooks.runAfter(HOOKS.STATE, { open = false, placing = false, suspended = true })
    return true
end

--- Fin de l'essai joué : page et focus rendus, sans nouvel accueil.
function session.resume()
    if not open or not suspended then return end
    suspended = false
    nui.send('suspended', { on = false })
    nui.setFocus(true)
    if placer() then placer().show() end
    core.hooks.runAfter(HOOKS.STATE, { open = true, placing = false, suspended = false })
end

---@return boolean
function session.isSuspended()
    return suspended
end

-- Le membre a perdu le droit d'ouvrir l'Atelier : le serveur a déjà fermé sa session. Le stockage local du paquet est
-- effacé (T-157) : rendu le rang, le membre le retéléchargera.
RegisterNetEvent(EVENTS.REVOKED, function()
    session.forget()
    if loader then loader.forget() end
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
        -- essai joué : la page est cachée jusqu'à F9, le membre est prévenu hors d'elle
        if what == 'trialEnded' and suspended then
            local name = type(title) == 'string' and #title <= 64 and title or id
            session.feed(texts.trialEndedFeed:format(name), 'info')
        end
    elseif what == 'trialEnded' then
        local name = type(title) == 'string' and #title <= 64 and title or id
        session.feed(texts.trialEndedFeed:format(name), 'info')
    end
end)
