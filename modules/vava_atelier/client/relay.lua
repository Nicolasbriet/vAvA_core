--[[
    vava_atelier/client/relay.lua
    Rôle : retours de la page → RPC du serveur (forme de vava_codex/client/main.lua `forward`). Le relais ne transmet
           que les clés attendues, converties (chaîne, entier), et laisse le serveur refuser le reste ; chaque réponse
           a la forme `{ ok, error?, data? }`. Il tient les versions gardées de l'accueil et des descripteurs (seul le
           changé repart du serveur) et envoie le bandeau du volet (`mode`) à l'ouverture d'un atelier.
    Dépendances : shared/constants.lua, config.lua, client/core.lua, client/nui.lua, client/session.lua
]]

local type, tostring, tonumber, ipairs = type, tostring, tonumber, ipairs
local tointeger = math.tointeger
local pack = table.pack

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local RPC = VavaAtelier.RPC
local nui, session = VavaAtelier.nui, VavaAtelier.session

local CARDS = { 'n', 's', 'b' }

---@param value any
---@return string
local function str(value)
    return type(value) == 'string' and value or ''
end

---@param value any
---@param default integer
---@return integer
local function int(value, default)
    return tointeger(tonumber(value)) or default
end

--- Valeurs d'une fiche : les trois cartes seulement, telles quelles (le serveur revérifie chaque clé et chaque valeur).
---@param values any
---@return table
local function cards(values)
    local out = {}
    if type(values) ~= 'table' then return out end
    for _, card in ipairs(CARDS) do
        if type(values[card]) == 'table' then out[card] = values[card] end
    end
    return out
end

--- Appel d'un RPC, réponse homogène : `{ ok = true, data }` ou `{ ok = false, error = code }` (code du serveur, ou
--- du transport : rate_limited, timeout, invalid_args…).
---@param name string
---@return table
local function forward(name, ...)
    local results = pack(core.rpc.call(name, ...))
    if not results[1] then return { ok = false, error = tostring(results[2]) } end
    if not results[2] then return { ok = false, error = tostring(results[3]) } end
    return { ok = true, data = results[3] }
end

--- Bandeau du volet (« Atelier de … », « Mode édition : visible par vous seul ») : la page le montre sur une fiche
--- en mise en page « volet ». T-102 y ajoutera l'état de la visée.
---@param label string
local function banner(label)
    nui.send('mode', { banner = { title = label, line = cfg.texts.modeLine } })
end

nui.on('home', function(d)
    local known = session.known()
    if str(d.version) == '' then known.home = '' end
    local response = forward(RPC.HOME, known.home)
    if not response.ok then return response end
    local message = session.absorbHome(response.data)
    if not message then return { ok = false, error = 'stale' } end
    return { ok = true, data = message }
end)

--- Descripteur d'un atelier : la version gardée part avec la demande ; le serveur ne renvoie le descripteur que s'il a
--- changé. Une réponse sans descripteur pour une autre version (incohérente) fait redemander tout, une fois.
nui.on('editor', function(d)
    local id = str(d.editor)
    local editors = session.known().editors
    local kept = editors[id]
    local response = forward(RPC.EDITOR, id, kept and kept.version or '')
    if not response.ok then return response end
    local answer = response.data
    if type(answer) ~= 'table' or type(answer.version) ~= 'string' then return { ok = false, error = 'stale' } end
    if type(answer.descriptor) ~= 'table' and (not kept or answer.version ~= kept.version) then
        editors[id] = nil
        response = forward(RPC.EDITOR, id, '')
        if not response.ok then return response end
        answer = response.data
        if type(answer) ~= 'table' or type(answer.descriptor) ~= 'table' then return { ok = false, error = 'stale' } end
    end
    if type(answer.descriptor) == 'table' then
        editors[id] = { version = answer.version, label = str(answer.descriptor.label) }
    end
    banner(editors[id].label)
    return { ok = true, data = answer }
end)

nui.on('list', function(d)
    return forward(RPC.LIST, str(d.editor), str(d.kind), int(d.page, 1), str(d.query))
end)

nui.on('read', function(d)
    return forward(RPC.READ, str(d.editor), str(d.kind), str(d.id))
end)

nui.on('check', function(d)
    return forward(RPC.CHECK, str(d.editor), str(d.kind), str(d.id), cards(d.values))
end)

nui.on('options', function(d)
    return forward(RPC.OPTIONS, str(d.editor), str(d.kind), str(d.field), str(d.query), int(d.page, 1))
end)

nui.on('search', function(d)
    return forward(RPC.SEARCH, str(d.text))
end)

nui.on('journal', function(d)
    return forward(RPC.JOURNAL, int(d.before, 0), str(d.editor))
end)

nui.on('close', function()
    session.close(true)
    return { ok = true }
end)

-- La page n'a pas le contenu que les versions annoncent (secours) : tout est oublié, la prochaine demande renvoie tout.
nui.on('stale', function()
    session.forget()
    return { ok = true }
end)
