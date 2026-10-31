--[[
    server/players/characters.lua
    Rôle : personnages d'un compte : liste, création, sélection (chargement + apparition), déchargement,
           suppression douce, champs. Machine d'états par session :
             joined → loading → active → unloading → joined   (connecting est géré par accounts.lua)
           Une seule action à la fois par session (verrou busy) : spam et duplication de sélection impossibles.
           La fermeture d'une session (déconnexion) attend la fin de l'action en cours avant de décharger.
           Noms uniques (option) : le nom est réservé en mémoire pendant toute sa création (créations simultanées).
    Les intentions du client passent par les RPC core:characters:* ; le serveur valide et décide de tout.
    Dépendances : shared/init.lua, config/server.lua, shared/lib/string.lua, shared/core/logger.lua,
                  shared/core/hooks.lua, server/core/database.lua, server/core/rpc.lua, server/core/zones.lua,
                  server/players/*.lua
]]

local type, tostring, tonumber, pairs, xpcall, pcall = type, tostring, tonumber, pairs, xpcall, pcall
local traceback = debug.traceback
local tointeger = math.tointeger
local sort, concat = table.sort, table.concat
local utf8codes, utf8char = utf8.codes, utf8.char
local decodeJson, encodeJson = json.decode, json.encode
local newPromise, await = promise.new, Citizen.Await

local str = vAvA.lib.string
local hooks = vAvA.hooks
local database = vAvA.database
local rpc = vAvA.rpc
local accounts = vAvA.accounts
local fields = vAvA.fields
local sync = vAvA.sync
local persistence = vAvA.persistence
local playtime = vAvA.playtime
local positions = vAvA.positions
local spawn = vAvA.spawn
local zones = vAvA.zones
local cfg = vAvA.config.server.characters
local nameCfg = cfg.name
local log = vAvA.logger.create('characters')

local CORE = vAvA.CORE_OWNER
local RPC = vAvA.CHARACTER_RPC
local MAX_CHARACTER_ID = 0xFFFFFFFF  -- INT UNSIGNED
local UTF8_MAX_BYTES = 4             -- octets maximum par caractère : borne réseau d'un nom
local EMPTY_DATA = '{}'

local SELECT_SUMMARIES_SQL = 'SELECT `id`, `first_name`, `last_name`, `sex` FROM `vava_characters` WHERE `account_id` = ? AND `deleted_at` IS NULL'
local SELECT_CHARACTER_SQL = 'SELECT `id`, `first_name`, `last_name`, `sex`, `position_x`, `position_y`, `position_z`, `heading`, `play_seconds`, `data` '
    .. 'FROM `vava_characters` WHERE `id` = ? AND `account_id` = ? AND `deleted_at` IS NULL'
local INSERT_CHARACTER_SQL = 'INSERT INTO `vava_characters` (`account_id`, `first_name`, `last_name`, `sex`, `data`) VALUES (?, ?, ?, ?, ?)'
local COUNT_NAME_SQL = 'SELECT COUNT(*) FROM `vava_characters` WHERE `first_name` = ? AND `last_name` = ? AND `deleted_at` IS NULL'
local TOUCH_CHARACTER_SQL = 'UPDATE `vava_characters` SET `last_played_at` = CURRENT_TIMESTAMP WHERE `id` = ?'
local DELETE_CHARACTER_SQL = 'UPDATE `vava_characters` SET `deleted_at` = CURRENT_TIMESTAMP WHERE `id` = ? AND `account_id` = ? AND `deleted_at` IS NULL'

local HOOK_CREATING = 'core:character:creating'
local HOOK_CREATED = 'core:character:created'
local HOOK_LOADED = 'core:character:loaded'
local HOOK_UNLOADING = 'core:character:unloading'
local HOOK_DELETING = 'core:character:deleting'
local HOOK_DELETED = 'core:character:deleted'
local HOOK_FIELD_CHANGED = 'core:character:fieldChanged'

local NAME_LETTERS = str.codepointSet(nameCfg.letters)
local NAME_SEPARATORS = str.codepointSet(nameCfg.separators)
-- Règles de nom envoyées avec la liste des personnages (0.8.0) : config/server.lua ne part jamais chez les clients,
-- et une interface de création vérifie ainsi la saisie comme le serveur, sans en garder une copie écrite en dur.
local NAME_RULES = {
    minLength = nameCfg.minLength, maxLength = nameCfg.maxLength,
    letters = nameCfg.letters, separators = nameCfg.separators,
}
local SEXES = {}
for _, sex in pairs(cfg.sexes) do SEXES[sex] = true end

-- Repli d'un nom pour la réservation des noms uniques : casse et accents ignorés, comme la vérification en base
-- (collation utf8mb4_unicode_ci de vava_characters : « Jéan » = « JEAN », « æ » = « ae »). Couvre les lettres de la
-- config par défaut ; une lettre ajoutée hors de cette table n'est repliée qu'en casse ASCII (la base tranche ensuite).
local FOLDED = {}
for base, variants in pairs({
    a = 'àâäáãåÀÂÄÁÃÅ', c = 'çÇ', e = 'éèêëÉÈÊË', i = 'íìîïÍÌÎÏ', n = 'ñÑ', o = 'óòôöõøÓÒÔÖÕØ',
    u = 'úùûüÚÙÛÜ', y = 'ýÿÝŸ', ae = 'æÆ', oe = 'œŒ',
}) do
    for _, code in utf8codes(variants) do FOLDED[code] = base end
end
-- noms (repliés) dont la création est en cours : clé → true, retirée à la fin de la création quoi qu'il arrive
local reservedNames = {}

local characters = {}
vAvA.characters = characters

---@class vAvA.CharacterSummary
---@field id integer
---@field firstName string
---@field lastName string
---@field sex string

---@class vAvA.Character : vAvA.CharacterSummary
---@field accountId integer
---@field source integer
---@field position vAvA.SpawnPoint|nil
---@field data table<string, any>   valeurs des champs déclarés par les modules
---@field revision integer          incrémenté à chaque modification à sauvegarder
---@field savedRevision integer
---@field spawned boolean           apparition confirmée par le serveur (server/players/spawn.lua, 0.14.0)
---@field playSeconds integer       temps de jeu relevé (secondes entières), écrit en base
---@field playMarker integer|nil    GetGameTimer du dernier relevé ; nil quand le temps ne compte pas (non apparu)

---@type table<integer, vAvA.Character>
local activeById = {}

--- Valide et normalise un nom (espaces de bord retirés). Comptage et contrôle par caractère UTF-8.
---@param value any
---@return string|nil
local function validateName(value)
    if type(value) ~= 'string' then return nil end
    value = str.trim(value)
    local length = str.utf8Length(value)
    if not length or length < nameCfg.minLength or length > nameCfg.maxLength then return nil end
    local afterSeparator = true  -- interdit un séparateur en tête
    for _, code in utf8codes(value) do
        if NAME_SEPARATORS[code] then
            if afterSeparator then return nil end
            afterSeparator = true
        elseif NAME_LETTERS[code] then
            afterSeparator = false
        else
            return nil
        end
    end
    if afterSeparator then return nil end
    return value
end

---@param name string  nom déjà validé (UTF-8 valide, bords retirés)
---@return string
local function foldName(name)
    local parts = {}
    for _, code in utf8codes(name) do
        -- casse ASCII seulement : string.lower suit la locale et casserait une lettre ajoutée hors de FOLDED
        parts[#parts + 1] = FOLDED[code] or str.asciiLower(utf8char(code))
    end
    return concat(parts)
end

--- Clé de réservation d'un prénom + nom (le saut de ligne ne peut figurer dans aucun nom valide).
---@param firstName string
---@param lastName string
---@return string
local function nameKey(firstName, lastName)
    return foldName(firstName) .. '\n' .. foldName(lastName)
end

--- Raison de refus transmise au client : celle d'un module si elle est explicite, sinon un code générique.
---@param reason any
---@return string
local function publicReason(reason)
    if type(reason) == 'string' and reason ~= 'hook_error' and reason ~= 'cancelled' then return reason end
    return 'refused'
end

---@param session vAvA.Session
---@return vAvA.CharacterSummary[]
local function summariesOf(session)
    local list = {}
    for _, summary in pairs(session.characters) do list[#list + 1] = summary end
    sort(list, function(a, b) return a.id < b.id end)
    return list
end

---@param raw any
---@return table|nil
local function decodeData(raw)
    if type(raw) == 'table' then return raw end
    if raw == nil or raw == '' then return {} end
    if type(raw) ~= 'string' then return nil end
    local ok, decoded = pcall(decodeJson, raw)
    if ok and type(decoded) == 'table' then return decoded end
    return nil
end

---@param session vAvA.Session
---@param row table
---@return vAvA.Character|nil
local function buildCharacter(session, row)
    local data = decodeData(row.data)
    -- données illisibles : on refuse de charger plutôt que d'écraser la base avec une table vide
    if not data then return nil end
    local position
    if row.position_x and row.position_y and row.position_z then
        position = { x = row.position_x, y = row.position_y, z = row.position_z, heading = row.heading or 0.0 }
    end
    return {
        id = row.id, accountId = session.accountId, source = session.source,
        firstName = row.first_name, lastName = row.last_name, sex = row.sex,
        position = position, data = data, revision = 0, savedRevision = 0, spawned = false,
        playSeconds = tointeger(tonumber(row.play_seconds)) or 0,
    }
end

--- Exécute une action sous verrou de session, dans l'état attendu. Le verrou est libéré même en cas d'erreur.
---@param src integer
---@param expectedState vAvA.SessionState
---@param action fun(session: vAvA.Session, ...): boolean, any
---@return boolean ok
---@return any resultOrCode
local function withSession(src, expectedState, action, ...)
    local session = accounts.get(src)
    if not session then return false, 'no_session' end
    if session.busy then return false, 'busy' end
    if session.state ~= expectedState then return false, 'wrong_state' end
    session.busy = true
    local called, ok, result = xpcall(action, traceback, session, ...)
    session.busy = false
    -- une fermeture de session attendait la fin de l'action (characters.handleClose) : elle reprend la main
    local idle = session.idle
    if idle then
        session.idle = nil
        idle:resolve(true)
    end
    if not called then
        log.error('action personnage en erreur (compte #%s) : %s', tostring(session.accountId), tostring(ok))
        return false, 'server_error'
    end
    return ok, result
end

--- Sérialise les champs fournis à la création, chacun validé par le schéma de sa définition.
---@param initialFields table<string, any>|nil
---@return string|nil json
---@return string|nil code
local function encodeInitialFields(initialFields)
    if initialFields == nil then return EMPTY_DATA end
    if type(initialFields) ~= 'table' then return nil, 'invalid_fields' end
    local data = {}
    for name, value in pairs(initialFields) do
        local valid, err = fields.validate(name, value)
        if not valid then
            log.warn("création refusée : champ initial '%s' invalide (%s)", tostring(name), tostring(err))
            return nil, 'invalid_fields'
        end
        data[name] = value
    end
    local ok, encoded = pcall(encodeJson, data)
    if not ok then return nil, 'invalid_fields' end
    return encoded
end

--- Création d'un personnage déjà validé : hooks, écriture, résumé. Bloque le thread courant.
---@param session vAvA.Session
---@param firstName string
---@param lastName string
---@param sex string
---@param data string  champs initiaux sérialisés
---@return boolean ok
---@return vAvA.CharacterSummary|string result
local function insertCharacter(session, firstName, lastName, sex, data)
    local allowed, reason = hooks.runBefore(HOOK_CREATING, {
        source = session.source, accountId = session.accountId, firstName = firstName, lastName = lastName, sex = sex,
    })
    if not allowed then return false, publicReason(reason) end
    if not accounts.isCurrent(session) then return false, 'no_session' end

    local id, err = database.insert(CORE, INSERT_CHARACTER_SQL, { session.accountId, firstName, lastName, sex, data })
    if err then return false, 'db_error' end

    local summary = { id = id, firstName = firstName, lastName = lastName, sex = sex }
    session.characters[id] = summary
    log.info('compte #%d : personnage #%d créé', session.accountId, id)
    hooks.runAfter(HOOK_CREATED, {
        source = session.source, accountId = session.accountId, characterId = id,
        firstName = firstName, lastName = lastName, sex = sex,
    })
    return true, summary
end

--- Création avec noms uniques : vérification en base, puis création. Appelée sous réservation du nom.
---@return boolean ok
---@return vAvA.CharacterSummary|string result
local function insertUnique(session, firstName, lastName, sex, data)
    local taken, err = database.scalar(CORE, COUNT_NAME_SQL, { firstName, lastName })
    if err then return false, 'db_error' end
    if taken > 0 then return false, 'name_taken' end
    return insertCharacter(session, firstName, lastName, sex, data)
end

---@param session vAvA.Session
---@param firstName any
---@param lastName any
---@param sex any
---@param initialFields? table<string, any>  valeurs de champs déclarés, fournies par un module serveur
---@return boolean ok
---@return vAvA.CharacterSummary|string result
local function create(session, firstName, lastName, sex, initialFields)
    local count = 0
    for _ in pairs(session.characters) do count = count + 1 end
    if count >= cfg.maxPerAccount then return false, 'too_many_characters' end

    firstName, lastName = validateName(firstName), validateName(lastName)
    if not firstName or not lastName then return false, 'invalid_name' end
    if not SEXES[sex] then return false, 'invalid_sex' end
    local data, fieldsErr = encodeInitialFields(initialFields)
    if not data then return false, fieldsErr end

    if not cfg.uniqueNames then return insertCharacter(session, firstName, lastName, sex, data) end

    -- COUNT puis INSERT ne sont pas atomiques : sans réservation, deux créations simultanées (deux comptes) du même
    -- nom passeraient toutes deux la vérification. FXServer est un seul processus : une réservation en mémoire,
    -- prise avant toute attente, suffit ; une création simultanée du même nom reçoit name_taken.
    local key = nameKey(firstName, lastName)
    if reservedNames[key] then return false, 'name_taken' end
    reservedNames[key] = true
    local called, ok, result = xpcall(insertUnique, traceback, session, firstName, lastName, sex, data)
    -- libérée quoi qu'il arrive (succès, refus, erreur) : une fois le personnage écrit, la base fait foi
    reservedNames[key] = nil
    if not called then error(ok, 0) end
    return ok, result
end

---@param session vAvA.Session
---@param characterId integer
---@return boolean ok
---@return string|nil code
local function selectCharacter(session, characterId)
    if not session.characters[characterId] then return false, 'not_owner' end
    -- encore chargé : la session précédente du compte (reconnexion rapide) termine son déchargement et sa
    -- sauvegarde ; le recharger maintenant lirait la base avant cette sauvegarde, puis serait retiré par elle
    if activeById[characterId] then return false, 'busy' end
    session.state = 'loading'

    -- un personnage déchargé sans avoir pu être sauvegardé est plus récent que la base : il est réutilisé
    local character = persistence.takeRetry(characterId)
    if character then
        character.source, character.spawned, character.playMarker = session.source, false, nil
    else
        local row, err = database.single(CORE, SELECT_CHARACTER_SQL, { characterId, session.accountId })
        if not accounts.isCurrent(session) then return false, 'no_session' end
        if err or not row then
            session.state = 'joined'
            return false, err and 'db_error' or 'not_found'
        end
        character = buildCharacter(session, row)
        if not character then
            session.state = 'joined'
            log.error('personnage #%d : données illisibles, chargement refusé', characterId)
            return false, 'corrupted_data'
        end
    end

    activeById[characterId] = character
    session.characterId = characterId
    database.update(CORE, TOUCH_CHARACTER_SQL, { characterId })
    -- les modules chargent leurs propres données avant l'apparition
    hooks.runAfter(HOOK_LOADED, {
        source = session.source, accountId = session.accountId, characterId = characterId,
        playSeconds = playtime.current(character),
    })
    if not accounts.isCurrent(session) then return false, 'no_session' end

    session.state = 'active'
    sync.sendCharacter(character)
    spawn.forCharacter(character)
    return true
end

--- Décharge le personnage actif : hooks (les modules sauvent leurs données), sauvegarde, nettoyage.
--- Bloque le thread courant.
---@param session vAvA.Session
---@param reason string
---@return boolean ok
---@return string|nil code
local function unload(session, reason)
    local character = session.characterId and activeById[session.characterId]
    if not character then return false, 'no_character' end
    session.state = 'unloading'
    positions.sample(character)
    playtime.pause(character)
    hooks.runAfter(HOOK_UNLOADING, {
        source = session.source, accountId = session.accountId, characterId = character.id, reason = reason,
        playSeconds = character.playSeconds,
    })
    persistence.saveCharacter(character)
    activeById[character.id] = nil
    session.characterId = nil
    character.spawned = false
    spawn.forget(character)
    -- abonnements de zone oubliés sans envoi : le client vide ses zones au déchargement
    zones.purgePlayer(session.source)
    sync.clearCharacter(character)
    session.state = 'joined'
    return true
end

---@param session vAvA.Session
---@param characterId integer
---@return boolean ok
---@return string|nil code
local function delete(session, characterId)
    if not session.characters[characterId] then return false, 'not_owner' end
    local payload = { source = session.source, accountId = session.accountId, characterId = characterId }
    local allowed, reason = hooks.runBefore(HOOK_DELETING, payload)
    if not allowed then return false, publicReason(reason) end
    local affected, err = database.update(CORE, DELETE_CHARACTER_SQL, { characterId, session.accountId })
    if err then return false, 'db_error' end
    if affected == 0 then return false, 'not_found' end
    session.characters[characterId] = nil
    log.info('compte #%d : personnage #%d supprimé', session.accountId, characterId)
    hooks.runAfter(HOOK_DELETED, payload)
    return true
end

--- Charge les résumés des personnages d'une session en cours de connexion (1 requête). Bloque le thread.
---@param session vAvA.Session
---@return boolean ok
---@return string|nil err
function characters.prepareSession(session)
    local rows, err = database.query(CORE, SELECT_SUMMARIES_SQL, { session.accountId })
    if err then return false, err end
    local summaries = {}
    for i = 1, #rows do
        local row = rows[i]
        summaries[row.id] = { id = row.id, firstName = row.first_name, lastName = row.last_name, sex = row.sex }
    end
    session.characters = summaries
    return true
end

--- Fermeture d'une session (déconnexion, session fantôme) : décharge le personnage actif s'il y en a un.
--- Une action en cours (sélection, déchargement…) se termine d'abord : elle s'interrompt d'elle-même à sa
--- prochaine vérification (session fermée). Sans cette attente, un déchargement en cours serait rejoué
--- (hooks unloading en double) et des modules chargeraient leurs données après le déchargement.
--- Bloque le thread courant.
---@param session vAvA.Session
---@param reason string
function characters.handleClose(session, reason)
    -- boucle : une autre action (lancée par un module) a pu commencer entre la fin de la précédente et la reprise
    while session.busy do
        local idle = session.idle or newPromise()
        session.idle = idle
        await(idle)
    end
    if session.characterId and activeById[session.characterId] then
        unload(session, reason)
    end
end

---@param fn fun(character: vAvA.Character)
function characters.forEachActive(fn)
    for _, character in pairs(activeById) do fn(character) end
end

---@class vAvA.CharacterInfo
---@field id integer
---@field accountId integer
---@field source integer
---@field firstName string
---@field lastName string
---@field sex string
---@field playSeconds integer  temps de jeu total, temps en cours compris

--- Identité du personnage actif d'un joueur, ou nil.
---@param src integer
---@return vAvA.CharacterInfo|nil
function characters.describeActive(src)
    local session = accounts.get(src)
    local character = session and session.characterId and activeById[session.characterId]
    if not character then return nil end
    return {
        id = character.id, accountId = character.accountId, source = character.source,
        firstName = character.firstName, lastName = character.lastName, sex = character.sex,
        playSeconds = playtime.current(character),
    }
end

--- Temps de jeu d'un personnage chargé (secondes entières, temps en cours compris).
---@param characterId integer
---@return integer|nil seconds
---@return string|nil err
function characters.playSeconds(characterId)
    local character = activeById[characterId]
    if not character then return nil, 'not_loaded' end
    return playtime.current(character)
end

--- Valeur d'un champ d'un personnage chargé.
---@param characterId integer
---@param name string
---@return any value
---@return string|nil err
function characters.getField(characterId, name)
    local character = activeById[characterId]
    if not character then return nil, 'not_loaded' end
    return fields.get(character, name)
end

--- Écrit un champ d'un personnage chargé : validé, marqué à sauvegarder, diffusé selon sa visibilité.
---@param characterId integer
---@param name string
---@param value any
---@return boolean ok
---@return string|nil err
function characters.setField(characterId, name, value)
    local character = activeById[characterId]
    if not character then return false, 'not_loaded' end
    local ok, changed = fields.set(character, name, value)
    if not ok then return false, changed end
    if changed then
        sync.fieldChanged(character, changed)
        hooks.runAfter(HOOK_FIELD_CHANGED, { characterId = characterId, field = name, value = value })
    end
    return true
end

---@class vAvA.CharacterIdentity
---@field firstName string
---@field lastName string
---@field sex string

--- Création décidée par un module serveur (par exemple avec l'apparence choisie). Mêmes règles que la création
--- par le joueur ; les champs initiaux doivent être déclarés et respecter leur schéma. Bloque le thread courant.
---@param src integer
---@param identity vAvA.CharacterIdentity
---@param initialFields? table<string, any>
---@return boolean ok
---@return vAvA.CharacterSummary|string result
function characters.create(src, identity, initialFields)
    if type(identity) ~= 'table' then return false, 'invalid_name' end
    return withSession(src, 'joined', create, identity.firstName, identity.lastName, identity.sex, initialFields)
end

--- Déchargement décidé par le serveur (retour à la sélection). Bloque le thread courant.
---@param src integer
---@param reason? string
---@return boolean ok
---@return string|nil code
function characters.unload(src, reason)
    return withSession(src, 'active', unload, reason or 'server')
end

--- Vrai si l'apparition du personnage actif du joueur est confirmée par le serveur (0.14.0) : ped vu au point du
--- dernier ordre d'apparition. Faux pendant une apparition ou une téléportation en cours.
---@param src integer
---@return boolean spawned
---@return string|nil err  'no_character' : aucun personnage actif
function characters.isSpawned(src)
    local session = accounts.get(src)
    local character = session and session.state == 'active' and activeById[session.characterId]
    if not character then return false, 'no_character' end
    return character.spawned == true
end

--- Réapparition ou téléportation décidée par le serveur.
---@param src integer
---@param coords? vAvA.SpawnPoint
---@return boolean ok
---@return string|nil code
function characters.spawn(src, coords)
    local session = accounts.get(src)
    local character = session and session.state == 'active' and activeById[session.characterId]
    if not character then return false, 'no_character' end
    return spawn.at(character, coords)
end

--- Enregistre les RPC des personnages. Appelé par init.lua, après la validation de la config du rate limiting.
---@return boolean ok
---@return string|nil err
function characters.registerRpc()
    -- réglages de la confirmation d'apparition (0.14.0) vérifiés avec ceux des RPC : invalides, le core ne démarre pas
    local valid, configErr = spawn.validateConfig()
    if not valid then return false, configErr end
    local nameArg = { type = 'string', min = 1, max = nameCfg.maxLength * UTF8_MAX_BYTES }
    local idArg = { type = 'integer', min = 1, max = MAX_CHARACTER_ID }
    local limits = cfg.rateLimits

    local definitions = {
        { RPC.LIST, {}, limits.list, function(src)
            local session = accounts.get(src)
            if not session then return false, 'no_session' end
            -- le maximum et les règles de nom permettent à une interface d'afficher les emplacements libres et de
            -- vérifier un nom sans connaître la config (le serveur revérifie tout à la création)
            return true, summariesOf(session), cfg.maxPerAccount, NAME_RULES
        end },
        { RPC.CREATE, { nameArg, nameArg, { type = 'string', enum = cfg.sexes } }, limits.create, function(src, firstName, lastName, sex)
            return withSession(src, 'joined', create, firstName, lastName, sex)
        end },
        { RPC.SELECT, { idArg }, limits.select, function(src, characterId)
            return withSession(src, 'joined', selectCharacter, characterId)
        end },
        { RPC.UNLOAD, {}, limits.unload, function(src)
            return withSession(src, 'active', unload, 'player')
        end },
        { RPC.DELETE, { idArg }, limits.delete, function(src, characterId)
            return withSession(src, 'joined', delete, characterId)
        end },
        { RPC.SPAWNED, {}, limits.spawned, function(src)
            local session = accounts.get(src)
            local character = session and session.state == 'active' and activeById[session.characterId]
            if not character then return false, 'no_character' end
            -- simple déclaration : le serveur ne confirme l'apparition qu'après avoir vu le ped au point ordonné
            -- (spawn.claim, une fois par ordre : spawn.send remet l'état à faux)
            return spawn.claim(character)
        end },
    }

    for i = 1, #definitions do
        local def = definitions[i]
        local ok, err = rpc.register(CORE, def[1], { args = def[2], rateLimit = def[3] }, def[4])
        if not ok then return false, def[1] .. ' : ' .. err end
    end
    return true
end
