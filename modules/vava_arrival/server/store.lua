--[[
    vava_arrival/server/store.lua
    Rôle : table vava_arrival et sa mémoire : une entrée par personnage CHARGÉ qui a une ligne (bornée par le nombre de
           joueurs). Reconnaissance d'une première venue au chargement (temps de jeu mesuré par le core et ligne en
           base), reprise d'une ligne, dotation réservée relue « incertaine » (sauf remise en cours dans ce serveur :
           personnage rechargé pendant qu'elle se fait) ; transitions CONDITIONNELLES de l'état
           de la dotation (la base arbitre : une ligne touchée ou rien) ; envois comptés, accusé de lecture ; écritures
           du Conseil (redoter, rejouer). Toutes les requêtes sont paramétrées ; les états sont des littéraux du SQL ou
           des paramètres, jamais concaténés.
    Dépendances : shared/constants.lua, config.lua, shared/rules.lua, server/core.lua, bridge/server.lua,
                  server/journal.lua ; server/kit.lua lu à l'appel (remise en cours, chargé après ce fichier)
]]

local pairs, tonumber, tostring = pairs, tonumber, tostring
local tointeger = math.tointeger

local bridge = VavaArrival.bridge
local journal = VavaArrival.journal
local rules = VavaArrival.rules
local KIT = VavaArrival.KIT

local SQL = {
    SELECT_ROW = 'SELECT `kit`, `kit_at`, `welcomed_at`, `welcome_sends` FROM `vava_arrival` WHERE `character_id` = ?',
    INSERT_ROW = "INSERT IGNORE INTO `vava_arrival` (`character_id`, `account_id`, `kit`, `created_at`) VALUES (?, ?, 'due', ?)",
    TRANSITION = 'UPDATE `vava_arrival` SET `kit` = ?, `kit_at` = ? WHERE `character_id` = ? AND `kit` = ?',
    COUNT_KITS = "SELECT COUNT(*) FROM `vava_arrival` WHERE `account_id` = ? AND `character_id` <> ? AND `kit` IN ('claimed', 'given', 'uncertain') AND `kit_at` >= ?",
    COUNT_SEND = 'UPDATE `vava_arrival` SET `welcome_sends` = `welcome_sends` + 1 WHERE `character_id` = ?',
    ACK = 'UPDATE `vava_arrival` SET `welcomed_at` = ? WHERE `character_id` = ? AND `welcomed_at` IS NULL',
    -- une ligne créée ici (personnage d'avant l'accueil) naît « vue » : redoter ne déclenche pas d'accueil plus tard
    REGIVE = "INSERT INTO `vava_arrival` (`character_id`, `account_id`, `kit`, `kit_at`, `welcomed_at`, `created_at`) VALUES (?, ?, 'given', ?, ?, ?) ON DUPLICATE KEY UPDATE `kit` = 'given', `kit_at` = ?",
    REPLAY = "INSERT INTO `vava_arrival` (`character_id`, `account_id`, `kit`, `created_at`, `welcome_sends`) VALUES (?, ?, 'none', ?, 1) ON DUPLICATE KEY UPDATE `welcomed_at` = NULL, `welcome_sends` = 1",
}

local store = {}
VavaArrival.store = store
store.SQL = SQL

---@class vAvA.ArrivalEntry
---@field characterId integer
---@field accountId integer
---@field source integer
---@field kit string
---@field kitAt? integer
---@field welcomedAt? integer
---@field welcomeSends integer
---@field spawned boolean      apparition confirmée pendant cette session
---@field busy boolean         dotation, envoi ou action du Conseil en cours (pris sans céder la main)
---@field awaitingAck boolean  accueil envoyé pendant cette session, pas encore accusé

---@type table<integer, vAvA.ArrivalEntry>
local entries = {}
---@type table<integer, integer>
local bySource = {}

--- Vrai si une remise de la dotation de ce personnage est en cours dans ce serveur (server/kit.lua).
---@param characterId integer
---@return boolean
local function claimInProgress(characterId)
    local kit = VavaArrival.kit
    return kit ~= nil and kit.isClaiming(characterId) == true
end

---@param value any
---@return integer|nil
local function integer(value)
    local number = tonumber(value)
    return number and tointeger(number) or nil
end

--- Ligne lue en base, ramenée à la forme de la mémoire.
---@param row table
---@return vAvA.ArrivalRow
local function normalize(row)
    return {
        kit = tostring(row.kit),
        kitAt = integer(row.kit_at),
        welcomedAt = integer(row.welcomed_at),
        welcomeSends = integer(row.welcome_sends) or 0,
    }
end

--- Lit la ligne d'un personnage : `row` (forme de la mémoire), `nil` sans ligne, ou `false, err` si la base échoue.
---@param characterId integer
---@return vAvA.ArrivalRow|false|nil
---@return string|nil err
function store.read(characterId)
    local row, err = bridge.db.single(SQL.SELECT_ROW, { characterId })
    if err then return false, tostring(err) end
    if row == nil then return nil end
    return normalize(row)
end

---@param characterId integer
---@return vAvA.ArrivalEntry|nil
function store.entry(characterId)
    return entries[characterId]
end

--- Entrée du personnage actif d'un joueur (celle de ce joueur seulement), ou nil.
---@param source integer
---@return vAvA.ArrivalEntry|nil
function store.bySource(source)
    local characterId = bySource[source]
    local entry = characterId and entries[characterId]
    if entry and entry.source == source then return entry end
    return nil
end

--- Pose une entrée en mémoire d'après une ligne (remplace la précédente de ce personnage et de ce joueur).
---@param source integer
---@param accountId integer
---@param characterId integer
---@param row vAvA.ArrivalRow
---@param spawned boolean
---@return vAvA.ArrivalEntry
function store.put(source, accountId, characterId, row, spawned)
    local previous = bySource[source]
    if previous and previous ~= characterId then entries[previous] = nil end
    local entry = {
        characterId = characterId, accountId = accountId, source = source,
        kit = row.kit, kitAt = row.kitAt, welcomedAt = row.welcomedAt, welcomeSends = row.welcomeSends or 0,
        spawned = spawned == true, busy = false, awaitingAck = false,
    }
    entries[characterId] = entry
    bySource[source] = characterId
    return entry
end

--- Relit la ligne d'une entrée et met la mémoire à jour (transition refusée : un autre a écrit entre-temps).
---@param entry vAvA.ArrivalEntry
---@return boolean ok
function store.refresh(entry)
    local row, err = store.read(entry.characterId)
    if row == false or row == nil then
        VavaArrival.log.warn('personnage n° %d : ligne de l\'accueil non relue (%s)', entry.characterId, tostring(err or 'absente'))
        return false
    end
    entry.kit, entry.kitAt, entry.welcomedAt, entry.welcomeSends = row.kit, row.kitAt, row.welcomedAt, row.welcomeSends
    return true
end

--- Transition conditionnelle de la dotation : `from` → `to`, réussie seulement si la base touche une ligne.
---@param characterId integer
---@param to string
---@param at integer|nil
---@param from string
---@return boolean ok
---@return string|nil err  nil : la ligne n'était plus dans l'état `from`
function store.transition(characterId, to, at, from)
    local affected, err = bridge.db.update(SQL.TRANSITION, { to, at, characterId, from })
    if err then return false, tostring(err) end
    return affected == 1
end

--- Dotations du compte (réservées, données, incertaines) depuis `since`, ce personnage exclu.
---@return integer|nil count
---@return string|nil err
function store.countKits(accountId, characterId, since)
    local count, err = bridge.db.scalar(SQL.COUNT_KITS, { accountId, characterId, since })
    if err then return nil, tostring(err) end
    return integer(count) or 0
end

--- Un envoi de l'accueil de plus.
---@param characterId integer
function store.countSend(characterId)
    local _, err = bridge.db.update(SQL.COUNT_SEND, { characterId })
    if err then VavaArrival.log.warn('personnage n° %d : envoi de l\'accueil non compté (%s)', characterId, tostring(err)) end
end

--- Accusé de lecture (conditionnel : une seule fois).
---@return boolean ok
---@return string|nil err
function store.ack(characterId, now)
    local _, err = bridge.db.update(SQL.ACK, { now, characterId })
    if err then return false, tostring(err) end
    return true
end

--- Dotation redonnée par le Conseil : ligne passée à « donnée », ou créée « donnée » et accueil « vu » (personnage
--- d'avant l'accueil : rien ne lui sera envoyé ensuite).
---@return boolean ok
---@return string|nil err
function store.regive(characterId, accountId, now)
    local _, err = bridge.db.update(SQL.REGIVE, { characterId, accountId, now, now, now, now })
    if err then return false, tostring(err) end
    return true
end

--- Accueil rejoué par le Conseil : ligne créée (« aucune » dotation) ou accueil remis à zéro, un envoi compté.
---@return boolean ok
---@return string|nil err
function store.replay(characterId, accountId, now)
    local _, err = bridge.db.update(SQL.REPLAY, { characterId, accountId, now })
    if err then return false, tostring(err) end
    return true
end

--- Reconnaissance au chargement d'un personnage (hook core:character:loaded, avant l'apparition ; bloque le thread).
--- Jamais d'entrée sur une lecture ou une écriture incertaine : pas de dotation cette session.
---@param source integer
---@param accountId integer
---@param characterId integer
---@param playSeconds any
---@param spawned? boolean  vrai pour un joueur déjà en jeu (module redémarré)
---@return vAvA.ArrivalEntry|nil
function store.load(source, accountId, characterId, playSeconds, spawned)
    store.forget(source)
    local row, err = store.read(characterId)
    if row == false then
        VavaArrival.log.warn('personnage n° %d : ligne de l\'accueil illisible, rien cette session (%s)', characterId, err)
        return nil
    end
    local decision = rules.onLoad(row, playSeconds)
    if decision.action == 'ignore' then return nil end
    if decision.action == 'create' then
        local now = bridge.Now()
        local affected, insertErr = bridge.db.update(SQL.INSERT_ROW, { characterId, accountId, now })
        if insertErr then
            VavaArrival.log.warn('personnage n° %d : ligne de l\'accueil non créée, rien cette session (%s)', characterId, tostring(insertErr))
            return nil
        end
        if affected == 1 then
            return store.put(source, accountId, characterId, { kit = KIT.DUE, welcomeSends = 0 }, spawned)
        end
        -- une ligne existe déjà (écrite entre la lecture et l'insertion) : relue une fois
        row, err = store.read(characterId)
        if not row then
            VavaArrival.log.warn('personnage n° %d : ligne de l\'accueil non relue, rien cette session (%s)', characterId, tostring(err or 'absente'))
            return nil
        end
        decision = rules.onLoad(row, playSeconds)
    end
    -- réservée par une remise en cours dans ce serveur (personnage déchargé puis rechargé pendant ses attentes de la
    -- base) : reprise « réservée », la remise écrit son issue et la pose aussi sur cette entrée (kit.lua)
    if decision.uncertain and row.kit == KIT.CLAIMED and claimInProgress(characterId) then
        decision.uncertain = false
    end
    if decision.uncertain then
        local ok, transitionErr = store.transition(characterId, KIT.UNCERTAIN, row.kitAt, row.kit)
        if not ok then
            VavaArrival.log.warn('personnage n° %d : dotation incertaine non écrite, rien cette session (%s)', characterId, tostring(transitionErr or 'ligne changée'))
            return nil
        end
        VavaArrival.log.error('personnage n° %d : dotation incertaine (serveur arrêté pendant la remise) ; /accueil etat puis redoter s\'il le faut', characterId)
        journal.write('kit_uncertain', { characterId = characterId, accountId = accountId, details = { since = row.kitAt } })
        row.kit = KIT.UNCERTAIN
    end
    return store.put(source, accountId, characterId, row, spawned)
end

--- Oublie l'entrée d'un joueur (déchargement, départ). Un thread en cours se termine : ses écritures sont
--- conditionnelles et son envoi revérifie le personnage actif.
---@param source integer
function store.forget(source)
    local characterId = bySource[source]
    if not characterId then return end
    bySource[source] = nil
    local entry = entries[characterId]
    if entry and entry.source == source then entries[characterId] = nil end
end

--- Entrées en mémoire (copie de la liste : l'appelant peut en changer pendant le parcours).
---@return vAvA.ArrivalEntry[]
function store.list()
    local list = {}
    for _, entry in pairs(entries) do list[#list + 1] = entry end
    return list
end
