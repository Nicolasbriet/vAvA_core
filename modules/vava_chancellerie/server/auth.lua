--[[
    vava_chancellerie/server/auth.lua
    Rôle : qui peut parler au pont. L'adresse HTTP du serveur de jeu est publique (port du jeu, relais de Cfx.re) :
           seules les requêtes venues de la machine elle-même, portant la clé de la Chancellerie pour ce lancement,
           sont acceptées. La clé ne passe ni par la ligne de commande de FXServer (lisible par tout utilisateur de la
           machine) ni par une convar (lisible par toute ressource) : le pont la demande dans la console du serveur, que
           la Chancellerie lit, et elle la lui donne par l'entrée de FXServer avec une commande que seule la console
           peut lancer ; la clé ne vit qu'en mémoire, la première reçue est gardée. Sans Chancellerie (aucune adresse
           posée au lancement, ou une adresse hors de la machine), le pont ne demande rien et reste fermé ; l'adresse
           est figée au setup. Limite : une ressource serveur hostile qui lance la commande avant la Chancellerie
           garderait le pont ; la Chancellerie le voit (KEY_CONFLICT_LINE, ou pas d'évènement `ready` vérifié) et
           alerte, mais rien ici ne protège d'une ressource serveur, qui a déjà tous les pouvoirs sur le serveur.
    Dépendances : config.lua, shared/rules.lua
]]

local type, select, byte, pairs, lower, tonumber, print = type, select, string.byte, pairs, string.lower, tonumber, print
local GetConvar, GetGameTimer, SetTimeout, RegisterCommand = GetConvar, GetGameTimer, SetTimeout, RegisterCommand

local cfg = VavaBridge.config
local rules = VavaBridge.rules
local HEADER = 'x-vava-token'
local LOOPBACK = { ['127.0.0.1'] = true, ['::1'] = true, ['::ffff:127.0.0.1'] = true }
local CONSOLE = 0

local auth = {}
VavaBridge.auth = auth

---@type string|nil  clé de ce lancement : seulement en mémoire, jamais écrite ni affichée
local key = nil
---@type function|nil  à appeler dès que la clé arrive (pont prêt : la Chancellerie est prévenue)
local onKey = nil
---@type string|nil  adresse de la Chancellerie, figée au setup
local panelUrl = nil

---@return string
function auth.token()
    return key or ''
end

---@return boolean
function auth.enabled()
    return key ~= nil
end

--- Lit l'adresse de la Chancellerie, une seule fois (au setup) : une ressource qui changerait la convar ensuite ne
--- recevrait ni la clé ni les évènements. Seulement la machine elle-même (shared/rules.lua).
---@return string|nil url
---@return string|nil err  invalid_url : convar posée mais refusée
function auth.capture()
    local url = GetConvar(cfg.convars.url, '')
    panelUrl = nil
    if url == '' then return nil end
    if not rules.validPanelUrl(url) then return nil, 'invalid_url' end
    panelUrl = url
    return url
end

--- Adresse de la Chancellerie figée au setup, ou nil.
---@return string|nil
function auth.panelUrl()
    return panelUrl
end

--- Serveur lancé par la Chancellerie ? Elle pose son adresse sur la ligne de commande ; la clé arrive ensuite.
---@return boolean
function auth.expected()
    return panelUrl ~= nil
end

--- Adresse sans son port : « 127.0.0.1:51234 » → « 127.0.0.1 », « [::1]:51234 » → « ::1 ».
---@param address any
---@return string
local function hostOf(address)
    if type(address) ~= 'string' then return '' end
    local bracketed = address:match('^%[([^%]]+)%]')
    if bracketed then return bracketed end
    -- une seule fois « : » : adresse IPv4 suivie de son port ; plusieurs : adresse IPv6 sans port
    local colons = select(2, address:gsub(':', ''))
    if colons == 1 then return (address:match('^([^:]+):%d+$')) or address end
    return address
end

---@param address any
---@return boolean
function auth.isLoopback(address)
    return LOOPBACK[hostOf(address)] == true
end

--- Comparaison à temps constant : la durée ne dit rien de la clé.
---@param given any
---@param expected string
---@return boolean
local function same(given, expected)
    if type(given) ~= 'string' or #given ~= #expected then return false end
    local diff = 0
    for i = 1, #expected do diff = diff | (byte(given, i) ~ byte(expected, i)) end
    return diff == 0
end

---@param headers table|nil
---@return string|nil
local function header(headers, name)
    if type(headers) ~= 'table' then return nil end
    for headerName, value in pairs(headers) do
        if type(headerName) == 'string' and lower(headerName) == name then return value end
    end
    return nil
end

--- Requête du pont acceptée ?
---@param request table  requête de SetHttpHandler
---@return boolean
function auth.check(request)
    if not key or not auth.isLoopback(request.address) then return false end
    return same(header(request.headers, HEADER), key)
end

--- Clé reçue par la commande de la console. Refus : `console_only` (lancée par un joueur), `not_expected` (serveur
--- lancé sans la Chancellerie), `already` (la même, déjà reçue), `conflict` (une autre : la première est gardée),
--- `invalid` (pas une clé). La clé n'apparaît dans aucun message.
---@param src integer  0 : la console du serveur
---@param value any
---@return boolean ok
---@return string|nil err
function auth.receive(src, value)
    if src ~= CONSOLE then return false, 'console_only' end
    if not auth.expected() then return false, 'not_expected' end
    if key then return false, same(value, key) and 'already' or 'conflict' end
    if not rules.validKey(value, cfg.tokenMin, cfg.key.max) then return false, 'invalid' end
    key = value
    local callback = onKey
    onKey = nil
    if callback then callback() end
    return true
end

--- Déclare la commande par laquelle la Chancellerie donne la clé. Appelé pendant le setup, avant toute demande.
function auth.listen()
    RegisterCommand(VavaBridge.KEY_COMMAND, function(source, args)
        local ok, code = auth.receive(tonumber(source) or -1, type(args) == 'table' and args[1] or nil)
        if ok then
            VavaBridge.log.info('clé de la Chancellerie reçue : pont ouvert')
        elseif code == 'conflict' then
            -- ligne du protocole, lue par la Chancellerie : elle en fait une alerte (sa clé n'a pas été prise)
            print(VavaBridge.KEY_CONFLICT_LINE)
        elseif code == 'invalid' or code == 'not_expected' then
            VavaBridge.log.warn('clé du pont refusée (%s)', code)
        end
    end, true)
end

--- Demande la clé à la Chancellerie (marque écrite dans la console, répétée tant qu'elle n'arrive pas, pendant
--- `key.waitMs` au plus), puis appelle `callback` dès qu'elle arrive, même après ce délai.
---@param callback fun()
function auth.await(callback)
    if key then
        callback()
        return
    end
    onKey = callback
    local started = GetGameTimer()
    local function ask()
        if key then return end
        if GetGameTimer() - started >= cfg.key.waitMs then
            VavaBridge.log.warn('la Chancellerie n\'a pas donné la clé du pont : pont fermé (est-elle à jour ?)')
            return
        end
        print(VavaBridge.KEY_ASK_LINE)
        SetTimeout(cfg.key.askEveryMs, ask)
    end
    ask()
end

auth.HEADER = HEADER
