--[[
    vava_codex/server/catalog.lua
    Rôle : lecture du registre `core:commands` pour un joueur : entrées qu'il a le droit de voir (public, droit du
           Conseil, console en lecture seule ; une sous-commande à droit propre n'est ouverte qu'avec ce droit),
           chapitres, commandes des ressources vAvA enregistrées auprès du jeu mais non décrites (Conseil), et valeurs
           proposées pour un argument (joueurs en jeu : tous pour le Conseil, les seuls proches sinon ; clés d'un
           registre, liste d'un module). Tout est recalculé à la demande : le registre vit en mémoire dans le core.
           L'ordre rendu est total (même contenu, même empreinte : shared/fingerprint.lua).
    Dépendances : shared/constants.lua, config.lua, server/core.lua, bridge/server.lua
]]

local pairs, ipairs, type, tostring = pairs, ipairs, type, tostring
local sort = table.sort
local find, lower = string.find, string.lower

local core = VavaCodex.core
local bridge = VavaCodex.bridge
local cfg = VavaCodex.config
local REGISTRY = VavaCodex.REGISTRY
local MAX_OPTIONS = VavaCodex.MAX_OPTIONS

local catalog = {}
VavaCodex.catalog = catalog

---@param args table[]|nil
---@return table[]|nil
local function wireArgs(args)
    if not args then return nil end
    local out = {}
    for i, arg in ipairs(args) do
        out[i] = {
            name = arg.name, type = arg.type, optional = arg.optional or nil, rest = arg.rest or nil,
            min = arg.min, max = arg.max, step = arg.step, choices = arg.choices, labels = arg.labels, hint = arg.hint,
            -- registry et list : les valeurs se demandent au serveur (RPC options) ; le client ne lit aucun registre
            dynamic = (arg.type == 'player' or arg.type == 'registry' or arg.type == 'list') or nil,
        }
    end
    return out
end

--- Sous-commande désignée d'une entrée ('' : forme nue), ou nil.
---@param def table
---@param actionId string
---@return table|nil
local function actionOf(def, actionId)
    for _, action in ipairs(def.actions or {}) do
        if (action.id or '') == actionId then return action end
    end
    return nil
end

--- Sous-commande ouverte au joueur : sans droit propre, ou avec ce droit (repli ACE de la commande sans vava_admin).
---@param src integer
---@param def table
---@param action table
---@return boolean
local function actionAllowed(src, def, action)
    return not action.permission or bridge.Can(src, action.permission, def.ace)
end

--- Représentation réseau d'une entrée pour un joueur : seules les sous-commandes qu'il peut lancer.
---@param name string
---@param def table
---@param src integer
---@return table|nil
local function wire(name, def, src)
    local actions
    if def.actions then
        actions = {}
        for _, action in ipairs(def.actions) do
            if actionAllowed(src, def, action) then
                actions[#actions + 1] = { id = action.id, label = action.label, description = action.description, args = wireArgs(action.args) }
            end
        end
        if #actions == 0 then return nil end
    end
    return {
        name = name, kind = def.kind, module = def.module, chapter = def.chapter, label = def.label, description = def.description,
        scope = def.scope, runnable = def.kind == 'command' and def.scope ~= 'console', ui = def.ui or nil,
        key = def.key, keyDevice = def.keyDevice, keyDisplay = def.keyDisplay, hold = def.hold or nil,
        actions = actions, args = wireArgs(def.args),
    }
end

--- Le joueur peut-il voir cette entrée ? Public : tous ; Conseil : le droit déclaré, ou tout membre du Conseil ;
--- console : les membres du Conseil, en lecture seule.
---@param def table
---@param src integer
---@param staff boolean
---@return boolean
local function visible(def, src, staff)
    if def.hidden then return false end
    if def.scope == 'player' then return true end
    if def.scope == 'console' then return staff end
    if def.permission then return bridge.Can(src, def.permission, def.ace) end
    return staff
end

--- Entrées visibles d'un joueur, triées par chapitre puis libellé, et la liste des chapitres.
---@param src integer
---@return table[] entries
---@return { id: string, label: string }[] chapters
---@return boolean staff
function catalog.visible(src)
    local staff = bridge.IsStaff(src)
    local entries, chapters, seen = {}, {}, {}
    for name, def in pairs(core.registry.all(REGISTRY) or {}) do
        if visible(def, src, staff) then
            local entry = wire(name, def, src)
            if entry then
                entries[#entries + 1] = entry
                if not seen[def.module] then
                    seen[def.module] = true
                    chapters[#chapters + 1] = { id = def.module, label = def.chapter }
                end
            end
        end
    end
    sort(entries, function(a, b)
        if a.chapter ~= b.chapter then return a.chapter < b.chapter end
        if a.label ~= b.label then return a.label < b.label end
        return a.name < b.name
    end)
    -- ordre total (deux modules peuvent porter le même chapitre) : même contenu, même empreinte à chaque ouverture
    sort(chapters, function(a, b)
        if a.label ~= b.label then return a.label < b.label end
        return a.id < b.id
    end)
    return entries, chapters, staff
end

---@param name string
---@param patterns string[]
---@return boolean
local function matches(name, patterns)
    for _, pattern in ipairs(patterns) do
        if find(name, pattern) then return true end
    end
    return false
end

--- Commandes des ressources vAvA enregistrées auprès du jeu mais absentes du registre (Conseil) : la liste de ce
--- qui reste à décrire, lançable en texte libre.
---@return { name: string, module: string }[]
function catalog.undeclared()
    local out = {}
    if not cfg.undeclared.enabled then return out end
    local declared = core.registry.all(REGISTRY) or {}
    for _, command in ipairs(bridge.RegisteredCommands()) do
        if matches(command.resource, cfg.undeclared.resources) and not matches(command.name, cfg.undeclared.hidden)
            and not declared[command.name] then
            out[#out + 1] = { name = command.name, module = command.resource }
        end
    end
    sort(out, function(a, b)
        if a.module ~= b.module then return a.module < b.module end
        return a.name < b.name
    end)
    return out
end

--- Le joueur peut-il lancer (ou noter dans ses dernières pages) cette commande ? `actionId` : le mot qui suit le
--- nom ; s'il désigne une sous-commande déclarée, son droit propre est vérifié et il est rendu, sinon ce n'était qu'un
--- argument (rien n'est rendu).
---@param src integer
---@param name string
---@param actionId? string
---@return boolean ok
---@return string|nil code  unknown | refused | console
---@return string|nil action  sous-commande reconnue
function catalog.canRun(src, name, actionId)
    local def = core.registry.get(REGISTRY, name)
    if not def then
        -- non décrite : lançable par le Conseil seul ; pour un autre joueur, inutile de parcourir les commandes du jeu
        if not bridge.IsStaff(src) then return false, 'unknown' end
        for _, command in ipairs(catalog.undeclared()) do
            if command.name == name then return true end
        end
        return false, 'unknown'
    end
    local staff = bridge.IsStaff(src)
    if not visible(def, src, staff) then return false, 'refused' end
    if def.scope == 'console' then return false, 'console' end
    local action = actionId and actionId ~= '' and actionOf(def, actionId) or nil
    if action and not actionAllowed(src, def, action) then return false, 'refused' end
    return true, nil, action and actionId or nil
end

--- Argument désigné d'une entrée : par sous-commande ('' : forme nue) et rang ; rend aussi la sous-commande.
---@param def table
---@param actionId string
---@param index integer
---@return table|nil arg
---@return table|nil action
local function argumentOf(def, actionId, index)
    local args, action = def.args, nil
    if def.actions then
        action = actionOf(def, actionId)
        args = action and action.args
    end
    return args and args[index] or nil, action
end

--- Valeurs proposées pour un argument dynamique : joueurs en jeu (hors du Conseil, les seuls proches), clés d'un
--- registre du core, liste d'un module.
---@param src integer
---@param name string
---@param actionId string
---@param index integer
---@return boolean ok
---@return table|string  { { value, label } } ou code
function catalog.options(src, name, actionId, index)
    local def = core.registry.get(REGISTRY, name)
    if not def then return false, 'unknown' end
    local staff = bridge.IsStaff(src)
    if not visible(def, src, staff) then return false, 'refused' end
    local arg, action = argumentOf(def, actionId, index)
    -- sous-commande à droit propre : ses valeurs ne vont qu'à qui peut la lancer (comme dans l'index)
    if action and not actionAllowed(src, def, action) then return false, 'refused' end
    if not arg then return false, 'invalid_request' end
    local out = {}
    if arg.type == 'player' then
        -- hors du Conseil, les noms des seuls joueurs à portée de voix : jamais la liste de tout le royaume
        local players = staff and bridge.ActivePlayers() or bridge.NearbyPlayers(src, cfg.players.nearbyRadius)
        for _, player in ipairs(players) do
            out[#out + 1] = { value = tostring(player.source), label = ('%s (n° %d)'):format(player.name, player.source) }
        end
    elseif arg.type == 'registry' then
        local field = arg.labelField or 'label'
        for key, data in pairs(core.registry.all(arg.registry) or {}) do
            local label = type(data) == 'table' and data[field]
            out[#out + 1] = { value = key, label = type(label) == 'string' and label or key }
            if #out >= MAX_OPTIONS then break end
        end
        sort(out, function(a, b) return lower(a.label) < lower(b.label) end)
    elseif arg.type == 'list' then
        out = bridge.ListFrom(def.module, arg.list)
    else
        return false, 'invalid_request'
    end
    return true, out
end
