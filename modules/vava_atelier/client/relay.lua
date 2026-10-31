--[[
    vava_atelier/client/relay.lua
    Rôle : retours de la page → RPC du serveur (forme de vava_codex/client/main.lua `forward`). Le relais ne transmet
           que les clés attendues, converties (chaîne, entier), et laisse le serveur refuser le reste ; chaque réponse
           a la forme `{ ok, error?, data? }`. Il tient les versions gardées de l'accueil et des descripteurs (seul le
           changé repart du serveur) et envoie le bandeau du volet (`mode`) à l'ouverture d'un atelier.
           T-101 : douze relais (enregistrer, essayer, arrêter, résumer, publier, revenir, abandonner, retirer,
           reprendre, historique, version, retirées) ; le jeton d'un résumé part tel quel (le serveur refuse tout ce
           qui n'est pas 16 hexadécimaux) ; bandeau d'essai (`texts.trialLine` de l'atelier) sur une fiche en essai,
           bandeau d'édition à la fin de l'essai.
    Dépendances : shared/constants.lua, config_client.lua, client/core.lua, client/nui.lua, client/session.lua
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

--- Refus mis en mots : `{ ok = false, error = code, text }`, le texte venant de la config (la page n'en garde pas de
--- copie ; un code inconnu prend le texte « indisponible »).
---@param code any
---@return table
local function refusal(code)
    local error = tostring(code)
    local refused = cfg.texts.refused
    return { ok = false, error = error, text = refused[error] or refused.unavailable }
end

--- Appel d'un RPC, réponse homogène : `{ ok = true, data }` ou `{ ok = false, error = code, text }` (code du serveur,
--- ou du transport : rate_limited, timeout, invalid_args…).
---@param name string
---@return table
local function forward(name, ...)
    local results = pack(core.rpc.call(name, ...))
    if not results[1] then return refusal(results[2]) end
    if not results[2] then return refusal(results[3]) end
    return { ok = true, data = results[3] }
end

--- Bandeau du volet (« Atelier de … », « Mode édition : visible par vous seul ») : la page le montre sur une fiche
--- en mise en page « volet ». T-102 y ajoutera l'état de la visée.
---@param label string
local function banner(label, line)
    nui.send('mode', { banner = { title = label, line = line or cfg.texts.modeLine } })
end

--- Bandeau de l'atelier ouvert selon l'état d'une fiche : ligne d'essai de l'atelier sur une fiche en essai.
---@param editorId string
---@param tone any  ton de l'étiquette d'état reçue (`trial` : en essai)
local function bannerFor(editorId, tone)
    local kept = session.known().editors[editorId]
    if not kept then return end
    if tone == 'trial' then
        banner(kept.label, (kept.trialLine or '') ~= '' and kept.trialLine or cfg.texts.trialLineDefault)
    else
        banner(kept.label)
    end
end

--- Ton de l'étiquette d'état d'une réponse, ou nil.
local function toneOf(response)
    local data = response.ok and response.data
    local state = type(data) == 'table' and data.state
    return type(state) == 'table' and state.tone or nil
end

nui.on('home', function(d)
    local known = session.known()
    if str(d.version) == '' then known.home = '' end
    local response = forward(RPC.HOME, known.home)
    if not response.ok then return response end
    local message = session.absorbHome(response.data)
    if not message then return refusal('stale') end
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
    if type(answer) ~= 'table' or type(answer.version) ~= 'string' then return refusal('stale') end
    if type(answer.descriptor) ~= 'table' and (not kept or answer.version ~= kept.version) then
        editors[id] = nil
        response = forward(RPC.EDITOR, id, '')
        if not response.ok then return response end
        answer = response.data
        if type(answer) ~= 'table' or type(answer.descriptor) ~= 'table' then return refusal('stale') end
    end
    if type(answer.descriptor) == 'table' then
        local descTexts = type(answer.descriptor.texts) == 'table' and answer.descriptor.texts or {}
        editors[id] = { version = answer.version, label = str(answer.descriptor.label),
            trialLine = str(descTexts.trialLine) }
    end
    session.setEditor(id)
    banner(editors[id].label)
    return { ok = true, data = answer }
end)

nui.on('list', function(d)
    return forward(RPC.LIST, str(d.editor), str(d.kind), int(d.page, 1), str(d.query))
end)

nui.on('read', function(d)
    local editor = str(d.editor)
    local response = forward(RPC.READ, editor, str(d.kind), str(d.id))
    if response.ok then bannerFor(editor, toneOf(response)) end
    return response
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

-- T-101 : définitions gardées ----------------------------------------------------------------------------------------

--- Relais d'une écriture qui change l'état de la fiche : le bandeau suit (essai ou édition).
---@param name string
---@param rpc string
---@param build fun(d: table): ...
local function writing(name, rpc, build)
    nui.on(name, function(d)
        local editor = str(d.editor)
        local response = forward(rpc, build(d))
        local tone = toneOf(response)
        if tone then bannerFor(editor, tone) end
        return response
    end)
end

writing('save', RPC.SAVE, function(d)
    return str(d.editor), str(d.kind), str(d.id), int(d.rev, 0), cards(d.values)
end)
writing('trial', RPC.TRIAL, function(d) return str(d.editor), str(d.kind), str(d.id), int(d.rev, 0) end)
writing('endTrial', RPC.END_TRIAL, function(d) return str(d.editor), str(d.kind), str(d.id) end)
writing('publish', RPC.PUBLISH, function(d)
    return str(d.editor), str(d.kind), str(d.id), int(d.rev, 0), str(d.token)
end)
writing('restore', RPC.RESTORE, function(d)
    return str(d.editor), str(d.kind), str(d.id), int(d.version, 0), str(d.token)
end)
writing('discard', RPC.DISCARD, function(d) return str(d.editor), str(d.kind), str(d.id), int(d.rev, 0) end)
writing('retire', RPC.RETIRE, function(d) return str(d.editor), str(d.kind), str(d.id) end)
writing('take', RPC.TAKE, function(d) return str(d.editor), str(d.kind), str(d.id), int(d.rev, 0) end)

nui.on('preview', function(d)
    return forward(RPC.PREVIEW, str(d.editor), str(d.kind), str(d.id), str(d.what), int(d.ref, 0))
end)

nui.on('history', function(d)
    return forward(RPC.HISTORY, str(d.editor), str(d.kind), str(d.id), int(d.before, 0))
end)

nui.on('version', function(d)
    return forward(RPC.VERSION, str(d.editor), str(d.kind), str(d.id), int(d.version, 0))
end)

nui.on('removed', function(d)
    return forward(RPC.REMOVED, str(d.editor), str(d.kind), int(d.page, 1))
end)

--- Fin d'un essai annoncée par le serveur pendant que la fiche est ouverte : bandeau d'édition.
VavaAtelier.relay = { bannerFor = bannerFor }

nui.on('close', function()
    session.close(true)
    return { ok = true }
end)

-- La page n'a pas le contenu que les versions annoncent (secours) : tout est oublié, la prochaine demande renvoie tout.
nui.on('stale', function()
    session.forget()
    return { ok = true }
end)
