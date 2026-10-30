--[[
    vava_example/server/main.lua
    Rôle : démonstration côté serveur d'un module vAvA :
      - garde      : `setup` refuse sans `set vava_env dev` (aucun RPC, aucune commande) ; /note réservé au droit
                     vava_admin `staff` ou à l'ACE `vava.dev` (config `access`), revérifié à chaque appel
      - migrations : sql/0001 (table), sql/0002 (colonne character_id), appliquées par le core avant setup()
      - registre   : vava_example:noteTypes (types de notes, extensible par d'autres modules)
      - hooks      : vava_example:notePost (before = filtre annulable, after = journal),
                     écoute de core:module:ready et core:character:created
      - RPC        : vava_example:postNote (client → serveur), vava_example:ping (serveur → client)
      - champ      : vava_example:notesPublished (compteur par personnage, visible par son seul joueur)
      - rétention  : au plus `maxNotesPerCharacter` notes gardées par personnage, notes de plus de `retentionDays`
                     jours retirées au démarrage
    Dépendances : vAvA_core (API v1, core ≥ 0.2.0), config.lua, shared/guard.lua, shared/limits.lua ;
                  facultatif : vava_admin (droit)
]]

local RESOURCE = GetCurrentResourceName()
local cfg = VavaExample.config
local guard = VavaExample.guard
local limits = VavaExample.limits

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

local log = core.log
local ipairs, pairs, tonumber, tostring, pcall = ipairs, pairs, tonumber, tostring, pcall
local find, lower = string.find, string.lower
local tointeger = math.tointeger
local GetConvar, GetResourceState, IsPlayerAceAllowed = GetConvar, GetResourceState, IsPlayerAceAllowed

local ADMIN = 'vava_admin'
local REGISTRY_NOTE_TYPES = RESOURCE .. ':noteTypes'
local HOOK_NOTE_POST = RESOURCE .. ':notePost'
local RPC_POST_NOTE = RESOURCE .. ':postNote'
local RPC_PING = RESOURCE .. ':ping'
local FIELD_NOTES_PUBLISHED = RESOURCE .. ':notesPublished'

local INSERT_NOTE_SQL = 'INSERT INTO `vava_example_notes` (`note_type`, `author`, `character_id`, `content`) VALUES (?, ?, ?, ?)'
local COUNT_NOTES_SQL = 'SELECT COUNT(*) FROM `vava_example_notes` WHERE `character_id` = ?'
local PURGE_NOTES_SQL = 'DELETE FROM `vava_example_notes` WHERE `created_at` < DATE_SUB(NOW(), INTERVAL ? DAY)'

-- personnages dont une note est en cours d'écriture : une seule à la fois (le plafond ne se franchit pas à deux)
local posting = {}

--- Mode développement relu à chaque appel, puis droit vava_admin (appel isolé) ou ACE : rien d'autre n'ouvre la publication.
---@param source integer
---@return boolean
local function allowed(source)
    local adminStarted = GetResourceState(ADMIN) == 'started'
    local adminCalled, adminCan = false, nil
    if adminStarted then
        adminCalled, adminCan = pcall(function() return exports[ADMIN]:can(source, cfg.access.permission) end)
    end
    return guard.allowed({
        devMode = guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK)),
        adminStarted = adminStarted,
        adminCalled = adminCalled,
        adminCan = adminCan,
        ace = IsPlayerAceAllowed(source, cfg.access.ace) == true,
    })
end

---@param content string
---@return boolean
local function containsForbiddenWord(content)
    local text = lower(content)
    for _, word in ipairs(cfg.forbiddenWords) do
        if find(text, word, 1, true) then return true end
    end
    return false
end

--- Écrit la note d'un personnage dont le verrou est pris : plafond, hook annulable, insertion, compteur.
---@param source integer
---@param character table
---@param noteType string
---@param content string
---@return boolean ok
---@return integer|string noteIdOrCode
local function publish(source, character, noteType, content)
    local count, countErr = core.db.scalar(COUNT_NOTES_SQL, { character.id })
    if countErr then log.warn('notes non comptées : %s', tostring(countErr)) end
    local permitted, limitCode = limits.check(count, cfg.maxNotesPerCharacter)
    if not permitted then return false, limitCode end

    local author = character.firstName .. ' ' .. character.lastName
    local payload = { source = source, characterId = character.id, author = author, noteType = noteType, content = content }
    local allowedByHooks, reason = core.hooks.runBefore(HOOK_NOTE_POST, payload)
    if not allowedByHooks then return false, reason end

    local noteId, dbErr = core.db.insert(INSERT_NOTE_SQL, { noteType, author, character.id, content })
    if not noteId then
        -- le détail est déjà journalisé par le core ; le client ne reçoit qu'un code
        log.warn('note non enregistrée : %s', tostring(dbErr))
        return false, 'db_error'
    end

    -- champ de personnage : validé par le core, sauvegardé avec le personnage, envoyé à son seul joueur
    local published = core.characters.get(character.id, FIELD_NOTES_PUBLISHED) or 0
    core.characters.set(character.id, FIELD_NOTES_PUBLISHED, published + 1)

    payload.noteId = noteId
    core.hooks.runAfter(HOOK_NOTE_POST, payload)
    return true, noteId
end

--- Handler RPC : les arguments sont déjà validés par le core (types, longueurs, motif). Reste la logique métier.
--- Renvoie (true, noteId) ou (false, raison) ; le client reçoit ces valeurs après le "ok" de transport.
---@param source integer
---@param noteType string
---@param content string
local function postNote(source, noteType, content)
    if not allowed(source) then return false, 'not_allowed' end

    -- lecture en mémoire dans le core, aucune requête base
    local noteDef = core.registry.get(REGISTRY_NOTE_TYPES, noteType)
    if not noteDef then return false, 'unknown_type' end
    if #content > noteDef.maxLength then return false, 'too_long' end

    -- une note est signée par un personnage, jamais par un compte : sans personnage actif, pas de note
    local character = core.characters.getActive(source)
    if not character then return false, 'no_character' end

    if posting[character.id] then return false, 'busy' end
    posting[character.id] = true
    local called, ok, result = pcall(publish, source, character, noteType, content)
    posting[character.id] = nil
    if not called then
        log.error('note non publiée : %s', tostring(ok))
        return false, 'error'
    end
    return ok, result
end

--- Commande console/admin : interroge un client et valide sa réponse (valeur déclarée, donc non fiable).
---@param _ integer  numéro du joueur, inutile ici
---@param args string[]
local function pingCommand(_, args)
    local target = tointeger(tonumber(args[1]))
    if not target then
        log.warn('usage : example_ping <id joueur>')
        return
    end
    CreateThread(function()
        local ok, clientTimer = core.rpc.callClientWith({
            timeout = cfg.pingTimeoutMs,
            returns = { { type = 'integer', min = 0 } },
        }, target, RPC_PING)
        if ok then
            log.info('joueur %d : GetGameTimer client = %d ms (déclaré par le client)', target, clientTimer)
        else
            log.warn('ping du joueur %d échoué : %s', target, tostring(clientTimer))
        end
    end)
end

--- Retire les notes trop anciennes (au démarrage, sans le faire attendre).
local function purge()
    CreateThread(function()
        local removed, err = core.db.update(PURGE_NOTES_SQL, { cfg.retentionDays })
        if err then
            log.warn('notes non purgées : %s', tostring(err))
        elseif tonumber(removed) and tonumber(removed) > 0 then
            log.info('%d note(s) de plus de %d jours retirée(s)', tonumber(removed), cfg.retentionDays)
        end
    end)
end

--- Appelé par le core une fois les dépendances prêtes et la migration appliquée.
--- Renvoyer false[, raison] fait échouer le module : le core purge alors tout ce qu'il a enregistré.
local function setup()
    -- module de démonstration : rien n'est offert hors du mode développement
    if not guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK)) then return false, guard.REFUSAL end

    local ok, err = core.registry.define(REGISTRY_NOTE_TYPES, {
        schema = {
            type = 'table',
            fields = {
                label = { type = 'string', min = 1, max = 32 },
                maxLength = { type = 'integer', min = 1, max = 500 },
            },
        },
    })
    if not ok then return false, err end

    for key, noteType in pairs(cfg.noteTypes) do
        ok, err = core.registry.add(REGISTRY_NOTE_TYPES, key, noteType)
        if not ok then return false, err end
    end

    local hookId
    hookId, err = core.hooks.before(HOOK_NOTE_POST, function(payload)
        if containsForbiddenWord(payload.content) then
            return false, 'forbidden_word'
        end
    end, cfg.forbiddenWordsPriority)
    if not hookId then return false, err end

    hookId, err = core.hooks.after(HOOK_NOTE_POST, function(payload)
        log.info('note #%d (%s) publiée par %s (personnage #%d, joueur %d)',
            payload.noteId, payload.noteType, payload.author, payload.characterId, payload.source)
    end)
    if not hookId then return false, err end

    hookId, err = core.hooks.after('core:module:ready', function(info)
        log.debug("module '%s' v%s prêt", info.name, info.version)
    end)
    if not hookId then return false, err end

    hookId, err = core.hooks.after('core:character:created', function(info)
        log.info('bienvenue à %s %s (personnage #%d)', info.firstName, info.lastName, info.characterId)
    end)
    if not hookId then return false, err end

    ok, err = core.characters.defineField(FIELD_NOTES_PUBLISHED, {
        schema = { type = 'integer', min = 0 },
        default = 0,
        visibility = 'owner',
    })
    if not ok then return false, err end

    ok, err = core.rpc.register(RPC_POST_NOTE, {
        args = {
            { type = 'string', min = 1, max = 32, pattern = '^[%w_]+$' },  -- type de note
            { type = 'string', min = 1, max = 500 },                       -- contenu
        },
        rateLimit = cfg.postRateLimit,
    }, postNote)
    if not ok then return false, err end

    RegisterCommand('example_ping', pingCommand, true)
    purge()
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(RESOURCE, 'version', 0),
    coreVersion = cfg.coreVersion,
    dependencies = {},
    setup = setup,
})
if not registered then
    log.error('déclaration refusée : %s', tostring(registerErr))
end
