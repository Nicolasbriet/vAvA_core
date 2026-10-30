--[[
    vava_example_atelier/server/main.lua
    Rôle : exemple de développement de l'Atelier (T-100) : deux éditeurs déclarés SANS une ligne d'interface, la preuve
           que le formulaire générique suffit.
             - vava_example_atelier:panneaux (monde, droit metiers) : types `panneau` (mise en page « page », les huit
               widgets) et `affiche` (mise en page « volet ») ; règles propres (shared/rules.lua) ;
             - vava_example_atelier:proclamations (société, droit staff) : sert au test des droits.
           Données en mémoire, tirées de la config ; rien n'est écrit en base. Fonctions lues par l'Atelier : index,
           read, validate, options, compare. Commande /atelier_exemple journal <panneaux|proclamations> <texte> : une
           ligne `note` au journal du Conseil par l'export `journal` (droit effectif de l'atelier, revérifié par
           l'Atelier). Garde : sans `set vava_env dev`, le setup refuse (aucun éditeur, aucune commande) ; relue
           à chaque redéclaration et à chaque commande.
    Dépendances : vAvA_core ≥ 0.11.0 (API v1), config.lua, shared/guard.lua, shared/rules.lua, shared/forms.lua ;
                  vava_atelier (registre et export journal ; redéclaration au hook vava_atelier:editorsReady)
]]

local RESOURCE = GetCurrentResourceName()
local cfg = VavaExampleAtelier.config
local guard, rules, forms = VavaExampleAtelier.guard, VavaExampleAtelier.rules, VavaExampleAtelier.forms

local core, apiErr = exports.vAvA_core:getApi(1)
if not core then
    print(('^1[%s] API vAvA indisponible : %s^7'):format(RESOURCE, tostring(apiErr)))
    return
end

local log = core.log
local type, ipairs, pairs, pcall, tostring = type, ipairs, pairs, pcall, tostring
local concat = table.concat
local GetConvar, GetResourceState, RegisterCommand, TriggerClientEvent =
    GetConvar, GetResourceState, RegisterCommand, TriggerClientEvent

local ATELIER = 'vava_atelier'
local REGISTRY = 'vava_atelier:editors'
local COMMANDS = 'core:commands'
local READY_HOOK = 'vava_atelier:editorsReady'
local PANNEAUX = RESOURCE .. ':panneaux'
local PROCLAMATIONS = RESOURCE .. ':proclamations'
-- résumé d'une ligne du journal (bornes de l'export journal)
local MAX_SUMMARY = 160
local CHAT_EVENT = 'chat:addMessage'

-- Données en mémoire : type → liste ordonnée d'entrées (copies de la config).
local store = { panneau = {}, affiche = {}, proclamation = {} }
for kind, list in pairs({ panneau = cfg.boards, affiche = cfg.posters, proclamation = cfg.proclamations }) do
    for i, entry in ipairs(list) do
        local copy = {}
        for key, value in pairs(entry) do copy[key] = value end
        store[kind][i] = copy
    end
end

--- Entrée d'un type, ou nil.
local function find(kind, id)
    for _, entry in ipairs(store[kind] or {}) do
        if entry.id == id then return entry end
    end
    return nil
end

--- `data` d'une entrée : ses seuls champs de formulaire (sans `id`, clé réservée).
local function dataOf(entry)
    local data = {}
    for key, value in pairs(entry) do
        if key ~= 'id' then data[key] = value end
    end
    return data
end

-- Fonctions lues par l'Atelier ----------------------------------------------------------------------------------------

local function index(kind)
    local out = {}
    for i, entry in ipairs(store[kind] or {}) do out[i] = { id = entry.id, title = entry.titre } end
    return out
end

local function read(kind, id)
    local entry = find(kind, id)
    if not entry then return nil end
    return dataOf(entry)
end

local function validateBoards(kind, data, ctx)
    if kind ~= 'panneau' then return true end
    local others = {}
    for i, entry in ipairs(store.panneau) do others[i] = { id = entry.id, titre = entry.titre } end
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
    -- l'entrée affichée est celle dont le nom est celui de la fiche, si elle existe
    local selfId
    for _, entry in ipairs(store.panneau) do
        if rules.key(entry.titre) == rules.key(data.titre) then selfId = entry.id end
    end
    return rules.compare(data, store.panneau, selfId)
end

local function noRules()
    return true
end

-- Déclarations ------------------------------------------------------------------------------------------------------

local EDITORS = {
    [PANNEAUX] = {
        family = 'monde', right = 'metiers', icon = 'parchemin', order = 900,
        label = 'Panneaux du bourg (exemple)',
        description = 'Exemple de développement : tous les réglages qu\'un atelier peut montrer.',
        texts = { trial = 'Voir le panneau', publish = 'Dresser le panneau',
            publishHint = 'Dresser le panneau le rend lisible aux passants.' },
        kinds = {
            { id = 'panneau', noun = 'panneau', nounPlural = 'panneaux', article = 'le', newLabel = 'Nouveau panneau',
                layout = 'page', steps = { 'Le panneau', 'Son allure', 'Dresser' }, form = forms.panneau },
            { id = 'affiche', noun = 'affiche', nounPlural = 'affiches', article = 'l\'', newLabel = 'Nouvelle affiche',
                layout = 'side', parent = 'panneau', placement = 'point', form = forms.affiche },
        },
        index = index, read = read, validate = validateBoards, options = options, compare = compare,
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
        index = index, read = read, validate = noRules,
    },
}

--- Déclare les deux éditeurs si le registre de l'Atelier existe (au setup, et à chaque démarrage de l'Atelier).
local function declare()
    -- mode développement relu à chaque appel : `set vava_env prod` puis `restart vava_atelier` ne redéclare rien
    if not guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK)) then
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

-- Commande de démonstration du journal ---------------------------------------------------------------------------

local TARGETS = {
    panneaux = { editor = PANNEAUX, kind = 'panneau' },
    proclamations = { editor = PROCLAMATIONS, kind = 'proclamation' },
}

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
    -- mode développement relu à chaque appel : `set vava_env prod` ferme aussitôt la commande
    if not guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK)) then
        reply(source, 'outil inactif sur ce serveur (mode développement absent).')
        return
    end
    local target = TARGETS[args[2] or '']
    if args[1] ~= 'journal' or not target then
        reply(source, ('usage : /%s journal <panneaux|proclamations> <texte>'):format(cfg.command))
        return
    end
    local summary = cut(concat(args, ' ', 3), MAX_SUMMARY)
    local first = store[target.kind][1]
    if summary == '' or not first then
        reply(source, ('usage : /%s journal <panneaux|proclamations> <texte>'):format(cfg.command))
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
        editor = target.editor, kind = target.kind, id = first.id, action = 'note', title = first.titre,
        summary = summary,
    })
    if not called then
        reply(source, 'l\'Atelier ne répond pas.')
    elseif ok then
        reply(source, ('ligne écrite au journal : « %s »'):format(first.titre))
    else
        reply(source, ('ligne refusée : %s'):format(tostring(code)))
    end
end

local function declareCommand()
    if not core.registry.exists(COMMANDS) then return true end
    return core.registry.add(COMMANDS, cfg.command, {
        kind = 'command', scope = 'admin', permission = cfg.commandRight, module = RESOURCE, chapter = 'Tests',
        label = 'Annoter le journal de l\'Atelier (exemple)',
        description = 'Écrit une ligne au journal du Conseil sur le premier panneau ou la première proclamation.',
        args = {
            { name = 'action', type = 'choice', choices = { 'journal' } },
            { name = 'atelier', type = 'choice', choices = { 'panneaux', 'proclamations' } },
            { name = 'texte', type = 'text', rest = true },
        },
    })
end

local function setup()
    if not guard.isDevMode(GetConvar(guard.CONVAR, guard.FALLBACK)) then
        return false, guard.REFUSAL
    end
    local id, err = core.hooks.after(READY_HOOK, declare)
    if not id then return false, READY_HOOK .. ' : ' .. tostring(err) end
    local ok
    ok, err = declareCommand()
    if not ok then return false, 'commande : ' .. tostring(err) end
    RegisterCommand(cfg.command, journalCommand, false)
    declare()
    log.warn('mode développement : ateliers d\'exemple déclarés et /%s ouverte au Conseil — '
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
