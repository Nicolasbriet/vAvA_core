--[[
    vava_atelier/client/loader.lua
    Rôle : chargeur du code du Conseil (amorce livrée à tous, T-157). Au premier F9 d'une séance de jeu : description du
           paquet par le RPC `code` (refusée hors du Conseil : stockage local effacé), stockage local de la ressource
           (KVP, morceaux de 32 Ko, empreinte écrite en dernier) relu et recalculé contre l'empreinte que le serveur
           vient d'annoncer, sinon morceaux téléchargés l'un après l'autre ; puis chaque fichier Lua exécuté par `load`
           en mode texte dans un environnement du paquet (jamais dans _G), puis la page amorcée (feuille et scripts
           envoyés à web/boot.js, compte rendu attendu). Seul chemin vers `load` : le texte de la réponse du RPC de la
           ressource ou de son stockage local, après comparaison à l'empreinte annoncée dans cette séance ; aucun
           évènement réseau, rappel de page, export ou commande n'y mène. Contrat avec la page :
           docs/plan/rapports/T-157-contrat.md. Aucune boucle.
    Dépendances : shared/constants.lua, config_client.lua, shared/digest.lua, shared/codepack.lua, client/core.lua,
                  client/nui.lua, client/notice.lua
]]

local type, ipairs, tostring, setmetatable, rawset, xpcall = type, ipairs, tostring, setmetatable, rawset, xpcall
local mathType = math.type
local find, sub = string.find, string.sub
local concat = table.concat
local traceback = debug.traceback
local GetResourceKvpString, GetResourceKvpInt, SetResourceKvp, SetResourceKvpInt, DeleteResourceKvp =
    GetResourceKvpString, GetResourceKvpInt, SetResourceKvp, SetResourceKvpInt, DeleteResourceKvp
local SetTimeout, GetCurrentResourceName = SetTimeout, GetCurrentResourceName

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local texts = cfg.texts
local waits = cfg.delivery
local RPC = VavaAtelier.RPC
local LIMITS = VavaAtelier.CODEPACK
local digest, codepack = VavaAtelier.digest, VavaAtelier.codepack
local nui, notice = VavaAtelier.nui, VavaAtelier.notice

-- nom des fichiers d'une ressource dans FiveM : une erreur se lit « vava_atelier/client/placer.lua:123: … » (si F8
-- écrivait `@@` en clair : passer à '@', spec T-157 § 8.4)
local CHUNK_PREFIX = '@@' .. GetCurrentResourceName() .. '/'
-- stockage local : empreinte (écrite en dernier, effacée en premier), taille, nombre de morceaux, morceaux 1 à 16
local KEY_FP, KEY_SIZE, KEY_COUNT, KEY_PART = 'paquet:empreinte', 'paquet:taille', 'paquet:morceaux', 'paquet:'
local HEX = '^[0-9a-f]+$'
local BOOTED, EITHER = { booted = true }, { pageReady = true, booted = true }

local loader = {}
VavaAtelier.loader = loader

-- idle → (F9) → luaReady → ready ; failed : un fichier n'a pas pu être exécuté ou la page a signalé une erreur
local phase = 'idle'
local busy = false            -- une seule demande à la fois (F9 pendant le téléchargement : rien)
local webPieces = nil         -- fichiers C/J gardés jusqu'à l'amorce réussie de la page
local pageSeen = false        -- rappel `pageReady` reçu depuis le démarrage de la ressource
local piecesSent = false      -- `bootEnd` envoyé à la page
local lateReport = nil        -- compte rendu `booted` arrivé sans attente (après l'échéance)
local waiter = nil            -- attente en cours : { promise, wants }

local function log(level, fmt, ...)
    core.log[level](fmt, ...)
end

---@param value any
---@param low integer
---@param high integer
local function integerIn(value, low, high)
    return mathType(value) == 'integer' and value >= low and value <= high
end

-- Stockage local ---------------------------------------------------------------------------------------------------

local cache = {}

--- Efface tout : empreinte d'abord.
function cache.clear()
    DeleteResourceKvp(KEY_FP)
    DeleteResourceKvp(KEY_SIZE)
    DeleteResourceKvp(KEY_COUNT)
    for i = 1, LIMITS.KVP_MAX_CHUNKS do DeleteResourceKvp(KEY_PART .. i) end
end

--- Paquet gardé, seulement s'il est exactement celui annoncé (`info.fp`, `info.bytes`) ; un écart efface le stockage.
---@param info { fp: string, bytes: integer }
---@return string|nil
function cache.read(info)
    local kept = GetResourceKvpString(KEY_FP)
    if kept == nil then return nil end
    local text
    if kept == info.fp and GetResourceKvpInt(KEY_SIZE) == info.bytes then
        local count = GetResourceKvpInt(KEY_COUNT)
        if integerIn(count, 1, LIMITS.KVP_MAX_CHUNKS) then
            local parts, total = {}, 0
            for i = 1, count do
                local part = GetResourceKvpString(KEY_PART .. i)
                if type(part) ~= 'string' then parts = nil break end
                total = total + #part
                if total > info.bytes then parts = nil break end
                parts[i] = part
            end
            text = parts and concat(parts) or nil
        end
    end
    if text and #text == info.bytes and digest(text) == info.fp then return text end
    cache.clear()
    return nil
end

--- Garde le paquet : empreinte effacée d'abord, morceaux, morceaux en trop effacés, taille et nombre, empreinte en
--- dernier ; relu aussitôt (un écart efface tout : le paquet sera retéléchargé à la prochaine séance).
---@param fp string
---@param text string
function cache.write(fp, text)
    DeleteResourceKvp(KEY_FP)
    local parts = codepack.cut(text, LIMITS.KVP_CHUNK)
    if not parts or #parts < 1 or #parts > LIMITS.KVP_MAX_CHUNKS then
        cache.clear()
        log('warn', 'paquet du Conseil : stockage local refusé (%s octets)', tostring(#text))
        return
    end
    for i, part in ipairs(parts) do SetResourceKvp(KEY_PART .. i, part) end
    for i = #parts + 1, LIMITS.KVP_MAX_CHUNKS do DeleteResourceKvp(KEY_PART .. i) end
    SetResourceKvpInt(KEY_SIZE, #text)
    SetResourceKvpInt(KEY_COUNT, #parts)
    SetResourceKvp(KEY_FP, fp)
    local back = {}
    for i = 1, #parts do back[i] = GetResourceKvpString(KEY_PART .. i) or '' end
    if GetResourceKvpString(KEY_FP) ~= fp or concat(back) ~= text then
        cache.clear()
        log('warn', 'paquet du Conseil : stockage local refusé (relecture différente)')
    end
end

-- Paquet -----------------------------------------------------------------------------------------------------------

--- Description annoncée par le serveur : `{ fp, parts, bytes }` contrôlée, ou nil et le code (transport ou refus).
---@return table|nil info
---@return string|nil code
local function describe()
    local ok, success, info = core.rpc.call(RPC.CODE, '', 0)
    if not ok then return nil, success end
    if not success then return nil, info end
    if type(info) ~= 'table' or type(info.fp) ~= 'string' or #info.fp ~= LIMITS.DIGEST_LENGTH
        or not find(info.fp, HEX) or not integerIn(info.parts, 1, LIMITS.MAX_PARTS)
        or not integerIn(info.bytes, 1, LIMITS.MAX_BYTES) or info.bytes > info.parts * LIMITS.PART_BYTES then
        return nil, 'unavailable'
    end
    return { fp = info.fp, parts = info.parts, bytes = info.bytes }
end

--- Morceaux 1 à `parts` du paquet annoncé, l'un après l'autre ; le texte n'est rendu que s'il a exactement la taille et
--- l'empreinte annoncées.
---@param info table
---@return string|nil text
---@return string|nil code
local function download(info)
    local received, total = {}, 0
    for k = 1, info.parts do
        local ok, success, part = core.rpc.call(RPC.CODE, info.fp, k)
        if not ok then return nil, success end
        if not success then return nil, part end
        if type(part) ~= 'string' or #part > LIMITS.PART_BYTES or total + #part > info.bytes then
            return nil, 'unavailable'
        end
        received[k] = part
        total = total + #part
    end
    local text = concat(received)
    if #text ~= info.bytes or digest(text) ~= info.fp then
        log('warn', 'paquet du Conseil reçu altéré : rien n\'est exécuté')
        return nil, 'unavailable'
    end
    return text
end

--- Paquet de cette version : du stockage local s'il est intact, sinon téléchargé puis gardé. Une empreinte périmée
--- (`stale` : le serveur a redémarré l'Atelier entre-temps) relance une seule fois depuis la description.
---@return string|nil text
---@return string|nil code
local function obtain()
    for _ = 1, 2 do
        local info, code = describe()
        if not info then
            if code == 'not_allowed' then cache.clear() end
            return nil, code
        end
        local text = cache.read(info)
        if text then return text end
        notice.feed(texts.loading, 'info')
        text, code = download(info)
        if text then
            cache.write(info.fp, text)
            return text
        end
        if code == 'not_allowed' then cache.clear() end
        if code ~= 'stale' then return nil, code end
    end
    return nil, 'unavailable'
end

--- Échec définitif dans cette séance de jeu : console, message, plus d'essai.
---@return false
local function fail(name, err)
    log('error', 'paquet du Conseil : %s : %s', tostring(name), tostring(err))
    notice.feed(texts.loadFailed, 'danger')
    phase = 'failed'
    return false
end

--- Exécute les fichiers Lua du paquet, dans l'ordre, dans un environnement du paquet : lectures dans _G (natives,
--- VavaAtelier, exports), écritures gardées dans l'environnement (une globale oubliée n'atteint pas _G).
---@param pieces table[]
---@return boolean
local function run(pieces)
    local env = setmetatable({}, {
        __index = _G,
        __newindex = function(t, key, value)
            log('warn', 'paquet du Conseil : globale « %s » posée', tostring(key))
            rawset(t, key, value)
        end,
    })
    for _, piece in ipairs(pieces) do
        -- texte seul ('t' : jamais de code précompilé), nom d'origine du fichier
        local fn, err = load(piece.code, CHUNK_PREFIX .. piece.name, 't', env)
        if not fn then return fail(piece.name, err) end
        local ran, runErr = xpcall(fn, traceback)
        if not ran then return fail(piece.name, runErr) end
    end
    return true
end

-- Page -------------------------------------------------------------------------------------------------------------

--- Rappel de la page : résout l'attente en cours s'il est attendu ; un compte rendu `booted` hors attente est gardé.
local function settle(kind, data)
    local current = waiter
    if current and current.wants[kind] then
        waiter = nil
        current.promise:resolve({ kind = kind, data = data })
    elseif kind == 'booted' then
        lateReport = data
    end
end

--- Attend le premier des rappels `wants` après `send()`, au plus `ms` ; nil à l'échéance.
local function await(wants, ms, send)
    local current = { promise = promise.new(), wants = wants }
    waiter = current
    SetTimeout(ms, function()
        if waiter == current then
            waiter = nil
            current.promise:resolve(false)
        end
    end)
    send()
    return Citizen.Await(current.promise) or nil
end

local function sayHello()
    nui.send('hello')
end

local function sendPieces()
    piecesSent = true
    for i, piece in ipairs(webPieces) do
        nui.send('bootPiece', { index = i - 1, kind = codepack.WEB_KIND[piece.kind], name = piece.name,
            code = piece.code })
    end
    nui.send('bootEnd', { count = #webPieces })
end

--- Amorce de la page : feuille et scripts envoyés (après `pageReady`), compte rendu `booted` lu. Page muette : le Lua
--- reste prêt, le F9 suivant reprend ici.
---@return boolean
local function bootPage()
    local got = lateReport and { kind = 'booted', data = lateReport } or nil
    lateReport = nil
    if not got then
        if pageSeen and not piecesSent then
            got = await(BOOTED, waits.bootWaitMs, sendPieces)
        else
            got = await(EITHER, waits.pageWaitMs, sayHello)
            if got and got.kind == 'pageReady' then got = await(BOOTED, waits.bootWaitMs, sendPieces) end
        end
    end
    if not got then
        log('warn', 'paquet du Conseil : la page ne répond pas')
        notice.feed(notice.refusal('unavailable'), 'warning')
        return false
    end
    local data = got.data
    if type(data) == 'table' and data.ok == true and data.count == #webPieces then
        phase, webPieces = 'ready', nil
        return true
    end
    local piece = type(data) == 'table' and type(data.piece) == 'string' and sub(data.piece, 1, LIMITS.MAX_NAME)
    return fail('page', 'la page signale ' .. (piece or 'une réponse illisible'))
end

--- Paquet de cette version lu et ses fichiers Lua exécutés : rend les fichiers de la page (le texte du paquet et le
--- code Lua sont lâchés au retour), ou nil (refus ou échec déjà annoncés).
---@return table[]|nil web
local function runLua()
    local text, code = obtain()
    if not text then
        notice.feed(notice.refusal(code), 'warning')
        return nil
    end
    local pieces, err = codepack.decode(text)
    if not pieces then
        cache.clear()
        log('warn', 'paquet du Conseil illisible : %s', tostring(err))
        notice.feed(notice.refusal('unavailable'), 'warning')
        return nil
    end
    local lua, web = {}, {}
    for _, piece in ipairs(pieces) do
        if piece.kind == 'L' then lua[#lua + 1] = piece else web[#web + 1] = piece end
    end
    if not run(lua) then return nil end
    if not VavaAtelier.session or not VavaAtelier.placer then
        fail('paquet', 'séance ou outil de placement absent après exécution')
        return nil
    end
    return web
end

--- Téléchargement (ou stockage local), exécution des fichiers Lua, puis amorce de la page.
---@return boolean
local function fetchAndRun()
    local web = runLua()
    if not web then return false end
    phase, webPieces = 'luaReady', web
    return bootPage()
end

--- Rend vrai quand l'Atelier peut s'ouvrir (paquet exécuté, page amorcée). Bloque le fil appelant (RPC, attente de la
--- page) : jamais à chaque image. Une seule demande à la fois.
---@return boolean
function loader.ensure()
    if phase == 'ready' then return true end
    if busy then return false end
    if phase == 'failed' then
        notice.feed(texts.loadFailed, 'danger')
        return false
    end
    busy = true
    local ran, result = xpcall(phase == 'luaReady' and bootPage or fetchAndRun, traceback)
    busy = false
    if not ran then
        log('error', 'chargeur de l\'Atelier en erreur : %s', tostring(result))
        notice.feed(notice.refusal('unavailable'), 'warning')
        return false
    end
    return result == true
end

---@return boolean
function loader.isReady()
    return phase == 'ready'
end

--- Efface le stockage local (droit refusé ou retiré). Le code déjà chargé reste en mémoire jusqu'à la fin de la
--- séance de jeu, sans effet : chaque RPC de l'Atelier revérifie le droit.
function loader.forget()
    cache.clear()
end

--- idle | luaReady | ready | failed
---@return string
function loader.state()
    return phase
end

-- Rappels de la page (web/boot.js), enregistrés au démarrage : `pageReady` à son chargement ou en réponse à `hello`,
-- `booted` après l'insertion de sa feuille et de ses scripts
nui.on('pageReady', function()
    pageSeen = true
    settle('pageReady', nil)
end)

nui.on('booted', function(data)
    settle('booted', data)
end)
