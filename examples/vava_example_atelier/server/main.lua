--[[
    vava_example_atelier/server/main.lua
    Rôle : exemple de développement de l'Atelier : deux éditeurs déclarés SANS une ligne d'interface ni de client.
             - vava_example_atelier:panneaux (monde, droit metiers) : types `panneau` (mise en page « page », les huit
               widgets, lieu orienté) et `affiche` (volet, féminin, enfant d'un panneau : publication groupée) ;
               règles propres (shared/rules.lua) ;
             - vava_example_atelier:proclamations (société, droit staff, sans essai) : sert au test des droits.
           T-101 : les deux ateliers sont gardés (`apply`, `remove`, et pour les panneaux `trial`, `endTrial`, `diff`,
           `format = 1`). Les fiches vivent en mémoire (shared/store.lua) : la config au démarrage, puis l'Atelier les
           synchronise sur la base (la base fait foi). Diffusion aux seuls joueurs concernés : chaque panneau qui a un
           lieu a sa zone du core (`panneau:<id>`, état public : titre, texte, langue) ; une publication l'annonce au
           chat de ses seuls abonnés ; un essai n'est montré qu'à son auteur. /atelier_exemple journal (Conseil) écrit
           au journal ; /atelier_exemple lire (tous, 2 s entre deux) dit les panneaux à portée, vus par le serveur.
           Garde : sans `set vava_env dev`, le setup refuse ; relue à chaque redéclaration, `apply` et commande.
    Dépendances : vAvA_core ≥ 0.11.0 (API v1, core.zones, core.net), config.lua, shared/guard.lua, shared/rules.lua,
                  shared/forms.lua, shared/store.lua ; vava_atelier ≥ 1.1.0 (registre, export journal ; redéclaration au
                  hook vava_atelier:editorsReady)
]]

local RESOURCE = GetCurrentResourceName()
local cfg = VavaExampleAtelier.config
local guard, rules, forms, Store = VavaExampleAtelier.guard, VavaExampleAtelier.rules, VavaExampleAtelier.forms,
    VavaExampleAtelier.store

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

local log = core.log
local type, ipairs, pairs, pcall, tostring = type, ipairs, pairs, pcall, tostring
local concat = table.concat
local GetConvar, GetResourceState, RegisterCommand, TriggerClientEvent, GetGameTimer =
    GetConvar, GetResourceState, RegisterCommand, TriggerClientEvent, GetGameTimer
local GetPlayerPed, GetEntityCoords, DoesEntityExist, AddEventHandler =
    GetPlayerPed, GetEntityCoords, DoesEntityExist, AddEventHandler

local ATELIER = 'vava_atelier'
local REGISTRY = 'vava_atelier:editors'
local COMMANDS = 'core:commands'
local READY_HOOK = 'vava_atelier:editorsReady'
local PANNEAUX = RESOURCE .. ':panneaux'
local PROCLAMATIONS = RESOURCE .. ':proclamations'
-- résumé d'une ligne du journal (bornes de l'export journal)
local MAX_SUMMARY = 160
local CHAT_EVENT = 'chat:addMessage'
local ZONE_PREFIX = 'panneau:'
local announce = cfg.announce

-- Fiches en mémoire, tirées de la config ; l'Atelier les met ensuite à l'état de la base.
local boards = Store.new({ panneau = cfg.boards, affiche = cfg.posters })
local decrees = Store.new({ proclamation = cfg.proclamations })
local stores = { panneau = boards, affiche = boards, proclamation = decrees }
-- l'original : la config telle quelle, jamais touchée par l'Atelier (retour à l'original, /atelier_archives)
local originalBoards = Store.new({ panneau = cfg.boards, affiche = cfg.posters })
local originals = { panneau = originalBoards, affiche = originalBoards,
    proclamation = Store.new({ proclamation = cfg.proclamations }) }
-- essais en cours, par joueur : { [type] = { [id] = data } }
local trials = {}

local function isDev()
    return guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK))
end

local function chat(target, message)
    TriggerClientEvent(CHAT_EVENT, target, { args = { announce.author, message } })
end

-- Zones du core et annonces ---------------------------------------------------------------------------------------

-- zones déclarées : id du panneau → aire
local zones = {}

local function areaOf(data, where)
    return { x = where.x, y = where.y, radius = data.portee or 3, margin = cfg.zone.margin }
end

local function sameArea(a, b)
    return a.x == b.x and a.y == b.y and a.radius == b.radius and a.margin == b.margin
end

--- Joueurs qui suivent la zone d'un panneau ; à sa création, ceux qui sont à portée (calcul du serveur).
local function audience(id, area)
    local list = core.zones.subscribers(ZONE_PREFIX .. id)
    if type(list) == 'table' and #list > 0 then return list end
    if not area then return {} end
    local near = core.net.playersNear({ x = area.x, y = area.y, z = 0.0 }, area.radius + area.margin)
    return type(near) == 'table' and near or {}
end

--- Un panneau publié : sa zone du core créée, déplacée ou remplacée ; annonce à ses seuls abonnés.
local function showBoard(id, data, where, reason)
    if type(where) ~= 'table' then return end
    local area = areaOf(data, where)
    local state = { t = data.titre, x = data.texte or '', l = data.langue }
    local key = ZONE_PREFIX .. id
    local known = zones[id]
    if not known then
        local ok, code = core.zones.define(key, area, state)
        if not ok then log.warn('zone %s : %s', key, tostring(code)) end
    else
        if not sameArea(known, area) then core.zones.move(key, area) end
        core.zones.replace(key, state)
    end
    zones[id] = area
    if reason ~= 'sync' then
        for _, player in ipairs(audience(id, area)) do
            chat(player, announce.published:format(data.titre, data.texte or ''))
        end
    end
end

--- Un panneau retiré : annonce à ses abonnés, puis sa zone retirée.
local function hideBoard(id, title, reason)
    if not zones[id] then return end
    if reason ~= 'sync' then
        for _, player in ipairs(audience(id, nil)) do chat(player, announce.removed:format(title or id)) end
    end
    core.zones.remove(ZONE_PREFIX .. id)
    zones[id] = nil
end


-- Fonctions lues par l'Atelier ----------------------------------------------------------------------------------------

--- `ctx.original` : l'Atelier demande l'original de la config (retour à l'original), pas ce qui est en vigueur.
local function storeFor(kind, ctx)
    if type(ctx) == 'table' and ctx.original == true then return originals[kind] end
    return stores[kind]
end

local function index(kind, ctx)
    local store = storeFor(kind, ctx)
    return store and store:index(kind) or {}
end

local function read(kind, id, ctx)
    local store = storeFor(kind, ctx)
    return store and store:read(kind, id) or nil
end

local function validateBoards(kind, data, ctx)
    if kind ~= 'panneau' or (ctx and ctx.action == 'remove') then return true end
    local others = {}
    for i, entry in ipairs(boards:index('panneau')) do others[i] = { id = entry.id, titre = entry.title } end
    local errors = rules.board(data, others, ctx and ctx.id)
    if #errors == 0 then return true end
    return false, errors
end

local function options(source)
    if source == 'quartiers' then return cfg.districts end
    return {}
end

local function compare(kind, data)
    if kind ~= 'panneau' then return nil end
    local list, selfId = {}, nil
    for i, entry in ipairs(boards:all('panneau')) do
        local copy = { id = entry.id }
        for key, value in pairs(entry.data) do copy[key] = value end
        list[i] = copy
        if rules.key(copy.titre) == rules.key(data.titre) then selfId = entry.id end
    end
    return rules.compare(data, list, selfId)
end

local function noRules()
    return true
end

--- Refus demandé (mode développement) : `set vava_example_refuse 1`.
local function refusing()
    return isDev() and GetConvar(cfg.refuseConvar, '0') == '1'
end

--- `apply` : crée ou remplace la fiche (tout ou rien) ; un panneau à lieu met sa zone à jour et l'annonce.
local function apply(kind, def, info)
    local store = stores[kind]
    if not store or type(def) ~= 'table' then return false, 'Genre de fiche inconnu.' end
    if refusing() then return false, announce.refused end
    store:apply(kind, def)
    if kind == 'panneau' then
        local entry = store:get(kind, def.id)
        showBoard(def.id, entry.data, entry.place, info and info.reason)
    end
    return true
end

--- `remove` : retire la fiche (aucun objet de joueur ici) ; un panneau retire sa zone après l'annonce.
local function remove(kind, id, info)
    local store = stores[kind]
    if not store then return false, 'Genre de fiche inconnu.' end
    local entry = store:get(kind, id)
    if kind == 'panneau' and entry then hideBoard(id, entry.data.titre, info and info.reason) end
    store:remove(kind, id)
    return true
end

--- `trial` : montre la fiche à son seul auteur (chat), enfants compris ; rien d'autre ne change en jeu.
local function trial(kind, def, ctx)
    local source = ctx and ctx.source
    if not source then return false, 'Auteur absent.' end
    local mine = { [kind] = { [def.id] = def } }
    local function show(k, d)
        if k == 'panneau' then chat(source, announce.trial:format(d.titre, d.texte or ''))
        else chat(source, announce.trialPoster:format(d.titre)) end
    end
    show(kind, def)
    for _, child in ipairs(ctx.children or {}) do
        mine[child.kind] = mine[child.kind] or {}
        mine[child.kind][child.def.id] = child.def
        show(child.kind, child.def)
    end
    trials[source] = mine
    return true
end

--- `endTrial` : l'auteur, s'il est là, est prévenu ; la version d'essai est oubliée.
local function endTrial(kind, id, ctx)
    local source = ctx and ctx.source
    for player, mine in pairs(trials) do
        if mine[kind] and mine[kind][id] then
            local title = mine[kind][id].titre or id
            trials[player] = nil
            if source then chat(source, announce.trialEnded:format(title)) end
        end
    end
    return true
end

local function diff(kind, before, after)
    return Store.diff(kind, before, after)
end

-- Déclarations ------------------------------------------------------------------------------------------------------

local EDITORS = {
    [PANNEAUX] = {
        family = 'monde', right = 'metiers', icon = 'parchemin', order = 900, format = 1,
        label = 'Panneaux du bourg (exemple)',
        description = 'Exemple de développement : tous les réglages qu\'un atelier peut montrer.',
        texts = { trial = 'Voir le panneau', publish = 'Dresser le panneau',
            publishHint = 'Dresser le panneau le rend lisible aux passants.' },
        kinds = {
            { id = 'panneau', noun = 'panneau', nounPlural = 'panneaux', article = 'le', newLabel = 'Nouveau panneau',
                layout = 'page', steps = { 'Le panneau', 'Son allure', 'Dresser' }, placement = 'oriented',
                form = forms.panneau },
            { id = 'affiche', noun = 'affiche', nounPlural = 'affiches', article = 'l\'', newLabel = 'Nouvelle affiche',
                layout = 'side', parent = 'panneau', feminine = true, form = forms.affiche },
        },
        index = index, read = read, validate = validateBoards, options = options, compare = compare,
        apply = apply, remove = remove, trial = trial, endTrial = endTrial, diff = diff,
    },
    [PROCLAMATIONS] = {
        family = 'societe', right = 'staff', icon = 'parchemin', order = 900,
        label = 'Proclamations (exemple)',
        description = 'Exemple de développement : un atelier réservé au Souverain.',
        texts = { trial = 'Lire la proclamation', publish = 'Proclamer' },
        kinds = {
            { id = 'proclamation', noun = 'proclamation', nounPlural = 'proclamations', article = 'la',
                newLabel = 'Nouvelle proclamation', layout = 'page', form = forms.proclamation },
        },
        index = index, read = read, validate = noRules, apply = apply, remove = remove,
    },
}

--- Déclare les deux éditeurs si le registre de l'Atelier existe (au setup, et à chaque démarrage de l'Atelier).
local function declare()
    -- mode développement relu à chaque appel : `set vava_env prod` puis `restart vava_atelier` ne redéclare rien
    if not isDev() then
        log.warn('mode développement absent : ateliers d\'exemple non déclarés')
        return
    end
    if not core.registry.exists(REGISTRY) then return end
    for key, def in pairs(EDITORS) do
        if not core.registry.has(REGISTRY, key) then
            local ok, err = core.registry.add(REGISTRY, key, def)
            if not ok then log.error("atelier '%s' refusé : %s", key, tostring(err)) end
        end
    end
end

-- Commande de démonstration ----------------------------------------------------------------------------------------

local TARGETS = {
    panneaux = { editor = PANNEAUX, kind = 'panneau', store = boards },
    proclamations = { editor = PROCLAMATIONS, kind = 'proclamation', store = decrees },
}
local USAGE = 'usage : /%s journal <panneaux|proclamations> <texte> | /%s lire'

local function reply(source, message)
    if source == 0 then
        print(('[%s] %s'):format(RESOURCE, message))
    else
        TriggerClientEvent(CHAT_EVENT, source, { args = { 'Atelier', message } })
    end
end

local function atelierCall(fn, ...)
    local target = exports[ATELIER]
    return target[fn](target, ...)
end

--- Coupe un texte à `max` octets sans briser un caractère UTF-8.
local function cut(text, max)
    if #text <= max then return text end
    local stop = max
    while stop > 0 and ((text:byte(stop + 1) or 0) & 0xC0) == 0x80 do stop = stop - 1 end
    return text:sub(1, stop)
end

--- /atelier_exemple journal <panneaux|proclamations> <texte> : une ligne `note` sur la première entrée de l'atelier.
local function journalCommand(source, args)
    local target = TARGETS[args[2] or '']
    local summary = cut(concat(args, ' ', 3), MAX_SUMMARY)
    local first = target and target.store:index(target.kind)[1]
    if not target or summary == '' or not first then
        reply(source, USAGE:format(cfg.command, cfg.command))
        return
    end
    if GetResourceState(ATELIER) ~= 'started' then
        reply(source, 'l\'Atelier n\'est pas démarré.')
        return
    end
    -- droit effectif de l'atelier (Conseil), revérifié par l'Atelier ; la console écrit au nom de « Console »
    if source ~= 0 then
        local called, allowed = pcall(atelierCall, 'can', source, target.editor)
        if not called or allowed ~= true then
            reply(source, 'refusé : cet atelier ne vous est pas ouvert.')
            return
        end
    end
    local called, ok, code = pcall(atelierCall, 'journal', source, {
        editor = target.editor, kind = target.kind, id = first.id, action = 'note', title = first.title,
        summary = summary,
    })
    if not called then
        reply(source, 'l\'Atelier ne répond pas.')
    elseif ok then
        reply(source, ('ligne écrite au journal : « %s »'):format(first.title))
    else
        reply(source, ('ligne refusée : %s'):format(tostring(code)))
    end
end

local lastRead = {}

--- /atelier_exemple lire : panneaux publiés à portée (position lue par le serveur), et la version d'essai de l'auteur.
local function readCommand(source)
    if source == 0 then return reply(source, 'commande de joueur.') end
    local now = GetGameTimer()
    if lastRead[source] and now - lastRead[source] < cfg.readCooldownMs then return reply(source, announce.cooldown) end
    lastRead[source] = now
    local ped = GetPlayerPed(source)
    if not ped or ped == 0 or not DoesEntityExist(ped) then return reply(source, announce.readNone) end
    local coords = GetEntityCoords(ped)
    local limit = cfg.zone.readRadius
    local lines = {}
    for _, entry in ipairs(boards:all('panneau')) do
        local where = entry.place
        if type(where) == 'table' then
            local dx, dy, dz = coords.x - where.x, coords.y - where.y, coords.z - where.z
            if dx * dx + dy * dy + dz * dz <= limit * limit then
                lines[#lines + 1] = announce.read:format(entry.data.titre, entry.data.texte or '')
                local mine = trials[source] and trials[source].panneau and trials[source].panneau[entry.id]
                if mine then lines[#lines + 1] = announce.readTrial:format(mine.titre, mine.texte or '') end
            end
        end
    end
    if #lines == 0 then return reply(source, announce.readNone) end
    for _, line in ipairs(lines) do chat(source, line) end
end

local function command(source, args)
    -- mode développement relu à chaque appel : `set vava_env prod` ferme aussitôt la commande
    if not isDev() then
        reply(source, 'outil inactif sur ce serveur (mode développement absent).')
        return
    end
    if args[1] == 'journal' then return journalCommand(source, args) end
    if args[1] == 'lire' then return readCommand(source) end
    reply(source, USAGE:format(cfg.command, cfg.command))
end

local function declareCommand()
    if not core.registry.exists(COMMANDS) then return true end
    return core.registry.add(COMMANDS, cfg.command, {
        kind = 'command', scope = 'player', module = RESOURCE, chapter = 'Tests',
        label = 'Exemple de l\'Atelier',
        description = 'Annoter le journal du Conseil (Conseil) ; lire les panneaux à portée (tous).',
        actions = {
            { id = 'journal', label = 'Annoter le journal de l\'Atelier (exemple)', permission = cfg.commandRight,
                args = {
                    { name = 'atelier', type = 'choice', choices = { 'panneaux', 'proclamations' } },
                    { name = 'texte', type = 'text', rest = true },
                } },
            { id = 'lire', label = 'Lire les panneaux à portée (exemple)' },
        },
    })
end

AddEventHandler('playerDropped', function()
    local source = source
    trials[source], lastRead[source] = nil, nil
end)

local function setup()
    if not isDev() then return false, guard.REFUSAL end
    local id, err = core.hooks.after(READY_HOOK, declare)
    if not id then return false, READY_HOOK .. ' : ' .. tostring(err) end
    local ok
    ok, err = declareCommand()
    if not ok then return false, 'commande : ' .. tostring(err) end
    RegisterCommand(cfg.command, command, false)
    -- zones des panneaux de la config ; l'Atelier les mettra à l'état de la base à sa synchronisation
    for _, entry in ipairs(boards:all('panneau')) do showBoard(entry.id, entry.data, entry.place, 'sync') end
    declare()
    log.warn('mode développement : ateliers d\'exemple déclarés et /%s ouverte — '
        .. 'jamais sur un serveur ouvert au public', cfg.command)
    return true
end

local registered, registerErr = core.modules.register({
    version = GetResourceMetadata(RESOURCE, 'version', 0),
    coreVersion = cfg.coreVersion,
    setup = setup,
})
if not registered then
    log.error('déclaration refusée : %s', tostring(registerErr))
end
