--[[
    vava_skills/server/progression.lua
    Rôle : la progression décidée par le serveur. Un module métier appelle `addXp` avec un contexte (compétence, action,
           difficulté, XP de base) ; ici s'appliquent le mode de la compétence (seule `up` progresse), la présence du
           mentor pour les savoirs `mentoredOnly` (Arcanes), les rendements décroissants, la pénurie, le bonus de
           mentorat et la Renommée du maître, puis le passage de niveau sous le plafond : savoir commun libre, budget de
           points au-delà, rouille (un point gagné en `up` en retire un à une compétence `down`). Changement de mode,
           correction d'un niveau par le Conseil. Hooks `vava_skills:xp` (before annulable, after) et
           `vava_skills:levelChanged` ; évènement `vava_skills:skill` au seul joueur concerné.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/journal.lua, server/registries.lua,
                  server/sheets.lua, server/shortages.lua ; server/mentoring.lua (lié à l'exécution)
]]

local type, pairs = type, pairs
local mathType, floor, min, max, random = math.type, math.floor, math.min, math.max, math.random
local format = string.format
local TriggerClientEvent, GetGameTimer = TriggerClientEvent, GetGameTimer
local time = os.time

local core = VavaSkills.core
local bridge = VavaSkills.bridge
local journal = VavaSkills.journal
local registries = VavaSkills.registries
local sheets = VavaSkills.sheets
local shortages = VavaSkills.shortages
local rules = VavaSkills.progression
local cfg = VavaSkills.config
local xpCfg, levelCfg, messages = cfg.xp, cfg.levels, cfg.messages
local EVENTS = VavaSkills.EVENTS
local MODES = VavaSkills.MODES

local HOOK_XP = 'vava_skills:xp'
local HOOK_LEVEL = 'vava_skills:levelChanged'
-- une même remarque (verrouillée, sans maître, plafond) n'est répétée au joueur qu'au bout de ce délai
local NOTICE_THROTTLE_MS = 30000

local UPSERT_LEVEL_SQL = 'INSERT INTO `vava_skills_skills` (`character_id`, `skill`, `level`, `xp`, `updated_at`) VALUES (?, ?, ?, 0, ?) '
    .. 'ON DUPLICATE KEY UPDATE `level` = VALUES(`level`), `xp` = 0, `updated_at` = VALUES(`updated_at`)'

local progression = {}
VavaSkills.experience = progression

-- source → { [compétence .. motif] = GetGameTimer de la dernière remarque }
local notices = {}

local function mentoring()
    return VavaSkills.mentoring
end

---@param src integer
---@param skill string
---@param reason string
---@return boolean
local function noticeAllowed(src, skill, reason)
    local bySrc = notices[src]
    if not bySrc then
        bySrc = {}
        notices[src] = bySrc
    end
    local key = skill .. reason
    local now = GetGameTimer()
    if bySrc[key] and now - bySrc[key] < NOTICE_THROTTLE_MS then return false end
    bySrc[key] = now
    return true
end

--- Envoie au joueur la vue à jour d'une compétence et son budget.
---@param sheet vAvA.SkillSheet
---@param skill string
function progression.push(sheet, skill)
    local view = sheets.skillView(sheet, skill)
    if view then TriggerClientEvent(EVENTS.SKILL, sheet.source, { skill = view, budget = sheets.budget(sheet) }) end
end

---@param sheet vAvA.SkillSheet
---@param skill string
---@param from integer
---@param to integer
---@param reason string
local function levelChanged(sheet, skill, from, to, reason)
    core.hooks.runAfter(HOOK_LEVEL, {
        source = sheet.source, characterId = sheet.characterId, skill = skill, from = from, to = to,
        rank = rules.rankOf(to).name, reason = reason,
    })
end

--- Compétence `down` qui paie le point gagné ailleurs, selon `rust.pick` ; nil s'il n'y en a aucune au-dessus du
--- savoir commun. À clés égales, l'ordre alphabétique départage : le choix ne dépend pas du parcours d'une table.
---@param sheet vAvA.SkillSheet
---@param except string
---@return string|nil
local function pickVictim(sheet, except)
    local pick = cfg.rust.pick
    local best, bestKey
    for skill, entry in pairs(sheet.skills) do
        if skill ~= except and entry.mode == 'down' and entry.level > levelCfg.commonKnowledge then
            local key
            if pick == 'recent' then key = entry.practicedAt
            elseif pick == 'random' then key = random()
            else key = entry.level end
            if not best or key > bestKey or (key == bestKey and skill < best) then best, bestKey = skill, key end
        end
    end
    return best
end

--- Tente un passage de niveau. Au-delà du savoir commun et du budget, une compétence `down` perd un point (rouille) ;
--- sans victime, le passage est refusé (`cap`).
---@param sheet vAvA.SkillSheet
---@param skill string
---@param entry vAvA.SkillEntry
---@return boolean ok
---@return string|nil blocked  max | cap
local function levelUp(sheet, skill, entry)
    if entry.level >= levelCfg.max then return false, 'max' end
    local newLevel = entry.level + 1
    if newLevel > levelCfg.commonKnowledge and rules.budgetUsed(sheet.skills) >= levelCfg.budget then
        local victim = pickVictim(sheet, skill)
        if not victim then return false, 'cap' end
        local lost = sheet.skills[victim]
        local before = lost.level
        lost.level, lost.xp = before - 1, 0
        sheets.touch(lost)
        journal.write('rust', { actorId = sheet.characterId, targetId = sheet.characterId, skill = victim, details = { from = before, to = lost.level, gained = skill } })
        bridge.Notify(sheet.source, format(messages.rusted, registries.skillLabel(victim), lost.level), 'warning')
        progression.push(sheet, victim)
        levelChanged(sheet, victim, before, lost.level, 'rust')
    end
    entry.level = newLevel
    return true
end

---@class vAvA.XpContext
---@field skill string
---@field source? string      action à l'origine (récolte, recette…), libre
---@field difficulty? integer difficulté de l'action (0 à 100) ; par défaut le niveau du joueur (plein rendement)
---@field amount? integer     XP de base (défaut config.xp.defaultAmount)

--- Ajoute de l'XP à une compétence d'un joueur, avec toutes les règles. Renvoie `true, résultat` même quand rien
--- n'est gagné (`blocked` explique : locked, no_master, cap, max) ; `false, code` sur une demande invalide.
---@param src integer
---@param ctx vAvA.XpContext
---@return boolean ok
---@return table|string result  { gained, level, rank, leveledUp, blocked? }
function progression.addXp(src, ctx)
    local sheet = sheets.get(src)
    if not sheet then return false, 'no_character' end
    if type(ctx) ~= 'table' then return false, 'invalid_context' end
    local def = registries.skill(ctx.skill)
    if not def then return false, 'unknown_skill' end
    local amount = ctx.amount == nil and xpCfg.defaultAmount or ctx.amount
    if mathType(amount) ~= 'integer' or amount < 0 or amount > xpCfg.maxPerAction then return false, 'invalid_amount' end
    local entry = sheets.entry(sheet, def.id, true)
    local difficulty = ctx.difficulty == nil and entry.level or ctx.difficulty
    if mathType(difficulty) ~= 'integer' or difficulty < 0 or difficulty > levelCfg.max then return false, 'invalid_difficulty' end

    local function blocked(reason, message, kind)
        if message and noticeAllowed(src, def.id, reason) then bridge.Notify(src, message, kind or 'info') end
        return true, { gained = 0, level = entry.level, rank = rules.rankOf(entry.level).name, leveledUp = 0, blocked = reason }
    end

    if entry.mode ~= 'up' then return blocked('locked', format(messages.locked, def.label)) end
    local mentorship, masterSheet
    if def.mentoredOnly then
        mentorship = sheet.mentors[def.id]
        masterSheet = mentorship and mentoring().masterNearby(mentorship, cfg.arcanes.masterRadius)
        if not masterSheet then
            journal.write('arcanes_blocked', { actorId = sheet.characterId, skill = def.id, details = { action = ctx.source } })
            return blocked('no_master', format(messages.noMaster, def.label), 'warning')
        end
    end
    local payload = { source = src, characterId = sheet.characterId, skill = def.id, action = ctx.source, difficulty = difficulty, amount = amount }
    local allowed, reason = core.hooks.runBefore(HOOK_XP, payload)
    if not allowed then return false, (type(reason) == 'string' and reason ~= 'hook_error') and reason or 'refused' end
    -- le hook a pu céder la main : le personnage doit toujours être là
    if sheets.get(src) ~= sheet then return false, 'no_character' end

    local factor = rules.diminishing(entry.level, difficulty) * (shortages.multiplier(def.id) or 1.0)
    local bonusMentorship, bonusMaster = mentoring().bonusFor(sheet, def.id)
    if bonusMentorship then factor = factor * (1.0 + cfg.mentoring.bonus) end
    local gained = amount > 0 and max(1, floor(amount * factor + 0.5)) or 0
    gained = min(gained, xpCfg.maxGainPerAction)

    local before = entry.level
    local leveledUp, stop = 0, nil
    entry.xp = entry.xp + gained
    while entry.xp >= rules.xpToNext(entry.level) do
        local need = rules.xpToNext(entry.level)
        local ok, why = levelUp(sheet, def.id, entry)
        if not ok then
            -- plafond ou maximum : l'XP se fige sous le seuil, rien n'est perdu
            entry.xp, stop = need - 1, why
            break
        end
        entry.xp = entry.xp - need
        leveledUp = leveledUp + 1
    end
    entry.practicedAt = time()
    sheets.touch(entry)

    if bonusMentorship and gained > 0 then mentoring().onApprenticeXp(bonusMentorship, bonusMaster, def.id, gained) end

    if leveledUp > 0 then
        local rankBefore, rankAfter = rules.rankOf(before), rules.rankOf(entry.level)
        if rankAfter ~= rankBefore then
            bridge.Notify(src, format(messages.rankUp, def.label, rankAfter.label), 'info')
        else
            bridge.Notify(src, format(messages.levelUp, def.label, entry.level), 'info')
        end
        levelChanged(sheet, def.id, before, entry.level, 'xp')
    end
    if stop == 'cap' and noticeAllowed(src, def.id, 'cap') then bridge.Notify(src, messages.capReached, 'warning') end
    progression.push(sheet, def.id)

    payload.gained, payload.level, payload.leveledUp, payload.blocked = gained, entry.level, leveledUp, stop
    core.hooks.runAfter(HOOK_XP, payload)
    return true, { gained = gained, level = entry.level, rank = rules.rankOf(entry.level).name, leveledUp = leveledUp, blocked = stop }
end

--- Change le mode de rouille d'une compétence (geste du joueur).
---@param src integer
---@param skill any
---@param mode any
---@return boolean ok
---@return table|string result  vue de la compétence
---@return table|nil budget
function progression.setMode(src, skill, mode)
    local sheet = sheets.get(src)
    if not sheet then return false, 'no_character' end
    local def = registries.skill(skill)
    if not def then return false, 'unknown_skill' end
    if not MODES[mode] then return false, 'invalid_mode' end
    local entry = sheets.entry(sheet, def.id, true)
    if entry.mode ~= mode then
        entry.mode = mode
        sheets.touch(entry)
    end
    return true, sheets.skillView(sheet, def.id), sheets.budget(sheet)
end

--- Fixe le niveau d'une compétence (Conseil, fondateur) : XP du niveau remise à zéro, journal, joueur prévenu s'il
--- est en jeu ; un personnage hors ligne est écrit directement en base (bloque le thread).
---@param characterId integer
---@param skill string
---@param level integer
---@param reason 'founder'|'admin_set'
---@param actor { source?: integer, characterId?: integer, accountId?: integer }
---@return boolean ok
---@return string|nil err
function progression.setLevel(characterId, skill, level, reason, actor)
    local def = registries.skill(skill)
    if not def then return false, 'unknown_skill' end
    if mathType(level) ~= 'integer' or level < 0 or level > levelCfg.max then return false, 'invalid_level' end
    local sheet = sheets.byCharacter(characterId)
    local from
    if sheet then
        local entry = sheets.entry(sheet, def.id, true)
        from = entry.level
        entry.level, entry.xp = level, 0
        sheets.touch(entry)
        progression.push(sheet, def.id)
        levelChanged(sheet, def.id, from, level, reason)
        bridge.Notify(sheet.source, format(messages.levelUp, def.label, level), 'info')
    else
        local _, err = bridge.db.update(UPSERT_LEVEL_SQL, { characterId, def.id, level, time() })
        if err then return false, 'db_error' end
    end
    journal.write(reason, {
        actorId = actor.characterId, accountId = actor.accountId, targetId = characterId, skill = def.id,
        details = { from = from, to = level },
    })
    return true
end

--- Joueur parti : ses remarques limitées sont oubliées.
---@param src integer
function progression.forget(src)
    notices[src] = nil
end
