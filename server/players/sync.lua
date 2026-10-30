--[[
    server/players/sync.lua
    Rôle : diffusion des données de personnage vers les clients, au plus juste.
      - owner  : envoyé au seul joueur concerné ; les modifications d'un même tick partent en un seul event.
      - public : statebag du joueur répliqué (visible par tous) ; à réserver à ce qui doit vraiment l'être.
                 Le client propriétaire peut réécrire son propre statebag : le serveur garde la valeur qu'il a publiée
                 et la remet quand une autre apparaît (garde). Lue sur un autre client, elle reste une déclaration.
      - private : jamais envoyé.
    Rien ne part pour un personnage qui n'est plus celui du joueur (déchargé, ou joueur parti dont le numéro a pu
    être redonné à un nouveau venu).
    Dépendances : shared/init.lua, shared/lib/table.lua, shared/core/logger.lua, config/server.lua,
                  server/players/fields.lua
]]

local pairs, tonumber, type = pairs, tonumber, type
local match = string.match
local TriggerClientEvent, SetTimeout, DoesPlayerExist, Player = TriggerClientEvent, SetTimeout, DoesPlayerExist, Player

local EVENTS = vAvA.EVENTS
local fields = vAvA.fields
local tbl = vAvA.lib.table
local logger = vAvA.logger
local cfg = vAvA.config.server.sync
local log = logger.create('sync')

local sync = {}
vAvA.sync = sync

-- source → { values = { champ → valeur }, cleared = { champ → true } }, vidé au tick suivant
local pending = {}
local flushScheduled = false
-- source → personnage dont le joueur reçoit les données (posé à l'envoi complet, retiré au déchargement ou au départ)
local owners = {}
-- source → { champ → valeur publiée par le serveur } ; NONE : champ public publié vide
local published = {}
local NONE = {}
-- source → { names = { champ → true } } : remises de la valeur serveur programmées (une minuterie par joueur)
local corrections = {}
-- source → état de limitation des avertissements (un par intervalle et par joueur)
local warnStates = {}
-- champ public → true : gestionnaire de changement branché (voir watch)
local watched = {}
-- AddStateBagChangeHandler, posé par start() s'il existe ; nil : garde inactive
local addStateBagHandler

local function flush()
    flushScheduled = false
    local batches = pending
    pending = {}
    for src, batch in pairs(batches) do
        local cleared = {}
        for name in pairs(batch.cleared) do cleared[#cleared + 1] = name end
        TriggerClientEvent(EVENTS.CHARACTER_FIELDS, src, batch.values, cleared)
    end
end

---@param src integer
---@param name string
---@param value any  nil : le champ n'a plus de valeur pour le client
local function queue(src, name, value)
    local batch = pending[src]
    if not batch then
        batch = { values = {}, cleared = {} }
        pending[src] = batch
    end
    if value == nil then
        batch.values[name], batch.cleared[name] = nil, true
    else
        batch.values[name], batch.cleared[name] = value, nil
    end
    if not flushScheduled then
        flushScheduled = true
        SetTimeout(0, flush)
    end
end

--- Valeur que le serveur a publiée pour ce champ public de ce joueur (nil : aucune, ou publiée vide).
---@param src integer
---@param name string
---@return any
local function expectedValue(src, name)
    local values = published[src]
    local value = values and values[name]
    if value == NONE then return nil end
    return value
end

--- Remet la valeur serveur des champs réécrits par le client, après le délai de regroupement.
---@param src integer
local function correct(src)
    local entry = corrections[src]
    corrections[src] = nil
    if not entry or not DoesPlayerExist(src) then return end
    local state = Player(src).state
    local restored
    for name in pairs(entry.names) do
        -- champ retiré entre-temps (module arrêté) : plus gardé
        if fields.isPublic(name) then
            local expected = expectedValue(src, name)
            if not tbl.deepEqual(state[name], expected, cfg.publicCompareDepth) then
                state:set(name, expected, true)
                restored = restored and (restored .. ', ' .. name) or name
            end
        end
    end
    if restored then
        local warnState = warnStates[src]
        if not warnState then
            warnState = {}
            warnStates[src] = warnState
        end
        local allowed, suppressed = logger.throttle(warnState)
        if allowed then
            log.warn('joueur %d : champ(s) public(s) réécrit(s) par son client, valeur du serveur remise (%s)%s',
                src, restored, logger.suppressedNote(suppressed))
        end
    end
end

--- Garde des champs publics : appelée à chaque changement, vu par le serveur, d'une clé de champ public sur un
--- statebag. Ne tranche pas sur l'origine (le serveur lui-même, ou le client du joueur) : toute valeur différente de
--- celle publiée est remise. La remise attend le délai de regroupement : pendant l'appel, la nouvelle valeur n'est
--- pas encore appliquée.
---@param bagName any
---@param key any
---@param value any
local function onStateBagChange(bagName, key, value)
    if not fields.isPublic(key) or type(bagName) ~= 'string' then return end
    local src = tonumber(match(bagName, '^player:(%d+)$'))
    if not src then return end
    if tbl.deepEqual(value, expectedValue(src, key), cfg.publicCompareDepth) then return end
    local entry = corrections[src]
    if entry then
        entry.names[key] = true
        return
    end
    corrections[src] = { names = { [key] = true } }
    SetTimeout(cfg.publicGuardDelayMs, function() correct(src) end)
end

--- Suivi d'une clé de champ public, branché à sa déclaration : le serveur n'est appelé que pour les clés
--- des champs publics, jamais pour les autres statebags (entités, GlobalState). Un gestionnaire par nom de champ,
--- gardé jusqu'à l'arrêt du core : un champ retiré puis redéclaré (module redémarré) n'en ajoute pas un second.
---@param name string
local function watch(name)
    if watched[name] or not addStateBagHandler then return end
    watched[name] = true
    addStateBagHandler(name, nil, onStateBagChange)
end

--- Publie un champ public : la valeur est retenue AVANT l'écriture, pour que la garde reconnaisse celle du serveur.
---@param state table  statebag du joueur
---@param src integer
---@param name string
---@param value any
local function publish(state, src, name, value)
    local values = published[src]
    if not values then
        values = {}
        published[src] = values
    end
    if value == nil then values[name] = NONE else values[name] = value end
    watch(name)
    state:set(name, value, true)
end

--- Envoie au joueur son personnage (identité + champs visibles) et publie les champs publics.
---@param character vAvA.Character
function sync.sendCharacter(character)
    local src = character.source
    pending[src] = nil
    owners[src] = character
    local visible = {}
    fields.forEachVisible(function(name)
        local value = fields.get(character, name)
        if value ~= nil then visible[name] = value end
    end)
    TriggerClientEvent(EVENTS.CHARACTER_LOADED, src, {
        id = character.id, firstName = character.firstName, lastName = character.lastName,
        sex = character.sex, fields = visible,
    })
    local state = Player(src).state
    fields.forEachPublic(function(name)
        publish(state, src, name, fields.get(character, name))
    end)
end

--- Diffuse un champ modifié selon sa visibilité. Rien ne part avant l'envoi complet (qui contient déjà la valeur)
--- ni après le déchargement ou le départ du joueur.
---@param character vAvA.Character
---@param def vAvA.FieldDefinition
function sync.fieldChanged(character, def)
    if def.visibility == 'private' then return end
    local src = character.source
    if owners[src] ~= character then return end
    local value = fields.get(character, def.name)
    queue(src, def.name, value)
    if def.visibility == 'public' then
        publish(Player(src).state, src, def.name, value)
    end
end

--- Retire les données d'un personnage déchargé : statebags publics vidés, client prévenu.
---@param character vAvA.Character
function sync.clearCharacter(character)
    local src = character.source
    -- joueur parti (purgé) : rien à vider ni à prévenir, et son numéro peut déjà être celui d'un autre
    if owners[src] ~= character then return end
    owners[src] = nil
    pending[src] = nil
    if not DoesPlayerExist(src) then
        -- session fermée sans playerDropped : aucune valeur retenue ne doit servir de référence à un futur venu
        published[src], corrections[src] = nil, nil
        return
    end
    local state = Player(src).state
    fields.forEachPublic(function(name)
        publish(state, src, name, nil)
    end)
    TriggerClientEvent(EVENTS.CHARACTER_UNLOADED, src, character.id)
end

--- Oublie un joueur parti. À appeler dès son départ, avant le déchargement de son personnage : plus rien ne lui est
--- envoyé, même si son numéro est redonné pendant la sauvegarde.
---@param src integer
function sync.purgePlayer(src)
    pending[src] = nil
    owners[src] = nil
    published[src] = nil
    corrections[src] = nil
    warnStates[src] = nil
end

--- Branche la garde des champs publics. Appelé par init.lua.
---@return boolean ok  false si le runtime n'offre pas de suivi des statebags côté serveur (garde inactive)
function sync.start()
    local native = AddStateBagChangeHandler
    if type(native) ~= 'function' then
        log.warn('AddStateBagChangeHandler indisponible : champs publics non gardés contre la réécriture du client')
        return false
    end
    addStateBagHandler = native
    fields.forEachPublic(watch)
    fields.setPublicListener(watch)
    return true
end
