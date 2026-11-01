--[[
    vava_hud/shared/numbers.lua
    Rôle : règles pures des chiffres des coups (T-155) : arguments de hitText, montant mis en forme, texte et classes
           d'une issue, réglage du joueur, cascade, fenêtre d'une seconde, contrôle de la config. Aucune native.
    Dépendances : config_client.lua
]]

local type, pairs, ipairs, tostring = type, pairs, ipairs, tostring
local floor, huge, tointeger, mathType = math.floor, math.huge, math.tointeger, math.type
local format = string.format

local rules = {}
VavaHud.numberRules = rules

local SIDES = { dealt = true, taken = true }
local ISSUES = { hit = true, tick = true, stagger = true, down = true, block = true, ['break'] = true, parry = true,
    dodge = true, absorb = true }
local MODES = { tous = true, infliges = true, aucun = true }
local WORDS = { 'block', 'parry', 'dodge', 'absorb', 'break', 'stagger', 'down', 'none' }
local WORD_SET = {}
for _, key in ipairs(WORDS) do WORD_SET[key] = true end
local SIZE = { tick = 'small', stagger = 'big', down = 'huge' }
-- issues dont le mot va sous le chiffre ; seules, sans chiffre, elles sont un mot
local SUB = { block = 'block', ['break'] = 'break', stagger = 'stagger', down = 'down' }
local MAX_PLAYER, MAX_TENTHS = 65535, 2000
local MAX_XY, MAX_Z = 50000, 5000
local WORD_MAX = 32
local WINDOW_MS = 1000

rules.ISSUES = ISSUES

local function finite(value)
    return type(value) == 'number' and value == value and value ~= huge and value ~= -huge
end

--- Entier (ou flottant de valeur entière) de low à high, sinon nil.
local function integerIn(value, low, high)
    if not finite(value) then return nil end
    local int = tointeger(value)
    if not int or int < low or int > high then return nil end
    return int
end

function rules.player(value)
    return integerIn(value, 1, MAX_PLAYER)
end

function rules.tenths(value)
    return integerIn(value, 0, MAX_TENTHS)
end

--- Point fixe : { x =, y =, z = } ou { x, y, z } (tables pures), ou vector3 ; coordonnées finies et bornées.
function rules.point(value)
    local kind = type(value)
    local x, y, z
    if kind == 'vector3' then
        x, y, z = value.x, value.y, value.z
    elseif kind == 'table' then
        local count = 0
        for _ in pairs(value) do count = count + 1 end
        if count ~= 3 then return nil end
        if value[1] ~= nil then
            x, y, z = value[1], value[2], value[3]
        else
            x, y, z = value.x, value.y, value.z
        end
    else
        return nil
    end
    if not finite(x) or not finite(y) or not finite(z) then return nil end
    if x < -MAX_XY or x > MAX_XY or y < -MAX_XY or y > MAX_XY or z < -MAX_Z or z > MAX_Z then return nil end
    return x, y, z
end

--- Arguments de hitText : nil, ou le code de refus.
function rules.check(side, anchor, issue, tenths)
    if not SIDES[side] then return 'invalid_side' end
    if not rules.player(anchor) and not rules.point(anchor) then return 'invalid_anchor' end
    if type(issue) ~= 'string' or not ISSUES[issue] then return 'invalid_issue' end
    if tenths ~= nil and not rules.tenths(tenths) then return 'invalid_amount' end
    return nil
end

--- Montant affiché : decimals 0 → entier arrondi, au moins 1 dès que le coup porte ; 1 → « 7,2 ». 0 ou nil → nil.
function rules.format(tenths, decimals)
    if not tenths or tenths <= 0 then return nil end
    if decimals == 1 then
        local whole, rest = tenths // 10, tenths % 10
        if rest == 0 then return tostring(whole) end
        return format('%d,%d', whole, rest)
    end
    local value = floor(tenths / 10 + 0.5)
    if value < 1 then value = 1 end
    return tostring(value)
end

--- Texte, mot dessous et classes d'un chiffre (forme du message `number`).
function rules.compose(side, issue, tenths, cfg)
    local words = cfg.words
    local size = SIZE[issue]
    local value = nil
    if issue ~= 'parry' and issue ~= 'dodge' and issue ~= 'absorb' then value = rules.format(tenths, cfg.decimals) end
    local text, sub, word
    if value then
        text = value
        sub = SUB[issue] and words[SUB[issue]] or nil
    else
        text = words[SUB[issue] or issue] or words.none
        word = true
    end
    local cls = side
    if size then cls = cls .. ' ' .. size end
    if word then cls = cls .. ' word' end
    return { text = text, sub = sub, cls = cls }
end

--- Réglage du joueur : `tous`, `infliges` (donnés seulement), `aucun` ; inconnu → `default`.
function rules.allowed(mode, side, default)
    if not MODES[mode] then mode = default end
    if mode == 'tous' then return true end
    if mode == 'infliges' then return side == 'dealt' end
    return false
end

--- Cascade : un coup qui suit le précédent sur la même ancre de moins de `stackMs` monte d'un cran (côté alterné),
--- jusqu'à `stackMax` crans puis revient au premier. `random` rend un nombre de 0 à 1.
function rules.stack(last, now, cfg, random)
    local step = 0
    if last and now - last.at < cfg.stackMs then step = (last.step + 1) % cfg.stackMax end
    local sign = step % 2 == 1 and 1 or -1
    local jitter = (random() * 2 - 1) * cfg.jitterVw
    return { step = step, dx = sign * step * cfg.stackStepVw + jitter, dy = -step * cfg.stackStepVh },
        { at = now, step = step }
end

--- Fenêtre d'une seconde : vrai si un chiffre de plus est admis (et le compte), faux au-delà de `max`.
function rules.window(state, now, max)
    if now - state.at >= WINDOW_MS then state.at, state.count = now, 0 end
    if state.count >= max then return false end
    state.count = state.count + 1
    return true
end

local function between(value, low, high)
    return finite(value) and value >= low and value <= high
end

--- Contrôle de config.numbers au démarrage : nil, ou la raison.
function rules.checkConfig(n)
    if type(n) ~= 'table' then return 'numbers attendu (table)' end
    if type(n.enabled) ~= 'boolean' then return 'numbers.enabled attendu (booléen)' end
    if not MODES[n.defaultMode] then return "numbers.defaultMode : 'tous', 'infliges' ou 'aucun' attendu" end
    for _, b in ipairs({
        { 'durationMs', 400, 3000, true }, { 'riseVh', 0, 20 }, { 'maxAlive', 1, 30, true },
        { 'maxPerSecond', 1, 60, true }, { 'followMs', 50, 500, true }, { 'followEpsilon', 0, 0.1 },
        { 'stackMs', 0, 2000, true }, { 'stackMax', 1, 8, true }, { 'stackStepVh', 0, 10 }, { 'stackStepVw', 0, 10 },
        { 'jitterVw', 0, 5 }, { 'maxDistance', 1, 500 }, { 'headBone', 0, 65535, true }, { 'headOffset', -2, 2 },
        { 'decimals', 0, 1, true },
    }) do
        local value = n[b[1]]
        if not between(value, b[2], b[3]) or (b[4] and mathType(value) ~= 'integer') then
            return format('numbers.%s attendu de %s à %s', b[1], tostring(b[2]), tostring(b[3]))
        end
    end
    local fallback = n.takenFallback
    if type(fallback) ~= 'table' or not between(fallback.x, 0, 1) or not between(fallback.y, 0, 1) then
        return 'numbers.takenFallback : { x, y } de 0 à 1 attendu'
    end
    local words = n.words
    if type(words) ~= 'table' then return 'numbers.words attendu (table)' end
    for _, key in ipairs(WORDS) do
        local word = words[key]
        if type(word) ~= 'string' or #word < 1 or #word > WORD_MAX then
            return format('numbers.words.%s : texte de 1 à %d octets attendu', key, WORD_MAX)
        end
    end
    for key in pairs(words) do
        if not WORD_SET[key] then return format("numbers.words : clé inconnue '%s'", tostring(key)) end
    end
    return nil
end
