--[[
    vava_provisions/shared/texts.lua
    Rôle : textes montrés au joueur, logique PURE (aucune native, testée hors jeu : tests/spec/provisions_rules_spec.lua
           et provisions_client_view_spec.lua) : invite, action réussie, refus du serveur, avis (outre fendue, perdue),
           texte reçu coupé sans briser un caractère. Lus dans `messages` de config_client.lua, clé par clé (aucune
           table de la config passée en paramètre : le client ne reçoit que les textes qu'il montre). Partagé : le
           client s'en sert ; le serveur, pour couper un texte. Motifs écrits octet par octet (jamais %c : T-133).
    Dépendances : shared/constants.lua, config_client.lua
]]

local type, mathType = type, math.type
local tointeger, ceil, max, huge = math.tointeger, math.ceil, math.max, math.huge
local format, gsub, sub, byte = string.format, string.gsub, string.sub, string.byte
local utf8len = utf8.len

local ACTIONS = VavaProvisions.ACTIONS
local MAX_NOTIFICATION = VavaProvisions.MAX_NOTIFICATION
local messages = VavaProvisions.config.messages

-- caractères de contrôle ASCII, écrits octet par octet (jamais %c : T-133)
local CONTROL_PATTERN = '[\0-\31\127]'

local texts = {}
VavaProvisions.texts = texts

---@param value any
---@return boolean
local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Texte coupé à `maxBytes` octets sans briser un caractère UTF-8, contrôles remplacés par une espace ; nil si vide
--- ou si ce n'est pas un texte.
---@param value any
---@param maxBytes integer
---@return string|nil
function texts.cutText(value, maxBytes)
    if type(value) ~= 'string' then return nil end
    local text = gsub(value, CONTROL_PATTERN, ' ')
    if #text > maxBytes then
        local cut = maxBytes
        -- recule tant que l'octet suivant la coupe est un octet de suite (10xxxxxx) : le caractère entier part
        while cut > 0 and (byte(text, cut + 1) or 0) >= 0x80 and (byte(text, cut + 1) or 0) < 0xC0 do cut = cut - 1 end
        text = sub(text, 1, cut)
    end
    if utf8len(text) == nil then return nil end
    text = gsub(gsub(text, '^ +', ''), ' +$', '')
    if text == '' then return nil end
    return text
end

--- Minutes d'attente annoncées (arrondies au-dessus, au moins 1).
---@param seconds any
---@return integer
function texts.dryMinutes(seconds)
    if not finite(seconds) or seconds <= 0 then return 1 end
    return max(1, tointeger(ceil(seconds / 60)) or 1)
end

--- Texte d'un refus de la besace (codes du serveur), ou nil pour toute autre valeur.
---@param code any
---@return string|nil
local function bagRefusal(code)
    if code == 'no_space' then return messages.noSpace end
    if code == 'too_heavy' then return messages.tooHeavy end
    return nil
end

--- Texte d'une action réussie (réponse du RPC), ou nil.
---@param result any  { action = 'fill', count } | { action = 'drink', dry, blocked? }
---@return string|nil
function texts.successText(result)
    if type(result) ~= 'table' then return nil end
    if result.action == ACTIONS.FILL then
        local count = mathType(result.count) == 'integer' and result.count or 1
        if count <= 1 then return messages.filledOne end
        return format(messages.filledMany, count)
    end
    if result.action == ACTIONS.DRINK then
        -- remplissage refusé par la besace : on a bu sur place à la place ; les deux textes, l'un après l'autre
        local blocked = bagRefusal(result.blocked)
        if blocked then return blocked .. ' ' .. messages.drank end
        return result.dry == true and messages.drankDry or messages.drank
    end
    return nil
end

--- Texte d'un refus du serveur, ou nil quand il n'y a rien à dire (sans personnage, à terre, occupé, point inconnu).
--- `dry` : texte de la sorte avec les minutes d'attente ; `refused` : raison du hook, coupée à 200 octets.
---@param code any
---@param extra any       secondes (dry), raison (refused)
---@param kind table|nil  sorte du point (dry)
---@return string|nil
function texts.refusalText(code, extra, kind)
    if code == 'dry' then
        if type(kind) ~= 'table' or type(kind.dry) ~= 'string' then return messages.unavailable end
        return format(kind.dry, texts.dryMinutes(extra))
    end
    if code == 'refused' then return texts.cutText(extra, MAX_NOTIFICATION) end
    if code == 'wait' then return messages.wait end
    if code == 'too_far' then return messages.tooFar end
    if code == 'not_thirsty' then return messages.notThirsty end
    if code == 'no_container' then return messages.noContainer end
    if code == 'unavailable' then return messages.unavailable end
    return bagRefusal(code)
end

--- Texte d'un avis du serveur (outre fendue, perdue), ou nil pour toute autre valeur.
---@param code any
---@return string|nil
function texts.noticeText(code)
    if code == 'torn' then return messages.torn end
    if code == 'lost' then return messages.lost end
    return nil
end

--- Verbe de l'invite selon la sorte : on y boit (« Puiser ou boire »), ou on n'y fait que puiser.
---@param kind table|nil
---@return string
function texts.promptVerb(kind)
    if type(kind) == 'table' and kind.drink == true then return messages.prompt.both end
    return messages.prompt.fill
end
