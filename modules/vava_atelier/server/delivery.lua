--[[
    vava_atelier/server/delivery.lua
    Rôle : code du Conseil livré à la demande (T-157). Au démarrage : paquet assemblé depuis les fichiers des
           directives `vava_conseil_lua` puis `vava_conseil_web` du manifeste, dans leur ordre, lus sur la copie
           déployée ; chaque fichier Lua compilé sans être exécuté (contrôle) ; empreintes FNV-1a (version, morceaux)
           et SHA-256 (recalculée par le chargeur avant tout `load`) ; découpe en morceaux de 64 Ko. Jamais dans un
           paquet : `config.lua`, `server/`, `bridge/` (relecture sécurité S-3). Un paquet qui ne se construit pas
           n'empêche pas le module de démarrer : le RPC répond `unavailable`. RPC `code` : description du paquet ou un
           morceau, au seul joueur qui a le droit d'ouvrir l'Atelier (relu à chaque appel), dans un budget par compte
           (seau rempli de `hourlyPackages` paquets par heure, relectures S-5 et R-2 : une reconnexion ne le remet pas
           à neuf). Aucune base, aucune attente. Bornes des réglages du chargeur contrôlées au setup.
    Dépendances : shared/constants.lua, config_client.lua, config.lua, shared/digest.lua, shared/codepack.lua,
                  shared/codepack_encode.lua, server/core.lua, server/access.lua
]]

local type, ipairs, tostring = type, ipairs, tostring
local mathType, min = math.type, math.min
local find, gsub, match, reverse, sub, lower = string.find, string.gsub, string.match, string.reverse, string.sub,
    string.lower
local GetNumResourceMetadata, GetResourceMetadata, LoadResourceFile, GetGameTimer =
    GetNumResourceMetadata, GetResourceMetadata, LoadResourceFile, GetGameTimer

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local RPC = VavaAtelier.RPC
local LIMITS = VavaAtelier.CODEPACK
local codepack, digest, sha256, access = VavaAtelier.codepack, VavaAtelier.digest, VavaAtelier.sha256,
    VavaAtelier.access
local log = VavaAtelier.log

local RESOURCE = VavaAtelier.resource
-- nom des fichiers d'une ressource dans FiveM : les erreurs se lisent « vava_atelier/client/placer.lua:123: … »
local CHUNK_PREFIX = '@@' .. RESOURCE .. '/'
local HOUR_MS = 3600000
-- directives du manifeste, dans l'ordre du paquet : genre de chaque extension permise
local LISTS = {
    { directive = 'vava_conseil_lua', kinds = { lua = 'L' } },
    { directive = 'vava_conseil_web', kinds = { css = 'C', js = 'J' } },
}

local delivery = {}
VavaAtelier.delivery = delivery

-- dossiers du seul serveur, jamais dans un paquet (relecture sécurité S-3 ; config.lua : FORBIDDEN_FILES)
local FORBIDDEN_DIRS = { 'server/', 'bridge/' }
local FORBIDDEN_FILES = { ['config.lua'] = true }

-- paquet construit : { ready, fp, sha, bytes, parts, pieces, err } (le texte entier n'est pas gardé)
local state = { ready = false, err = 'non construit' }
-- par compte : { allowance, at, logged, warned } — octets que le compte peut encore recevoir (seau rempli de
-- hourlyPackages × taille du paquet par heure, plein au départ), dernière mise à jour, empreinte dont l'envoi est déjà
-- écrit en console, dernier refus écrit en console. Gardé d'une connexion à l'autre (quelques octets par membre qui a
-- téléchargé l'outil).
local served = {}

--- Entier écrit par groupes de trois chiffres (« 250 368 »).
local function grouped(n)
    local text = reverse((gsub(reverse(tostring(n)), '([0-9][0-9][0-9])', '%1 ')))
    return (gsub(text, '^ ', ''))
end

---@param value any
---@param low integer
---@param high integer
local function integerIn(value, low, high)
    return mathType(value) == 'integer' and value >= low and value <= high
end

---@param value any
local function shortText(value)
    return type(value) == 'string' and #value >= 1 and #value <= 160
end

--- Réglages du chargeur (config_client.lua, relu par le serveur) et du budget (config.lua) : le setup refuse une valeur
--- hors bornes, avec sa raison.
---@param settings table  VavaAtelier.config
---@return boolean ok
---@return string|nil reason
function delivery.checkSettings(settings)
    local waits = type(settings.delivery) == 'table' and settings.delivery or {}
    for _, key in ipairs({ 'pageWaitMs', 'bootWaitMs' }) do
        if not integerIn(waits[key], 1000, 30000) then
            return false, ('config_client.lua, delivery.%s : entier de 1000 à 30000 attendu'):format(key)
        end
    end
    local texts = type(settings.texts) == 'table' and settings.texts or {}
    for _, key in ipairs({ 'loading', 'loadFailed' }) do
        if not shortText(texts[key]) then
            return false, ('config_client.lua, texts.%s : texte de 1 à 160 octets attendu'):format(key)
        end
    end
    local hourly = type(settings.delivery) == 'table' and settings.delivery.hourlyPackages
    if not integerIn(hourly, 1, 20) then
        return false, 'config.lua, delivery.hourlyPackages : entier de 1 à 20 attendu'
    end
    -- un config.lua d'avant 1.4.0 n'a pas ce débit : le RPC serait déclaré sans limite propre
    if type(settings.rateLimits) ~= 'table' or type(settings.rateLimits.code) ~= 'table' then
        return false, 'config.lua, rateLimits.code : débit attendu'
    end
    return true
end

--- Chemins d'une directive du manifeste, dans l'ordre de déclaration.
---@param directive string
---@return string[]
local function listed(directive)
    local out = {}
    local count = GetNumResourceMetadata(RESOURCE, directive) or 0
    for i = 0, count - 1 do
        out[#out + 1] = GetResourceMetadata(RESOURCE, directive, i)
    end
    return out
end

--- Fichiers du paquet lus, contrôlés et compilés : liste de { kind, name, code }, ou nil et la raison.
---@return table[]|nil pieces
---@return string|nil err
local function gather()
    local pieces, seen = {}, {}
    for _, list in ipairs(LISTS) do
        local names = listed(list.directive)
        if #names == 0 then return nil, ('directive %s vide ou absente du manifeste'):format(list.directive) end
        for _, name in ipairs(names) do
            if #pieces >= LIMITS.MAX_PIECES then
                return nil, ('plus de %d fichiers'):format(LIMITS.MAX_PIECES)
            end
            local extension = type(name) == 'string' and match(name, '%.([a-z]+)$')
            local kind = extension and list.kinds[extension]
            if not kind or not codepack.validName(name, kind) then
                return nil, ('chemin refusé dans %s : %s'):format(list.directive, tostring(name))
            end
            if FORBIDDEN_FILES[lower(name)] then
                return nil, ('%s ne part jamais dans un paquet (réglages du seul serveur)'):format(name)
            end
            for _, dir in ipairs(FORBIDDEN_DIRS) do
                if sub(name, 1, #dir) == dir then
                    return nil, ('%s ne part jamais dans un paquet (code du seul serveur, %s)'):format(name, dir)
                end
            end
            if seen[name] then return nil, ('fichier listé deux fois : %s'):format(name) end
            seen[name] = true
            local code = LoadResourceFile(RESOURCE, name)
            if type(code) ~= 'string' then return nil, ('fichier absent : %s'):format(name) end
            code = gsub(code, '\r\n', '\n')
            if find(code, '\0', 1, true) then return nil, ('octet nul dans %s'):format(name) end
            if kind == 'L' then
                -- compilation de contrôle, texte seul : la fonction n'est jamais appelée sur le serveur
                local compiled, syntaxError = load(code, CHUNK_PREFIX .. name, 't')
                if not compiled then return nil, ('erreur de syntaxe : %s'):format(tostring(syntaxError)) end
            end
            pieces[#pieces + 1] = { kind = kind, name = name, code = code }
        end
    end
    return pieces
end

--- Construit le paquet (setup du module). Un échec laisse le paquet indisponible (RPC `unavailable`) sans arrêter le
--- module.
---@return boolean ok
---@return string|nil err
function delivery.build()
    state = { ready = false, err = 'non construit' }
    local pieces, err = gather()
    local text
    if pieces then text, err = codepack.encode(pieces) end
    local parts
    if text then
        parts, err = codepack.cut(text, LIMITS.PART_BYTES)
        if parts and #parts > LIMITS.MAX_PARTS then parts, err = nil, 'too_large' end
    end
    if not parts then
        state.err = tostring(err)
        log.error('paquet du Conseil non construit : %s ; l\'Atelier ne s\'ouvrira chez aucun membre', state.err)
        return false, state.err
    end
    state = { ready = true, fp = digest(text), sha = sha256(text), bytes = #text, parts = parts, pieces = #pieces }
    log.info('paquet du Conseil : %d fichiers, %s octets, %d morceaux, empreinte %s, SHA-256 %s', state.pieces,
        grouped(state.bytes), #parts, state.fp, state.sha)
    return true
end

--- État du paquet (lecture seule) : { ready, fp?, sha?, bytes?, parts?, pieces?, err? }.
---@return table
function delivery.status()
    return { ready = state.ready, fp = state.fp, sha = state.sha, bytes = state.bytes,
        parts = state.parts and #state.parts, pieces = state.pieces, err = state.err }
end

--- RPC `code` : `part == 0` → description `{ fp, sha, parts, bytes }` ; sinon le morceau `part` du paquet d'empreinte
--- `fp`. Droit relu à chaque appel (un rang retiré entre deux morceaux arrête l'envoi).
---@param source integer
---@param fp string    '' ou 16 chiffres hexadécimaux (schéma du RPC)
---@param part integer 0 à MAX_PARTS (schéma du RPC)
---@return boolean
---@return any
function delivery.rpc(source, fp, part)
    local ctx, code = access.allowed(source, RPC.CODE)
    if not ctx then return false, code end
    if not state.ready then return false, 'unavailable' end
    if part == 0 then
        return true, { fp = state.fp, sha = state.sha, parts = #state.parts, bytes = state.bytes }
    end
    if fp ~= state.fp then return false, 'stale' end
    local chunk = state.parts[part]
    if not chunk then return false, 'bad_request' end
    -- seau du compte : plein au départ, rempli au fil de l'heure (hourlyPackages paquets entiers par heure au plus)
    local now, cap = GetGameTimer(), cfg.delivery.hourlyPackages * state.bytes
    local key = ctx.accountId or ('joueur ' .. source)
    local mine = served[key]
    if not mine then
        mine = { allowance = cap, at = now }
        served[key] = mine
    else
        mine.allowance = min(cap, mine.allowance + (now - mine.at) * cap / HOUR_MS)
        mine.at = now
    end
    if #chunk > mine.allowance then
        -- contre-relecture C-5 : un client qui insiste se voit en console, une ligne par compte et par intervalle
        if not mine.warned or now - mine.warned >= cfg.limits.refusalLogMs then
            mine.warned = now
            log.warn('paquet du Conseil : budget épuisé, joueur %d, compte %s (%d paquets par heure)', source,
                tostring(ctx.accountId), cfg.delivery.hourlyPackages)
        end
        return false, 'rate_limited'
    end
    mine.allowance = mine.allowance - #chunk
    if part == 1 and mine.logged ~= state.fp then
        mine.logged = state.fp
        log.info('paquet du Conseil envoyé : joueur %d, compte %s, %s octets', source, tostring(ctx.accountId),
            grouped(state.bytes))
    end
    return true, chunk
end
