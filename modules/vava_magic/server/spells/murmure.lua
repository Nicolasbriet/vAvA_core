--[[
    vava_magic/server/spells/murmure.lua
    Rôle : sort Murmure (messages texte, remplace le courrier rapide), décidé par le serveur.
      - Début : contacts choisis dans la liste du lanceur (cercle selon le niveau), message nettoyé et tronqué en
        signes UTF-8, position jointe dès le niveau 3. Le serveur tire les fragments (mots montrés au-dessus des
        mains) et la déformation (mots arrivés en « … ») selon le niveau.
      - Pendant l'incantation : fragments envoyés aux seuls joueurs à moins de 3 m (positions serveur, revues
        toutes les 500 ms) ; au-delà, les runes du state bag d'incantation restent indéchiffrables.
      - Fin : chaque destinataire en jeu et à portée reçoit le message (nom du contact s'il connaît le sigil du
        lanceur, sinon « présence inconnue ») et ses yeux s'illuminent ; injoignable : hook
        `vava_magic:murmur:unreachable` (un autre module peut s'en charger), sinon le lien reste silencieux et une part
        de la mana revient. Archivé dans le registre que porte chacun.
    Dépendances : shared/, config.lua, server/ (noyau)
]]

local ipairs, tostring = ipairs, tostring
local floor, random, max = math.floor, math.random, math.max
local concat = table.concat
local CreateThread, Wait, SetTimeout, TriggerClientEvent, GetGameTimer = CreateThread, Wait, SetTimeout, TriggerClientEvent, GetGameTimer

local core = VavaMagic.core
local bridge = VavaMagic.bridge
local world = VavaMagic.world
local sheets = VavaMagic.sheets
local casting = VavaMagic.casting
local registers = VavaMagic.registers
local text = VavaMagic.text
local geometry = VavaMagic.geometry
local cfg = VavaMagic.config
local spellCfg = cfg.spells.murmure
local ambient = cfg.ambient
local notify = cfg.texts.notify
local EVENTS = VavaMagic.EVENTS
local STATES = VavaMagic.STATES
local HOOKS = VavaMagic.HOOKS
local DIRECTION = VavaMagic.DIRECTION
local NAME = 'murmure'
local HIDDEN_WORD = '…'
-- revue des joueurs proches pendant l'incantation
local FRAGMENTS_POLL_MS = 500
local HANDLED = 'handled'

local MAX_CIRCLE = 1
for _, level in ipairs(spellCfg.levels) do MAX_CIRCLE = max(MAX_CIRCLE, level.circle) end

---@type table<integer, integer>  joueur → jeton de ses yeux illuminés (le dernier murmure reçu l'emporte)
local glowTokens = {}

--- Rangs de mots tirés au hasard (dans l'ordre du message).
---@param count integer
---@param total integer
---@return table<integer, boolean>
local function pick(count, total)
    local chosen, taken = {}, 0
    while taken < count do
        local index = random(1, total)
        if not chosen[index] then
            chosen[index] = true
            taken = taken + 1
        end
    end
    return chosen
end

--- Mots montrés au-dessus des mains selon le niveau.
---@param words string[]
---@param levelCfg table
---@return string[]
local function fragmentsOf(words, levelCfg)
    local total = #words
    if total == 0 or levelCfg.fragmentShare <= 0 or levelCfg.fragmentMax <= 0 then return {} end
    local count = floor(total * levelCfg.fragmentShare + 0.5)
    if count < 1 then count = 1 end
    if count > levelCfg.fragmentMax then count = levelCfg.fragmentMax end
    if count > total then count = total end
    local chosen = pick(count, total)
    local list = {}
    for index, word in ipairs(words) do
        if chosen[index] then list[#list + 1] = word end
    end
    return list
end

--- Message tel qu'il arrive : chaque mot a une chance de se perdre.
---@param words string[]
---@param distortion number
---@return string
local function distort(words, distortion)
    local out = {}
    for index, word in ipairs(words) do
        out[index] = (distortion > 0 and random() < distortion) and HIDDEN_WORD or word
    end
    return text.join(out)
end

--- Pendant l'incantation : fragments aux joueurs à moins de 3 m, chacun une fois.
---@param src integer
---@param data table
local function spreadFragments(src, data)
    CreateThread(function()
        Wait(0)
        local cast = casting.current(src)
        if not cast or cast.data ~= data then return end
        local sent = {}
        while casting.current(src) == cast and not cast.finishing do
            local position = world.position(src)
            if position then
                local left = cast.durationMs - (GetGameTimer() - cast.startedAt)
                local nearby = world.near(position, ambient.fragmentDistance)
                nearby[#nearby + 1] = { source = src }
                for _, entry in ipairs(nearby) do
                    if not sent[entry.source] then
                        sent[entry.source] = true
                        TriggerClientEvent(EVENTS.FRAGMENTS, entry.source, src, cast.id, data.fragments, left > 0 and left or 0)
                    end
                end
            end
            Wait(FRAGMENTS_POLL_MS)
        end
    end)
end

--- Ses yeux s'illuminent un bref instant (vu des joueurs proches).
---@param target integer
local function glow(target)
    local token = (glowTokens[target] or 0) + 1
    glowTokens[target] = token
    world.setState(target, STATES.GLOW, true)
    SetTimeout(ambient.glowMs, function()
        if glowTokens[target] == token then
            glowTokens[target] = nil
            world.setState(target, STATES.GLOW, nil)
        end
    end)
end

---@param ctx table
---@param targets integer[]  rangs dans la liste de contacts du lanceur
---@param message string
---@param sharePosition boolean
local function begin(ctx, targets, message, sharePosition)
    local sheet = sheets.get(ctx.source)
    local levelCfg = spellCfg.levels[ctx.level]
    if #targets > levelCfg.circle then return false, 'too_many_targets' end
    local recipients, seen = {}, {}
    for _, index in ipairs(targets) do
        local contact = sheet.sigils[index]
        if not contact then return false, 'unknown_sigil' end
        if not seen[contact.sigil] then
            seen[contact.sigil] = true
            recipients[#recipients + 1] = { sigil = contact.sigil, name = contact.name }
        end
    end
    local cleaned = text.clean(message)
    if not cleaned then return false, 'invalid' end
    if cleaned == '' then return false, 'empty_message' end
    if sharePosition and not levelCfg.waypoint then return false, 'no_waypoint' end
    local body = text.truncate(cleaned, levelCfg.maxLength)
    local words = text.words(body)
    local data = {
        recipients = recipients, text = body, received = distort(words, levelCfg.distortion),
        sharePosition = sharePosition == true, fragments = fragmentsOf(words, levelCfg),
    }
    spreadFragments(ctx.source, data)
    return true, data
end

--- Un destinataire injoignable : un autre module peut s'en charger (pigeon, relais…). Renvoie vrai s'il le fait.
---@param ctx table
---@param reason string  'offline' ou 'too_far'
---@param recipient table
---@return boolean
local function handledElsewhere(ctx, reason, recipient)
    local allowed, answer = core.hooks.runBefore(HOOKS.UNREACHABLE, {
        source = ctx.source, characterId = ctx.characterId, reason = reason, sigil = recipient.sigil, text = ctx.data.text,
    })
    return allowed == false and answer == HANDLED
end

---@param ctx table
local function finish(ctx)
    local src, data = ctx.source, ctx.data
    local sender = sheets.get(src)
    local position = world.position(src)
    if not sender or not position then return false, 'no_position' end
    local levelCfg = spellCfg.levels[ctx.level]
    local waypoint = data.sharePosition and { x = position.x, y = position.y } or nil
    local delivered, tooFar, silent = 0, 0, 0
    local names = {}
    for _, recipient in ipairs(data.recipients) do
        local target = sheets.sourceOf(recipient.sigil)
        local reason = nil
        local targetPosition = target and bridge.GetCharacterId(target) and world.position(target)
        if not targetPosition then
            reason = 'offline'
        elseif levelCfg.range > 0 and geometry.distance(position, targetPosition) > levelCfg.range then
            reason = 'too_far'
        end
        if reason then
            if handledElsewhere(ctx, reason, recipient) then
                delivered = delivered + 1
                names[#names + 1] = recipient.name
            elseif reason == 'too_far' then
                tooFar = tooFar + 1
            else
                silent = silent + 1
            end
        else
            local receiverSheet = sheets.get(target)
            local index = receiverSheet and sheets.contactIndex(receiverSheet, sender.sigil)
            local from = index and receiverSheet.sigils[index].name or nil
            TriggerClientEvent(EVENTS.MURMUR, target, { from = from, text = data.received, waypoint = waypoint })
            glow(target)
            -- présence inconnue : contact vide, que le registre affiche à sa façon
            CreateThread(function() registers.archive(target, DIRECTION.RECEIVED, from or '', data.received) end)
            delivered = delivered + 1
            names[#names + 1] = recipient.name
        end
    end

    local total = #data.recipients
    local failed = tooFar + silent
    if delivered > 0 then
        CreateThread(function() registers.archive(src, DIRECTION.SENT, concat(names, ', '), data.text) end)
    end
    local share = failed > 0 and spellCfg.refundShare * failed / total or 0
    local message
    if failed == 0 then
        message = notify.murmurDelivered
    elseif delivered > 0 then
        message = notify.murmurPartial:format(delivered, total)
    else
        message = silent > 0 and notify.murmurSilent or notify.murmurTooFar
    end
    if share > 0 then message = message .. ' ' .. notify.refund:format(floor(ctx.cost * share + 0.5)) end
    bridge.Notify(src, message, delivered > 0 and 'success' or 'warning')
    return { success = delivered > 0, refund = share }
end

local ok, err = VavaMagic.spells.register(NAME, {
    config = spellCfg,
    beginArgs = {
        { type = 'array', min = 1, max = MAX_CIRCLE, items = { type = 'integer', min = 1, max = sheets.SIGILS_MAX } },
        { type = 'string', min = 1, max = spellCfg.textMaxBytes },
        { type = 'boolean' },
    },
    finishArgs = {},
    begin = begin,
    finish = finish,
})
if not ok then VavaMagic.log.error('Murmure non déclaré : %s', tostring(err)) end
