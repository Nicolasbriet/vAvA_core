--[[
    vava_magic/bridge/server.lua
    Rôle : SEUL point de contact, côté serveur, entre la magie et le core / les autres modules : personnage, droits du
           Conseil, notifications, objets de l'inventaire, sauvegarde de la fiche, base de données, santé (chaîne de
           dégâts de vava_health : coups des sorts, vie tenue par le serveur, hook des coups, modificateurs), mains vides
           pour incanter (arme de GTA sur le ped, arme et bouclier au bras lus par vava_combat, prises en main suivies
           par le hook vava_inventory:hold).
           Pour brancher la magie sur un autre core, réécrire les fonctions de ce fichier (et de bridge/client.lua) :
           le reste du module ne connaît qu'elles.
    Implémentation : vAvA_core (API documentée dans docs/api.md) et ses modules officiels. Chaque appel à une autre
           ressource est isolé : un module absent ou en erreur ne retire que la fonction concernée.
    Dépendances : shared/constants.lua, config.lua, server/core.lua
]]

local type, pairs, ipairs, pcall, tostring, tonumber = type, pairs, ipairs, pcall, tostring, tonumber
local mathType, huge = math.type, math.huge
local pack, unpack, concat = table.pack, table.unpack, table.concat
local GetResourceState, TriggerClientEvent, IsPlayerAceAllowed, CreateThread, GetPlayers, GetGameTimer =
    GetResourceState, TriggerClientEvent, IsPlayerAceAllowed, CreateThread, GetPlayers, GetGameTimer
local GetPlayerPed, GetSelectedPedWeapon = GetPlayerPed, GetSelectedPedWeapon

local core = VavaMagic.core
if not core then return end

local cfg = VavaMagic.config
local LINKS = VavaMagic.LINKS
local EVENTS = VavaMagic.EVENTS
local FIELD = VavaMagic.SHEET_FIELD
local CONSOLE = 0

local Bridge = {}
VavaMagic.bridge = Bridge

local function invoke(resource, fn, ...)
    local target = exports[resource]
    return target[fn](target, ...)
end

--- Export d'une autre ressource, isolé. Renvoie ok (appel réussi) puis ses valeurs.
---@return boolean called
local function call(resource, fn, ...)
    if GetResourceState(resource) ~= 'started' then return false end
    local results = pack(pcall(invoke, resource, fn, ...))
    if not results[1] then
        VavaMagic.log.warn('%s.%s en erreur : %s', resource, fn, tostring(results[2]))
        return false
    end
    return true, unpack(results, 2, results.n)
end

-- Personnage ----------------------------------------------------------------------------------------------------

--- Identifiant unique du personnage actif du joueur, ou nil (en sélection, pas de personnage).
---@param source integer
---@return integer|nil
function Bridge.GetCharacterId(source)
    local session = core.players.get(source)
    if not session or session.state ~= 'active' then return nil end
    return session.characterId
end

--- Nom du personnage actif (prénom nom), pour les commandes du Conseil.
---@param source integer
---@return string|nil
function Bridge.GetCharacterName(source)
    local character = core.characters.getActive(source)
    if not character then return nil end
    return character.firstName .. ' ' .. character.lastName
end

--- Joueurs dont le personnage est en jeu (sources).
---@return integer[]
function Bridge.ActivePlayers()
    local list = {}
    for _, id in ipairs(GetPlayers()) do
        local src = tonumber(id)
        if src and Bridge.GetCharacterId(src) then list[#list + 1] = src end
    end
    return list
end

-- Droits du Conseil --------------------------------------------------------------------------------------------

--- Commandes du Conseil permises ? La console du serveur l'est toujours ; sinon le droit vava_admin de la config,
--- ou la permission ACE `admin.ace` quand vava_admin n'est pas lancé.
---@param source integer
---@return boolean
function Bridge.IsAdmin(source)
    if source == CONSOLE then return true end
    if GetResourceState(LINKS.ADMIN) == 'started' then
        local called, allowed = call(LINKS.ADMIN, 'can', source, cfg.admin.permission)
        return called and allowed == true
    end
    return IsPlayerAceAllowed(source, cfg.admin.ace) == true
end

--- Rang d'un joueur au Conseil (`vava_admin` rankOf : 1 Gardien, 2 Sénéchal, 3 Souverain ; 0 sans rang ; la console
--- au-dessus de tous) ; nil si vava_admin n'est pas démarré (les rangs n'existent pas), false s'il tourne mais que
--- le rang est illisible (appel en erreur : l'appelant refuse).
---@param source integer
---@return integer|false|nil
function Bridge.RankLevel(source)
    if source == CONSOLE then return huge end
    if GetResourceState(LINKS.ADMIN) ~= 'started' then return nil end
    local called, rank = call(LINKS.ADMIN, 'rankOf', source)
    if not called then return false end
    return type(rank) == 'table' and mathType(rank.level) == 'integer' and rank.level or 0
end

--- Droit `staff` du Registre (Souverain), ou la console. Sans vava_admin : la console seule.
---@param source integer
---@return boolean
function Bridge.IsStaff(source)
    if source == CONSOLE then return true end
    local called, allowed = call(LINKS.ADMIN, 'isStaff', source)
    return called and allowed == true
end

--- Inscrit une action du Conseil au journal du Registre (sans lui : la console du serveur la garde).
---@param source integer
---@param label string   32 signes au plus
---@param details table  { clé = texte ou nombre }, 8 au plus
function Bridge.AdminLog(source, label, details)
    local called, ok, err = false, nil, nil
    if source ~= CONSOLE then called, ok, err = call(LINKS.ADMIN, 'log', source, label, details) end
    if not called or ok ~= true then
        local parts = {}
        for key, value in pairs(details) do parts[#parts + 1] = key .. '=' .. tostring(value) end
        VavaMagic.log.info('%s (par %d) : %s%s', label, source, concat(parts, ', '), called and (' — journal refusé : ' .. tostring(err)) or '')
    end
end

--- Vrai si le Conseil a immobilisé ce joueur (Registre, vava_admin ≥ 1.6.0) : la fin d'un gel ne le libère pas.
--- vava_admin absent ou en erreur : non.
---@param source integer
---@return boolean
function Bridge.IsHeldByCouncil(source)
    local called, frozen = call(LINKS.ADMIN, 'isFrozen', source)
    return called and frozen == true
end

--- Prévient `handler` après chaque action du Conseil (hook `vava_admin:action` : { actor, action, target?, details }),
--- pour garder figé celui que la magie gèle quand « Libérer » du Registre relâche son ped.
---@param handler fun(payload: table)
---@return boolean ok
---@return string|nil err
function Bridge.OnCouncilAction(handler)
    local id, err = core.hooks.after(LINKS.ADMIN .. ':action', handler)
    if not id then return false, err end
    return true
end

-- Notifications ---------------------------------------------------------------------------------------------------

--- Message à un joueur ; nature : info (défaut), success, warning, danger.
---@param source integer
---@param message string
---@param kind? string
function Bridge.Notify(source, message, kind)
    if source == CONSOLE then
        print(('[%s] %s'):format(VavaMagic.resource, message))
        return
    end
    TriggerClientEvent(EVENTS.NOTIFY, source, message, kind or 'info')
end

-- Objets (vava_inventory) ------------------------------------------------------------------------------------------

---@param source integer
---@param item string
---@return boolean
function Bridge.HasItem(source, item)
    local called, count = call(LINKS.INVENTORY, 'count', source, item)
    return called and mathType(count) == 'integer' and count >= 1
end

---@param source integer
---@param item string
---@param count integer
---@param metadata? table
---@return boolean ok
---@return string|nil code
function Bridge.AddItem(source, item, count, metadata)
    local called, ok, code = call(LINKS.INVENTORY, 'add', source, item, count, metadata)
    if not called then return false, 'inventory_unavailable' end
    return ok == true, code
end

---@param source integer
---@param item string
---@param count integer
---@return boolean ok
---@return string|nil code
function Bridge.RemoveItem(source, item, count)
    local called, ok, code = call(LINKS.INVENTORY, 'remove', source, item, count)
    if not called then return false, 'inventory_unavailable' end
    return ok == true, code
end

--- Exemplaires d'un objet portés par le joueur, avec leurs métadonnées : { { instanceId, metadata } }.
---@param source integer
---@param item string
---@return table[]
function Bridge.GetItemMetadata(source, item)
    local list = {}
    local called, items = call(LINKS.INVENTORY, 'getItems', source)
    if not called or type(items) ~= 'table' then return list end
    for _, entry in ipairs(items) do
        if entry.item == item then
            list[#list + 1] = { instanceId = entry.id, metadata = type(entry.metadata) == 'table' and entry.metadata or {} }
        end
    end
    return list
end

--- Remplace les métadonnées d'un exemplaire porté par le joueur (vava_inventory 1.3.0).
---@param source integer
---@param instanceId integer
---@param metadata table
---@return boolean
function Bridge.SetItemMetadata(source, instanceId, metadata)
    local called, ok = call(LINKS.INVENTORY, 'setMetadata', source, instanceId, metadata)
    return called and ok == true
end

-- objets utilisables du module : (re)déclarés quand l'inventaire est prêt
local usable = {}

local function declare(name)
    local entry = usable[name]
    local registry = core.registry
    if not registry.exists(LINKS.ITEMS_REGISTRY) or registry.has(LINKS.ITEMS_REGISTRY, name) then return end
    local definition = {}
    for key, value in pairs(entry.definition) do
        if key ~= 'name' then definition[key] = value end
    end
    -- l'objet n'est jamais consommé : la fonction du module travaille dans son propre thread
    definition.onUse = function(source, instance)
        CreateThread(function()
            entry.callback(source, { instanceId = instance.id, metadata = type(instance.metadata) == 'table' and instance.metadata or {} })
        end)
        return false
    end
    local ok, err = registry.add(LINKS.ITEMS_REGISTRY, name, definition)
    if not ok then VavaMagic.log.warn("objet '%s' non déclaré : %s", name, tostring(err)) end
end

--- Objet utilisable : `callback(source, { instanceId, metadata })` à chaque usage (l'objet reste dans l'inventaire).
---@param item string
---@param definition table  champs d'un objet de vava_inventory (label, width, height, weight, stack, image…)
---@param callback fun(source: integer, instance: table)
function Bridge.RegisterUsableItem(item, definition, callback)
    usable[item] = { definition = definition, callback = callback }
    if VavaMagic.ready then declare(item) end
end

-- Fiche magie (persistance) -------------------------------------------------------------------------------------

--- Déclare le champ de personnage qui porte la fiche (privé : jamais envoyé au client).
---@param schema table
---@return boolean ok
---@return string|nil err
function Bridge.DefineSheet(schema)
    return core.characters.defineField(FIELD, { schema = schema, visibility = 'private' })
end

--- Fiche enregistrée du personnage, ou nil s'il n'en a jamais eu.
---@param characterId integer
---@return table|nil
function Bridge.LoadSheet(characterId)
    local value = core.characters.get(characterId, FIELD)
    return type(value) == 'table' and value or nil
end

--- Écrit la fiche dans le personnage : le core la sauvegarde en base avec le personnage (par lots, et au départ).
---@param characterId integer
---@param sheet table
---@return boolean ok
---@return string|nil err
function Bridge.SaveSheet(characterId, sheet)
    return core.characters.set(characterId, FIELD, sheet)
end

-- Base de données (tables du module, sql/) ---------------------------------------------------------------------

Bridge.db = {
    query = function(sql, params) return core.db.query(sql, params) end,
    single = function(sql, params) return core.db.single(sql, params) end,
    scalar = function(sql, params) return core.db.scalar(sql, params) end,
    insert = function(sql, params) return core.db.insert(sql, params) end,
    update = function(sql, params) return core.db.update(sql, params) end,
}

-- Santé et chaîne de dégâts (vava_health ≥ 1.3.0) -----------------------------------------------------------------

--- Coup porté par un sort : `exports.vava_health:hit(cible, paquet)` (paquet de shared/harm.lua). Rend le résultat de
--- la chaîne (`applied`, `absorbed`, `cancelled`…), ou nil et un code : celui de vava_health, ou `health_unavailable`
--- quand il est arrêté, en erreur ou sans chaîne (plus ancien que 1.3.0). Sans vava_health, aucun sort ne blesse
--- personne (plus aucun repli chez le client). Appel isolé et silencieux : combat.lua le signale, une fois par minute
--- (pas une ligne de console par coup).
---@param target integer
---@param packet table
---@return table|nil result
---@return string|nil code
function Bridge.Hit(target, packet)
    if GetResourceState(LINKS.HEALTH) ~= 'started' then return nil, 'health_unavailable' end
    local called, result, code = pcall(invoke, LINKS.HEALTH, 'hit', target, packet)
    if not called then return nil, 'health_unavailable' end
    if type(result) ~= 'table' then return nil, type(code) == 'string' and code or 'refused' end
    return result
end

-- ce que la magie sait de la chaîne (vava_health `vocabulary()`), relu à chaque démarrage de vava_health : points d'une
-- vie pleine, types de dégâts, étiquette `launched` connue (1.4.0), interrupteur des combats entre joueurs (1.4.0)
local chain = { points = nil, kinds = nil, launched = false, pvp = true }

--- Relit le vocabulaire de la chaîne (vava_health démarré, 1.3.0 au moins). Illisible (vava_health plus ancien ou en
--- erreur) : tout revient aux valeurs par défaut, rien de ce qu'une version précédente avait dit ne reste.
local function readVocabulary()
    local called, vocabulary = call(LINKS.HEALTH, 'vocabulary')
    if not called or type(vocabulary) ~= 'table' or type(vocabulary.healthPoints) ~= 'number' then
        chain.points, chain.kinds, chain.launched, chain.pvp = nil, nil, false, true
        return
    end
    chain.points = vocabulary.healthPoints
    chain.kinds = type(vocabulary.kinds) == 'table' and vocabulary.kinds or nil
    chain.launched = false
    for _, tag in ipairs(type(vocabulary.tags) == 'table' and vocabulary.tags or {}) do
        if tag == 'launched' then chain.launched = true end
    end
    -- absent (1.3.0) : la chaîne ne dit rien, seul `combat.pvp` de la magie compte
    chain.pvp = vocabulary.pvp ~= false
end

--- Vie du joueur tenue par le serveur de vava_health (0 à 1, 0 à terre), ou nil (vava_health absent ou sans chaîne,
--- personnage non suivi). Jamais lue sur le ped : un client qui garde sa vie GTA au maximum n'y gagne rien. Avant
--- 1.3.0, `get` lisait encore le ped : la vie n'est demandée que si la chaîne est connue.
---@param source integer
---@return number|nil
function Bridge.GetHealth(source)
    if not chain.points then return nil end
    local called, state = call(LINKS.HEALTH, 'get', source)
    if not called or type(state) ~= 'table' or type(state.health) ~= 'number' then return nil end
    return state.health
end

---@param source integer
---@return boolean
function Bridge.IsDowned(source)
    local called, downed = call(LINKS.HEALTH, 'isDowned', source)
    return called and downed == true
end

--- Prévient `handler` après chaque coup de la chaîne et chaque perte native (hook `vava_health:hit` after :
--- { target, applied, … }). Le hook appartient au core : l'abonnement survit aux redémarrages de vava_health.
---@param handler fun(payload: table)
---@return boolean ok
---@return string|nil err
function Bridge.OnHit(handler)
    local id, err = core.hooks.after(LINKS.HEALTH_HIT, handler)
    if not id then return false, err end
    return true
end

-- modificateurs de la chaîne : clé → { stage, priority?, label, apply, kinds? (liste), exceptKinds? (ensemble) } ;
-- (re)déclarés quand vava_health démarre
local modifiers = {}

--- Types pour lesquels un modificateur est appelé (`kinds` du registre) : sa liste, réduite aux types de la chaîne,
--- ou tous les types de la chaîne sauf `exceptKinds`. Nil : tous (vocabulaire inconnu, ou aucune liste) ; liste vide :
--- jamais appelé (rien à déclarer).
---@param definition table
---@return string[]|nil
local function kindsOf(definition)
    local known = chain.kinds
    if not known then return definition.kinds end
    local allowed = {}
    if definition.kinds then
        for _, kind in ipairs(definition.kinds) do allowed[kind] = true end
    elseif definition.exceptKinds then
        for _, kind in ipairs(known) do allowed[kind] = not definition.exceptKinds[kind] end
    else
        return nil
    end
    local list = {}
    for _, kind in ipairs(known) do
        if allowed[kind] then list[#list + 1] = kind end
    end
    return list
end

local function declareModifiers()
    readVocabulary()
    local registry = core.registry
    if not registry.exists(LINKS.HEALTH_MODIFIERS) then return end
    for key, definition in pairs(modifiers) do
        if not registry.has(LINKS.HEALTH_MODIFIERS, key) then
            local kinds = kindsOf(definition)
            if kinds and #kinds == 0 then
                VavaMagic.log.warn("modificateur '%s' non déclaré : aucun type de la chaîne à couvrir", key)
            else
                -- entrée du registre : seulement les champs qu'il connaît
                local ok, err = registry.add(LINKS.HEALTH_MODIFIERS, key, {
                    stage = definition.stage, priority = definition.priority, label = definition.label,
                    kinds = kinds, apply = definition.apply,
                })
                if not ok then VavaMagic.log.warn("modificateur '%s' non déclaré : %s", key, tostring(err)) end
            end
        end
    end
end

--- Modificateurs de la chaîne de dégâts tenus par la magie (au plus un par étape ; clés `vava_magic:…`) : déclarés au
--- registre `vava_health:modifiers` s'il existe, puis à chaque démarrage de vava_health (le registre disparaît avec
--- lui), avec les types qu'ils couvrent (`kinds`, ou tous sauf `exceptKinds`) : la chaîne ne les appelle pas pour les
--- autres. Chaque `apply(ctx)` lit les données de la magie et rend un résultat, sans jamais céder la main.
---@param list table<string, table>
function Bridge.SetModifiers(list)
    modifiers = list
    if VavaMagic.ready then declareModifiers() end
end

--- Points d'une vie pleine pour la chaîne (vava_health `vocabulary().healthPoints`), nil s'ils ne sont pas connus.
---@return number|nil
function Bridge.ChainHealthPoints()
    return chain.points
end

--- Combats entre joueurs permis par la chaîne (`chain.pvp` de vava_health ≥ 1.4.0) ; vrai s'il ne le dit pas.
---@return boolean
function Bridge.ChainPvp()
    return chain.pvp
end

--- La chaîne connaît-elle les coups déjà lancés (étiquette `launched`, vava_health ≥ 1.4.0) ?
---@return boolean
function Bridge.ChainKnowsLaunched()
    return chain.launched
end

-- Mains vides pour incanter (vava_combat ≥ 1.0.0) --------------------------------------------------------------------

-- une ligne de console par minute au plus : vava_combat en erreur, ou démarré mais pas prêt depuis une minute (jamais
-- une par lancer)
local COMBAT_WARN_MS = 60000
local NOT_READY_WARN_MS = 60000
-- WEAPON_UNARMED (joaat), comparé sur 32 bits : le hash lu peut revenir signé ou non
local UNARMED_HASH = 0xA2719263
local HASH_MASK = 0xFFFFFFFF
local combatWarnedAt = nil
local notReadySince = nil

--- Ligne de console sur vava_combat, une par minute au plus.
local function warnCombat(fmt, ...)
    local now = GetGameTimer()
    if combatWarnedAt and now - combatWarnedAt < COMBAT_WARN_MS then return end
    combatWarnedAt = now
    VavaMagic.log.warn(fmt, ...)
end

--- Export de vava_combat, isolé et silencieux : ok (appel réussi), puis ses valeurs. Démarré mais en erreur : une ligne
--- de console par minute au plus.
---@return boolean called
local function combat(fn, source)
    if GetResourceState(LINKS.COMBAT) ~= 'started' then return false end
    local called, result, code = pcall(invoke, LINKS.COMBAT, fn, source)
    if called then return true, result, code end
    warnCombat('%s.%s en erreur, mains vides non vérifiées : %s', LINKS.COMBAT, fn, tostring(result))
    return false
end

--- vava_combat démarré mais pas prêt : aucune restriction ; si cela dure plus d'une minute, une ligne de console par
--- minute au plus. Toute autre réponse remet le compte à zéro.
---@param code any  code rendu par `armed`
local function watchReady(code)
    if code ~= 'not_ready' then
        notReadySince = nil
        return
    end
    local now = GetGameTimer()
    if not notReadySince then
        notReadySince = now
    elseif now - notReadySince >= NOT_READY_WARN_MS then
        warnCombat('%s démarré mais pas prêt depuis %d s : mains vides non vérifiées', LINKS.COMBAT,
            (now - notReadySince) // 1000)
    end
end

--- Arme de GTA sortie, lue sur le ped répliqué par OneSync (`GetSelectedPedWeapon`) ? Ped absent ou arme illisible :
--- non, sans bruit.
---@param source integer
---@return boolean
local function nativeWeapon(source)
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 then return false end
    local hash = GetSelectedPedWeapon(ped)
    if mathType(hash) ~= 'integer' or hash == 0 then return false end
    return hash & HASH_MASK ~= UNARMED_HASH
end

--- Ce qui empêche d'incanter dans les mains du joueur : `armed` (arme de GTA sortie, ou arme tenue d'après
--- `vava_combat:armed(source)`), `shielded` (bouclier accroché **au bras**, `shield(source).ready`), ou nil : mains
--- libres, bouclier dans le dos, outil en main, vava_combat absent, pas prêt ou en erreur (aucune restriction pour les
--- armes de l'inventaire).
---@param source integer
---@return string|nil code
function Bridge.HandsBusy(source)
    if nativeWeapon(source) then return 'armed' end
    local called, weapon, code = combat('armed', source)
    if not called then return nil end
    watchReady(weapon == nil and code or nil)
    if type(weapon) == 'table' then return 'armed' end
    local read, shield = combat('shield', source)
    if read and type(shield) == 'table' and shield.ready == true then return 'shielded' end
    return nil
end

--- Prévient `handler` après chaque prise en main ou dépôt (hook `vava_inventory:hold` after : { source, instanceId,
--- item, previous, owner }) : une arme ou un bouclier pris pendant une incantation la brise aussitôt. Le hook
--- appartient au core : l'abonnement survit aux redémarrages de l'inventaire.
---@param handler fun(payload: table)
---@return boolean ok
---@return string|nil err
function Bridge.OnHold(handler)
    local id, err = core.hooks.after(LINKS.INVENTORY_HOLD, handler)
    if not id then return false, err end
    return true
end

--- Déclare les objets et les modificateurs, et suit les redémarrages de l'inventaire et de vava_health. Appelé
--- pendant le setup du module.
---@return boolean ok
---@return string|nil err
function Bridge.start()
    for name in pairs(usable) do declare(name) end
    declareModifiers()
    local id, err = core.hooks.after('core:module:ready', function(payload)
        if payload.name == LINKS.INVENTORY then
            for name in pairs(usable) do declare(name) end
        elseif payload.name == LINKS.HEALTH then
            declareModifiers()
        end
    end)
    if not id then return false, err end
    return true
end
