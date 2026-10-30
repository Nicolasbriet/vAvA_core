--[[
    vava_arrival/server/kit.lua
    Rôle : la dotation de départ. Objets de la config déclarés à l'inventaire s'ils manquent ; dotation d'une entrée
           « à donner » : objets connus, limite du compte, RÉSERVATION CONDITIONNELLE en base, limite recomptée après
           la réservation, entrée du fil et personnage actif relus juste avant l'échange atomique de vava_inventory
           (tout ou rien, sans céder la main entre les deux), état écrit, retour à « à donner » si l'échange échoue ;
           remises en cours tenues hors des entrées (un rechargement du personnage pendant la remise ne la prend pas
           pour une remise interrompue) ; dotation redonnée par le Conseil. Au plus une fois : la base arbitre (une
           ligne touchée), et une dotation interrompue par un arrêt du serveur n'est jamais redonnée d'office
           (« incertaine », store.lua).
    Dépendances : shared/constants.lua, config.lua, shared/rules.lua, server/core.lua, bridge/server.lua,
                  server/journal.lua, server/store.lua
]]

local pairs, pcall, error, tostring = pairs, pcall, error, tostring

local bridge = VavaArrival.bridge
local journal = VavaArrival.journal
local store = VavaArrival.store
local rules = VavaArrival.rules
local cfg = VavaArrival.config
local KIT = VavaArrival.KIT
local MISSING_ITEM_REPORT_S = VavaArrival.MISSING_ITEM_REPORT_S

local kit = {}
VavaArrival.kit = kit

-- objet de la dotation inconnu de l'inventaire → heure de la dernière ligne de console (une par objet et par 10 min)
local missingReportedAt = {}

-- personnage → nombre de remises en cours dans ce serveur (de la réservation à son issue). Indépendante des entrées,
-- elle survit à store.forget : un chargement du personnage pendant la remise ne la lit pas « incertaine » (store.lua).
---@type table<integer, integer>
local claiming = {}

--- Vrai si une remise de la dotation de ce personnage est en cours dans ce serveur.
---@param characterId integer
---@return boolean
function kit.isClaiming(characterId)
    return (claiming[characterId] or 0) > 0
end

--- Déclare les objets de la config à l'inventaire (ceux qu'il ne connaît pas encore). Rappelée au retour de
--- l'inventaire, qui a perdu les déclarations de tous les modules.
function kit.declareItems()
    for name, def in pairs(cfg.items) do
        local definition = {}
        for key, value in pairs(def) do definition[key] = value end
        definition.image = definition.image or ('nui://' .. VavaArrival.resource .. '/web/items/' .. name .. '.svg')
        bridge.DeclareItem(name, definition)
    end
end

--- Vrai si chaque objet de la dotation est connu de l'inventaire ; sinon une erreur en console par objet manquant, au
--- plus une fois par 10 min.
---@param items { item: string, quantity: integer }[]
---@return boolean
local function itemsKnown(items)
    local known = true
    for i = 1, #items do
        local name = items[i].item
        if not bridge.ItemExists(name) then
            known = false
            local now = bridge.Now()
            local last = missingReportedAt[name]
            if not last or now - last >= MISSING_ITEM_REPORT_S then
                missingReportedAt[name] = now
                VavaArrival.log.error("objet '%s' de la dotation inconnu de l'inventaire : dotation reportée (aucune réservation)", name)
            end
        end
    end
    return known
end

--- Transition refusée : erreur de la base (la mémoire garde son état, nouvel essai plus tard) ou ligne changée par un
--- autre entre-temps (entrée relue). Rien n'est donné.
---@param entry vAvA.ArrivalEntry
---@param err string|nil
---@return string state
---@return boolean given
---@return string code
local function refused(entry, err)
    if err then
        VavaArrival.log.warn('personnage n° %d : dotation non écrite (%s), nouvel essai plus tard', entry.characterId, err)
        return entry.kit, false, 'db_error'
    end
    store.refresh(entry)
    return entry.kit, false, 'changed'
end

--- État écrit en base, posé sur l'entrée du fil et sur celle qui l'a remplacée (personnage rechargé pendant la remise)
--- si celle-ci l'a lue « réservée ».
---@param entry vAvA.ArrivalEntry
---@param state string
---@param at integer|nil
local function settle(entry, state, at)
    entry.kit, entry.kitAt = state, at
    local current = store.entry(entry.characterId)
    if current and current ~= entry and current.kit == KIT.CLAIMED then current.kit, current.kitAt = state, at end
end

--- Dotations du compte dans la fenêtre de la limite (ce personnage exclu), ou nil si la base échoue (console).
---@param entry vAvA.ArrivalEntry
---@param now integer
---@param cap { max: integer, days: number }
---@return integer|nil
local function countAccount(entry, now, cap)
    local count, err = store.countKits(entry.accountId, entry.characterId, rules.capSince(now, cap.days))
    if not count then
        VavaArrival.log.warn('personnage n° %d : dotations du compte non comptées (%s), nouvel essai plus tard', entry.characterId, tostring(err))
    end
    return count
end

--- Dotation retenue (limite du compte atteinte) : transition conditionnelle depuis `from` (« à donner », ou
--- « réservée » quand la limite est atteinte au recomptage), console et journal.
---@param entry vAvA.ArrivalEntry
---@param from string
---@param now integer
---@param count integer
---@param cap { max: integer, days: number }
---@return string state
---@return boolean given
---@return string|nil code
local function withhold(entry, from, now, count, cap)
    local id, accountId = entry.characterId, entry.accountId
    local ok, err = store.transition(id, KIT.WITHHELD, now, from)
    if not ok then
        if from == KIT.DUE then return refused(entry, err) end
        -- la ligne reste réservée en base : plus d'essai cette session, relue « incertaine » au prochain chargement
        VavaArrival.log.error('personnage n° %d : dotation restée réservée (%s)', id, tostring(err or 'ligne changée'))
        return entry.kit, false, err and 'db_error' or 'changed'
    end
    settle(entry, KIT.WITHHELD, now)
    VavaArrival.log.info('personnage n° %d (compte n° %d) : dotation retenue, %d dotation(s) du compte en %d jours', id, accountId, count, cap.days)
    journal.write('kit_withheld', { characterId = id, accountId = accountId, details = { count = count, max = cap.max, days = cap.days } })
    return KIT.WITHHELD, false
end

--- Réservation rendue sans rien donner : retour conditionnel à « à donner » (nouvel essai à la prochaine apparition ou
--- au retour de l'inventaire).
---@param entry vAvA.ArrivalEntry
---@param code string|nil
---@return string state
---@return boolean given
---@return string|nil code
local function release(entry, code)
    local id = entry.characterId
    local back, backErr = store.transition(id, KIT.DUE, nil, KIT.CLAIMED)
    if back then
        settle(entry, KIT.DUE, nil)
    else
        -- la ligne reste réservée en base : plus d'essai cette session, relue « incertaine » au prochain chargement
        VavaArrival.log.error('personnage n° %d : dotation restée réservée (%s)', id, tostring(backErr or 'ligne changée'))
    end
    VavaArrival.log.warn('personnage n° %d : dotation non donnée (%s), nouvel essai à la prochaine apparition ou au retour de l\'inventaire', id, tostring(code))
    return entry.kit, false, code
end

--- Réservation, limite recomptée, échange et état écrit. Appelée par kit.claim, qui tient la remise en cours.
---@param entry vAvA.ArrivalEntry
---@param items { item: string, quantity: integer }[]
---@param cap { max: integer, days: number }
---@param now integer
---@return string state
---@return boolean given
---@return string|nil code
local function reserveAndGive(entry, items, cap, now)
    local id, source, accountId = entry.characterId, entry.source, entry.accountId

    -- réservation : écrite avant l'échange ; la base arbitre (une ligne touchée, sinon un autre l'a prise)
    local reserved, reserveErr = store.transition(id, KIT.CLAIMED, now, KIT.DUE)
    if not reserved then return refused(entry, reserveErr) end
    entry.kit, entry.kitAt = KIT.CLAIMED, now

    -- limite recomptée après la réservation : un fil dont le premier compte a vieilli pendant les attentes de la base
    -- ne la dépasse pas
    if cap.max > 0 then
        local count = countAccount(entry, now, cap)
        if not count then return release(entry, 'db_error') end
        if rules.capReached(count, cap.max) then return withhold(entry, KIT.CLAIMED, now, count, cap) end
    end

    -- juste avant l'échange, sans céder la main entre les relectures et l'échange : l'entrée est toujours celle du fil
    -- (sinon le personnage a été déchargé ou rechargé pendant les attentes de la base) et le personnage actif du joueur
    -- est toujours le sien
    local given, code
    if store.entry(id) ~= entry or bridge.ActiveCharacterId(source) ~= id then
        given, code = false, 'changed'
    else
        given, code = bridge.Exchange(source, {}, items)
    end
    if not given then return release(entry, code) end

    local done = bridge.Now()
    local written, err = store.transition(id, KIT.GIVEN, done, KIT.CLAIMED)
    if not written then
        VavaArrival.log.error('personnage n° %d : dotation donnée mais non écrite (%s) : elle sera relue « incertaine »', id, tostring(err or 'ligne changée'))
    end
    settle(entry, KIT.GIVEN, done)
    journal.write('kit_given', { characterId = id, accountId = accountId, details = { items = items } })
    return KIT.GIVEN, true
end

--- Donne la dotation d'une entrée « à donner ». L'appelant tient `entry.busy` (pris sans céder la main) ; bloque le
--- thread (attentes de la base).
---@param entry vAvA.ArrivalEntry
---@return string state  état après la dotation : given, withheld, due (échec : nouvel essai), uncertain, claimed…
---@return boolean given  vrai si des objets ont été donnés
---@return string|nil code
function kit.claim(entry)
    if entry.kit ~= KIT.DUE then return entry.kit, false end
    local id, accountId = entry.characterId, entry.accountId
    local items = cfg.kit.items
    local now = bridge.Now()

    if #items == 0 then
        local ok, err = store.transition(id, KIT.GIVEN, now, KIT.DUE)
        if not ok then return refused(entry, err) end
        entry.kit, entry.kitAt = KIT.GIVEN, now
        journal.write('kit_given', { characterId = id, accountId = accountId, details = { items = {} } })
        return KIT.GIVEN, false
    end

    if not itemsKnown(items) then return KIT.DUE, false, 'unknown_item' end

    local cap = cfg.kit.perAccount
    if cap.max > 0 then
        local count = countAccount(entry, now, cap)
        if not count then return KIT.DUE, false, 'db_error' end
        if rules.capReached(count, cap.max) then return withhold(entry, KIT.DUE, now, count, cap) end
    end

    -- remise en cours de la réservation à son issue, quelle qu'elle soit (réussite, refus ou erreur)
    claiming[id] = (claiming[id] or 0) + 1
    local ok, state, given, code = pcall(reserveAndGive, entry, items, cap, now)
    local left = claiming[id] - 1
    claiming[id] = left > 0 and left or nil
    if not ok then error(state, 0) end
    return state, given, code
end

--- Dotation redonnée par le Conseil, quels que soient l'état et la limite du compte (décision journalisée par
--- l'appelant). Bloque le thread.
---@param target integer   joueur qui la reçoit
---@param characterId integer
---@param accountId integer
---@param actor integer    membre du Conseil (0 : console)
---@return boolean ok
---@return string|nil code
function kit.regive(target, characterId, accountId, actor)
    local entry = store.entry(characterId)
    -- une remise en cours peut appartenir à une entrée remplacée (personnage rechargé pendant la remise)
    if (entry and entry.busy) or kit.isClaiming(characterId) then return false, 'busy' end
    local items = cfg.kit.items
    if not itemsKnown(items) then return false, 'unknown_item' end
    if entry then entry.busy = true end

    -- personnage actif relu juste avant l'échange, sans céder la main entre les deux
    local ok, code
    if bridge.ActiveCharacterId(target) ~= characterId then
        ok, code = false, 'changed'
    elseif #items == 0 then
        ok = true
    else
        ok, code = bridge.Exchange(target, {}, items)
    end
    if not ok then
        if entry then entry.busy = false end
        return false, code
    end

    local now = bridge.Now()
    local written, err = store.regive(characterId, accountId, now)
    if not written then
        VavaArrival.log.error('personnage n° %d : dotation redonnée mais non écrite (%s)', characterId, tostring(err))
    end
    if entry then entry.kit, entry.kitAt, entry.busy = KIT.GIVEN, now, false end
    journal.write('admin_regive', { characterId = characterId, accountId = accountId, actorAccountId = bridge.GetAccountId(actor),
        details = { items = items } })
    return true
end
