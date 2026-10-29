--[[
    vava_example/server/main.lua
    Rôle : démonstration côté serveur d'un module vAvA :
      - migrations : sql/0001 (table), sql/0002 (colonne character_id), appliquées par le core avant setup()
      - registre   : vava_example:noteTypes (types de notes, extensible par d'autres modules)
      - hooks      : vava_example:notePost (before = filtre annulable, after = journal),
                     écoute de core:module:ready et core:character:created
      - RPC        : vava_example:postNote (client → serveur), vava_example:ping (serveur → client)
      - champ      : vava_example:notesPublished (compteur par personnage, visible par son seul joueur)
    Dépendances : vAvA_core (API v1, core ≥ 0.2.0), config.lua
]]

local RESOURCE = GetCurrentResourceName()
local cfg = VavaExample.config

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

local log = core.log
local ipairs, pairs, tonumber, tostring = ipairs, pairs, tonumber, tostring
local find, lower = string.find, string.lower
local tointeger = math.tointeger

local REGISTRY_NOTE_TYPES = RESOURCE .. ':noteTypes'
local HOOK_NOTE_POST = RESOURCE .. ':notePost'
local RPC_POST_NOTE = RESOURCE .. ':postNote'
local RPC_PING = RESOURCE .. ':ping'
local FIELD_NOTES_PUBLISHED = RESOURCE .. ':notesPublished'

local INSERT_NOTE_SQL = 'INSERT INTO `vava_example_notes` (`note_type`, `author`, `character_id`, `content`) VALUES (?, ?, ?, ?)'

---@param content string
---@return boolean
local function containsForbiddenWord(content)
    local text = lower(content)
    for _, word in ipairs(cfg.forbiddenWords) do
        if find(text, word, 1, true) then return true end
    end
    return false
end

--- Handler RPC : les arguments sont déjà validés par le core (types, longueurs, motif). Reste la logique métier.
--- Renvoie (true, noteId) ou (false, raison) ; le client reçoit ces valeurs après le "ok" de transport.
---@param source integer
---@param noteType string
---@param content string
local function postNote(source, noteType, content)
    -- lecture en mémoire dans le core, aucune requête base
    local noteDef = core.registry.get(REGISTRY_NOTE_TYPES, noteType)
    if not noteDef then return false, 'unknown_type' end
    if #content > noteDef.maxLength then return false, 'too_long' end

    -- une note est signée par un personnage, jamais par un compte : sans personnage actif, pas de note
    local character = core.characters.getActive(source)
    if not character then return false, 'no_character' end
    local author = character.firstName .. ' ' .. character.lastName

    local payload = { source = source, characterId = character.id, author = author, noteType = noteType, content = content }
    local allowed, reason = core.hooks.runBefore(HOOK_NOTE_POST, payload)
    if not allowed then return false, reason end

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

--- Appelé par le core une fois les dépendances prêtes et la migration appliquée.
--- Renvoyer false[, raison] fait échouer le module : le core purge alors tout ce qu'il a enregistré.
local function setup()
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
