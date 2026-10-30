--[[
    vava_arrival/shared/rules.lua
    Rôle : logique PURE de l'arrivée (aucune native, testée hors jeu : tests/spec/arrival_rules_spec.lua) : validation
           de la dotation, décision au chargement d'un personnage (première venue, ligne reprise, dotation
           incertaine), plan d'une apparition (dotation, accueil), limite du compte, écran prêt pour l'accueil,
           lecture de /accueil, textes d'état pour le Conseil.
    Dépendances : shared/constants.lua
]]

local type, pairs, tonumber, tostring = type, pairs, tonumber, tostring
local mathType, tointeger, floor = math.type, math.tointeger, math.floor
local format, find, match = string.format, string.find, string.match

local KIT = VavaArrival.KIT
local ID_PATTERN, MAX_ID = VavaArrival.ID_PATTERN, VavaArrival.MAX_ID
local MAX_KIT_ENTRIES, MAX_QUANTITY = VavaArrival.MAX_KIT_ENTRIES, VavaArrival.MAX_QUANTITY
local MAX_PLAYER = VavaArrival.MAX_PLAYER

-- états connus de la colonne `kit` ; un autre état lu en base est traité comme incertain
local KNOWN_STATES = {}
for _, state in pairs(KIT) do KNOWN_STATES[state] = true end

local ACTIONS = { etat = true, redoter = true, rejouer = true }

local rules = {}
VavaArrival.rules = rules

--- Vrai si `value` est une liste pure (clés 1..n sans trou, aucune autre clé ; `{}` en est une).
---@param value any
---@return boolean
local function isList(value)
    if type(value) ~= 'table' then return false end
    local count = 0
    for key in pairs(value) do
        if mathType(key) ~= 'integer' or key < 1 then return false end
        count = count + 1
    end
    return count == #value
end

--- Vrai si `value` est un identifiant du core (objet, chapitre du Codex).
---@param value any
---@return boolean
function rules.isId(value)
    return type(value) == 'string' and #value >= 1 and #value <= MAX_ID and find(value, ID_PATTERN) ~= nil
end

--- Valide la dotation de la config : liste pure de `{ item, quantity }`, 8 entrées au plus, quantités entières de 1 à
--- 100, un objet au plus une fois.
---@param items any
---@return boolean ok
---@return string|nil code  invalid_list | too_many | invalid_item | invalid_quantity | duplicate
function rules.validateKit(items)
    if not isList(items) then return false, 'invalid_list' end
    if #items > MAX_KIT_ENTRIES then return false, 'too_many' end
    local seen = {}
    for i = 1, #items do
        local entry = items[i]
        if type(entry) ~= 'table' or not rules.isId(entry.item) then return false, 'invalid_item' end
        local quantity = entry.quantity
        if mathType(quantity) ~= 'integer' or quantity < 1 or quantity > MAX_QUANTITY then return false, 'invalid_quantity' end
        if seen[entry.item] then return false, 'duplicate' end
        seen[entry.item] = true
    end
    return true
end

---@class vAvA.ArrivalLoad
---@field action 'create'|'ignore'|'resume'
---@field kit? string        état repris (resume)
---@field uncertain? boolean vrai : l'état lu (réservé, ou inconnu) passe à « incertaine »

--- Décision au chargement d'un personnage, d'après sa ligne en base et le temps de jeu mesuré par le core.
--- Sans ligne : nouveau personnage seulement si son temps de jeu est nul (sinon personnage ancien, rien à suivre).
--- Ligne lue « réservée » (serveur tombé pendant une dotation) ou d'un état inconnu : incertaine, jamais redonnée.
---@param row { kit: string }|nil
---@param playSeconds any
---@return vAvA.ArrivalLoad
function rules.onLoad(row, playSeconds)
    if row == nil then
        if playSeconds == 0 then return { action = 'create' } end
        return { action = 'ignore' }
    end
    local state = row.kit
    if state == KIT.CLAIMED or not KNOWN_STATES[state] then
        return { action = 'resume', kit = KIT.UNCERTAIN, uncertain = true }
    end
    return { action = 'resume', kit = state, uncertain = false }
end

--- Ce qu'une apparition déclenche pour une entrée en mémoire : la dotation (état « à donner ») et l'accueil (jamais vu,
--- moins de `maxSends` envois, pas déjà envoyé pendant cette session). Rien pendant une dotation en cours.
---@param entry { kit: string, welcomedAt?: integer, welcomeSends: integer, busy?: boolean, awaitingAck?: boolean }
---@param maxSends integer
---@return { kit: boolean, welcome: boolean }
function rules.plan(entry, maxSends)
    if entry.busy then return { kit = false, welcome = false } end
    local welcome = entry.welcomedAt == nil and not entry.awaitingAck and (entry.welcomeSends or 0) < maxSends
    return { kit = entry.kit == KIT.DUE, welcome = welcome }
end

--- Vrai si le compte a atteint sa limite de dotations (`max = 0` : aucune limite).
---@param count integer
---@param max integer
---@return boolean
function rules.capReached(count, max)
    return max > 0 and count >= max
end

--- Début de la fenêtre glissante de la limite du compte (secondes).
---@param now integer
---@param days number
---@return integer
function rules.capSince(now, days)
    return now - floor(days * 86400)
end

--- Vrai si l'écran est prêt pour l'accueil : ni menu pause, ni interface qui a le focus, écran ouvert (fondu fini).
---@param screen { paused: boolean, nuiFocused: boolean, fadedIn: boolean }
---@return boolean
function rules.welcomeReady(screen)
    return screen.paused ~= true and screen.nuiFocused ~= true and screen.fadedIn == true
end

--- Lit les arguments de /accueil : action (etat, redoter, rejouer) et numéro de joueur entier de 1 à 65 535.
---@param args any
---@return string|nil action
---@return integer|string player  numéro, ou 'usage'
function rules.parseCommand(args)
    if type(args) ~= 'table' then return nil, 'usage' end
    local action, raw = args[1], args[2]
    if not ACTIONS[action] or type(raw) ~= 'string' or not match(raw, '^%d+$') or #raw > 5 then return nil, 'usage' end
    local player = tointeger(tonumber(raw))
    if not player or player < 1 or player > MAX_PLAYER then return nil, 'usage' end
    return action, player
end

--- Date d'une ligne au format de la config (heure du serveur ; os.date lu ici seulement : le fichier est aussi chargé
--- par le client, qui n'en a pas besoin).
---@param at any
---@param dateFormat string
---@return string
local function date(at, dateFormat)
    if mathType(at) ~= 'integer' then return '?' end
    return os.date(dateFormat, at)
end

---@class vAvA.ArrivalRow
---@field kit string
---@field kitAt? integer
---@field welcomedAt? integer
---@field welcomeSends integer

--- Texte d'état de l'accueil d'un personnage pour le Conseil (/accueil etat), d'après sa ligne (ou son entrée en
--- mémoire) ; `row = nil` : personnage arrivé avant l'accueil.
---@param row vAvA.ArrivalRow|nil
---@param messages table  messages.admin de la config
---@param who { name: string, source: integer, characterId: integer }
---@return string
function rules.describe(row, messages, who)
    if row == nil then return format(messages.unknown, who.name, who.source, who.characterId) end
    local template = messages.kitStates[row.kit] or tostring(row.kit)
    local kitText = format(template, date(row.kitAt, messages.dateFormat))
    local welcomeText
    if row.welcomedAt ~= nil then
        welcomeText = format(messages.welcomeStates.seen, date(row.welcomedAt, messages.dateFormat))
    elseif (row.welcomeSends or 0) > 0 then
        welcomeText = format(messages.welcomeStates.pending, row.welcomeSends)
    else
        welcomeText = messages.welcomeStates.never
    end
    return format(messages.state, who.name, who.source, who.characterId, kitText, welcomeText)
end

--- Libellé d'un code de refus de la dotation pour le Conseil ; un code sans libellé est rendu tel quel.
---@param code any
---@param codes table<string, string>
---@return string
function rules.codeLabel(code, codes)
    return codes[code] or tostring(code)
end

