--[[
    vava_chancellerie/server/auth.lua
    Rôle : qui peut parler au pont. L'adresse HTTP du serveur de jeu est publique (port du jeu, relais de Cfx.re) :
           seules les requêtes venues de la machine elle-même, portant la clé posée par la Chancellerie à ce lancement,
           sont acceptées. Sans clé (serveur lancé sans la Chancellerie), le pont reste fermé.
    Dépendances : config.lua
]]

local type, select, byte, pairs, lower = type, select, string.byte, pairs, string.lower
local GetConvar = GetConvar

local cfg = VavaBridge.config
local HEADER = 'x-vava-token'
local LOOPBACK = { ['127.0.0.1'] = true, ['::1'] = true, ['::ffff:127.0.0.1'] = true }

local auth = {}
VavaBridge.auth = auth

---@return string
function auth.token()
    return GetConvar(cfg.convars.token, '')
end

---@return boolean
function auth.enabled()
    return #auth.token() >= cfg.tokenMin
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
    for key, value in pairs(headers) do
        if type(key) == 'string' and lower(key) == name then return value end
    end
    return nil
end

--- Requête du pont acceptée ?
---@param request table  requête de SetHttpHandler
---@return boolean
function auth.check(request)
    if not auth.enabled() or not auth.isLoopback(request.address) then return false end
    return same(header(request.headers, HEADER), auth.token())
end

auth.HEADER = HEADER
