--[[
    vava_skills/server/mentoring.lua
    Rôle : mentorat. Un Maître propose (joueur à portée, comptes différents, temps de jeu suffisant, places libres),
           l'apprenti accepte dans le délai ; chacun peut rompre. L'apprenti gagne un bonus d'XP quand il pratique près
           de son maître qui a lui-même pratiqué récemment ; le maître en tire de la Renommée (part de l'XP, plafond
           journalier, rendement décroissant sur un même apprenti). Les propositions vivent en mémoire et expirent ;
           les mentorats sont écrits aussitôt (début, fin) et leurs compteurs par lots avec les fiches. Hook
           `vava_skills:mentorship` (after : started | ended) ; évènements et notifications aux deux parties.
    Dépendances : shared/, config.lua, server/core.lua, bridge/server.lua, server/journal.lua, server/registries.lua,
                  server/sheets.lua
]]

local pairs, ipairs, tostring = pairs, ipairs, tostring
local mathType, floor, min = math.type, math.floor, math.min
local format = string.format
local TriggerClientEvent, GetGameTimer, SetTimeout = TriggerClientEvent, GetGameTimer, SetTimeout
local time = os.time

local core = VavaSkills.core
local bridge = VavaSkills.bridge
local journal = VavaSkills.journal
local registries = VavaSkills.registries
local sheets = VavaSkills.sheets
local rules = VavaSkills.progression
local cfg = VavaSkills.config.mentoring
local messages = VavaSkills.config.messages
local EVENTS = VavaSkills.EVENTS

local HOOK = 'vava_skills:mentorship'
local INSERT_SQL = 'INSERT INTO `vava_skills_mentorships` (`skill`, `master_id`, `apprentice_id`, `started_at`) VALUES (?, ?, ?, ?)'
local END_SQL = 'UPDATE `vava_skills_mentorships` SET `ended_at` = ?, `ended_by` = ? WHERE `id` = ? AND `ended_at` IS NULL'
local END_ALL_SQL = 'UPDATE `vava_skills_mentorships` SET `ended_at` = ?, `ended_by` = ? WHERE `ended_at` IS NULL AND (`master_id` = ? OR `apprentice_id` = ?)'
local COUNTERS_SQL = 'UPDATE `vava_skills_mentorships` SET `xp_granted` = ?, `renown_granted` = ? WHERE `id` = ?'

local mentoring = {}
VavaSkills.mentoring = mentoring

---@class vAvA.MentorProposal
---@field id integer
---@field masterSrc integer
---@field masterId integer
---@field apprenticeSrc integer
---@field apprenticeId integer
---@field skill string
---@field expiresAt integer  GetGameTimer

---@type table<integer, vAvA.MentorProposal>
local proposals = {}
local lastProposalId = 0
-- mentorats dont les compteurs ont changé depuis la dernière écriture
---@type table<integer, vAvA.Mentorship>
local dirty = {}

---@param src integer
---@param payload table
local function push(src, payload)
    TriggerClientEvent(EVENTS.MENTORSHIP, src, payload)
end

-- Conditions -------------------------------------------------------------------------------------------------------

--- Vrai si la fiche peut proposer un mentorat (et enseigner une leçon) dans cette compétence : rang et temps de jeu.
---@param sheet vAvA.SkillSheet
---@param skill string
---@return boolean
function mentoring.canMentor(sheet, skill)
    return rules.hasRank(sheets.level(sheet, skill), cfg.minRank) and bridge.GetPlaySeconds(sheet.source) >= cfg.minTeachPlaySeconds
end

---@param sheet vAvA.SkillSheet
---@param skill string
---@return integer
local function apprenticeCount(sheet, skill)
    local count = 0
    for _ in pairs(sheet.apprentices[skill] or {}) do count = count + 1 end
    return count
end

--- Fiche du maître d'un mentorat s'il est en jeu à moins de `radius` m de l'apprenti, sinon nil.
---@param mentorship vAvA.Mentorship
---@param radius number
---@return vAvA.SkillSheet|nil
function mentoring.masterNearby(mentorship, radius)
    local master = sheets.byCharacter(mentorship.masterId)
    local apprentice = sheets.byCharacter(mentorship.apprenticeId)
    if not master or not apprentice then return nil end
    if not bridge.Within(master.source, apprentice.source, radius) then return nil end
    return master
end

--- Mentorat qui bonifie la pratique de l'apprenti : maître à portée, ayant lui-même pratiqué récemment.
---@param sheet vAvA.SkillSheet
---@param skill string
---@return vAvA.Mentorship|nil mentorship
---@return vAvA.SkillSheet|nil master
function mentoring.bonusFor(sheet, skill)
    local mentorship = sheet.mentors[skill]
    if not mentorship then return nil end
    local master = mentoring.masterNearby(mentorship, cfg.radius)
    if not master then return nil end
    local entry = master.skills[skill]
    if not entry or time() - entry.practicedAt > cfg.recentMs // 1000 then return nil end
    return mentorship, master
end

--- L'apprenti a gagné de l'XP bonifiée : compteur du mentorat, Renommée du maître (part, plafond du jour UTC,
--- divisée par deux tous les `halfEvery` points déjà rapportés par cet apprenti).
---@param mentorship vAvA.Mentorship
---@param master vAvA.SkillSheet
---@param skill string
---@param gained integer
function mentoring.onApprenticeXp(mentorship, master, skill, gained)
    mentorship.xpGranted = mentorship.xpGranted + gained
    dirty[mentorship.id] = mentorship
    local renown = cfg.renown
    local entry = sheets.entry(master, skill, true)
    local today = sheets.dayOf(time())
    if entry.renownDay ~= today then
        entry.renownDay, entry.renownDayGained = today, 0
    end
    local halving = 2 ^ (mentorship.pairRenown // renown.halfEvery)
    local amount = floor(gained * renown.share / halving)
    amount = min(amount, renown.dailyCap - entry.renownDayGained)
    if amount <= 0 then
        sheets.touch(entry)
        return
    end
    entry.renown = entry.renown + amount
    entry.renownDayGained = entry.renownDayGained + amount
    mentorship.renownGranted = mentorship.renownGranted + amount
    mentorship.pairRenown = mentorship.pairRenown + amount
    sheets.touch(entry)
    VavaSkills.experience.push(master, skill)
end

-- Propositions -----------------------------------------------------------------------------------------------------

--- Joueurs à portée de proposition : { serverId, name, distance }.
---@param src integer
---@return table[]
function mentoring.nearby(src)
    local list = {}
    for _, other in ipairs(bridge.ActivePlayers()) do
        if other ~= src then
            local distance = bridge.Distance(src, other)
            if distance and distance <= cfg.proposalRadius then
                list[#list + 1] = { serverId = other, name = bridge.GetCharacterName(other) or ('Joueur ' .. other), distance = floor(distance * 10) / 10 }
            end
        end
    end
    return list
end

---@param src integer
---@return table[]
function mentoring.proposalsFor(src)
    local list = {}
    local now = GetGameTimer()
    for _, proposal in pairs(proposals) do
        if proposal.apprenticeSrc == src then
            list[#list + 1] = {
                id = proposal.id, masterName = bridge.GetCharacterName(proposal.masterSrc) or '?', masterCharacterId = proposal.masterId,
                skill = proposal.skill, skillLabel = registries.skillLabel(proposal.skill), expiresInMs = proposal.expiresAt - now,
            }
        end
    end
    return list
end

---@param proposal vAvA.MentorProposal
---@param reason 'expired'|'declined'|'gone'
local function dropProposal(proposal, reason)
    if proposals[proposal.id] ~= proposal then return end
    proposals[proposal.id] = nil
    local label = registries.skillLabel(proposal.skill)
    local apprenticeName = bridge.GetCharacterName(proposal.apprenticeSrc) or '?'
    if reason == 'expired' then
        bridge.Notify(proposal.masterSrc, format(messages.proposalExpired, apprenticeName), 'info')
        push(proposal.apprenticeSrc, { action = 'expired', skill = proposal.skill, skillLabel = label, role = 'apprentice',
            other = { characterId = proposal.masterId, name = bridge.GetCharacterName(proposal.masterSrc) or '?' } })
    end
end

--- Un Maître propose un mentorat à un joueur proche.
---@param src integer
---@param targetSrc any
---@param skill any
---@return boolean ok
---@return string|nil code
function mentoring.propose(src, targetSrc, skill)
    local sheet = sheets.get(src)
    if not sheet then return false, 'no_character' end
    local def = registries.skill(skill)
    if not def then return false, 'unknown_skill' end
    if mathType(targetSrc) ~= 'integer' or targetSrc == src then return false, 'self' end
    local target = sheets.get(targetSrc)
    if not target then return false, 'no_target' end
    if not rules.hasRank(sheets.level(sheet, def.id), cfg.minRank) then return false, 'not_master' end
    if bridge.GetPlaySeconds(src) < cfg.minTeachPlaySeconds then return false, 'too_young' end
    if sheet.accountId == target.accountId then return false, 'same_account' end
    if target.mentors[def.id] then return false, 'already_mentored' end
    if apprenticeCount(sheet, def.id) >= cfg.maxApprentices then return false, 'full' end
    if not bridge.Within(src, targetSrc, cfg.proposalRadius) then return false, 'too_far' end
    for _, proposal in pairs(proposals) do
        if proposal.apprenticeSrc == targetSrc and proposal.skill == def.id then return false, 'pending' end
    end

    lastProposalId = (lastProposalId % VavaSkills.MAX_PROPOSAL_ID) + 1
    local proposal = {
        id = lastProposalId, masterSrc = src, masterId = sheet.characterId, apprenticeSrc = targetSrc, apprenticeId = target.characterId,
        skill = def.id, expiresAt = GetGameTimer() + cfg.proposalTtlMs,
    }
    proposals[proposal.id] = proposal
    SetTimeout(cfg.proposalTtlMs, function() dropProposal(proposal, 'expired') end)
    TriggerClientEvent(EVENTS.PROPOSAL, targetSrc, {
        id = proposal.id, masterName = sheet.name, masterCharacterId = sheet.characterId,
        skill = def.id, skillLabel = def.label, expiresInMs = cfg.proposalTtlMs,
    })
    bridge.Notify(targetSrc, format(messages.proposalReceived, sheet.name, def.label, VavaSkills.config.keys.open), 'info')
    bridge.Notify(src, format(messages.proposalSent, target.name), 'info')
    return true
end

--- L'apprenti répond. Bloque le thread courant si la proposition est acceptée (écriture du mentorat).
---@param src integer
---@param proposalId any
---@param accept any
---@return boolean ok
---@return string|nil code
function mentoring.answer(src, proposalId, accept)
    local proposal = proposals[proposalId]
    if not proposal or proposal.apprenticeSrc ~= src then return false, 'not_found' end
    if GetGameTimer() > proposal.expiresAt then
        dropProposal(proposal, 'expired')
        return false, 'expired'
    end
    if accept ~= true then
        dropProposal(proposal, 'declined')
        bridge.Notify(proposal.masterSrc, format(messages.proposalExpired, bridge.GetCharacterName(src) or '?'), 'info')
        return true
    end
    local master, apprentice = sheets.get(proposal.masterSrc), sheets.get(src)
    if not master or not apprentice or master.characterId ~= proposal.masterId or apprentice.characterId ~= proposal.apprenticeId then
        dropProposal(proposal, 'gone')
        return false, 'not_found'
    end
    if not bridge.Within(proposal.masterSrc, src, cfg.proposalRadius) then return false, 'too_far' end
    -- l'état a pu changer depuis la proposition
    if apprentice.mentors[proposal.skill] or apprenticeCount(master, proposal.skill) >= cfg.maxApprentices then
        dropProposal(proposal, 'gone')
        return false, 'not_found'
    end
    proposals[proposal.id] = nil

    local startedAt = time()
    local id, err = bridge.db.insert(INSERT_SQL, { proposal.skill, master.characterId, apprentice.characterId, startedAt })
    if not id then
        VavaSkills.log.error('mentorat non écrit : %s', tostring(err))
        return false, 'db_error'
    end
    local mentorship = {
        id = id, skill = proposal.skill, masterId = master.characterId, apprenticeId = apprentice.characterId,
        startedAt = startedAt, xpGranted = 0, renownGranted = 0, pairRenown = 0, dirty = false,
    }
    -- rendement décroissant : ce que cet apprenti a déjà rapporté au maître lors de mentorats passés
    local pair = bridge.db.scalar('SELECT COALESCE(SUM(`renown_granted`), 0) FROM `vava_skills_mentorships` WHERE `master_id` = ? AND `apprentice_id` = ? AND `skill` = ?',
        { master.characterId, apprentice.characterId, proposal.skill })
    mentorship.pairRenown = bridge.Integer(pair, 0)
    sheets.attachMentorship(master, mentorship)
    sheets.attachMentorship(apprentice, mentorship)
    master.names[apprentice.characterId], apprentice.names[master.characterId] = apprentice.name, master.name

    local label = registries.skillLabel(proposal.skill)
    journal.write('mentor_start', { actorId = master.characterId, targetId = apprentice.characterId, skill = proposal.skill, details = { mentorship = id } })
    core.hooks.runAfter(HOOK, { action = 'started', mentorshipId = id, skill = proposal.skill, masterId = master.characterId, apprenticeId = apprentice.characterId })
    push(master.source, { action = 'started', mentorshipId = id, skill = proposal.skill, skillLabel = label, role = 'master', other = { characterId = apprentice.characterId, name = apprentice.name } })
    push(apprentice.source, { action = 'started', mentorshipId = id, skill = proposal.skill, skillLabel = label, role = 'apprentice', other = { characterId = master.characterId, name = master.name } })
    bridge.Notify(master.source, format(messages.mentorshipStarted, apprentice.name, messages.roles.apprentice, label), 'info')
    bridge.Notify(apprentice.source, format(messages.mentorshipStarted, master.name, messages.roles.master, label), 'info')
    VavaSkills.experience.push(master, proposal.skill)
    VavaSkills.experience.push(apprentice, proposal.skill)
    return true
end

-- Fin ------------------------------------------------------------------------------------------------------------

---@param mentorship vAvA.Mentorship
---@param endedBy 'master'|'apprentice'|'system'
---@param actorId integer|nil
local function finish(mentorship, endedBy, actorId)
    local label = registries.skillLabel(mentorship.skill)
    local master, apprentice = sheets.byCharacter(mentorship.masterId), sheets.byCharacter(mentorship.apprenticeId)
    sheets.detachMentorship(mentorship)
    dirty[mentorship.id] = nil
    journal.write('mentor_end', { actorId = actorId, targetId = actorId == mentorship.masterId and mentorship.apprenticeId or mentorship.masterId,
        skill = mentorship.skill, details = { mentorship = mentorship.id, endedBy = endedBy, xpGranted = mentorship.xpGranted, renownGranted = mentorship.renownGranted } })
    core.hooks.runAfter(HOOK, { action = 'ended', mentorshipId = mentorship.id, skill = mentorship.skill, masterId = mentorship.masterId, apprenticeId = mentorship.apprenticeId, endedBy = endedBy })
    if master then
        local name = sheets.nameOf(master, mentorship.apprenticeId)
        push(master.source, { action = 'ended', mentorshipId = mentorship.id, skill = mentorship.skill, skillLabel = label, role = 'master', other = { characterId = mentorship.apprenticeId, name = name }, reason = endedBy })
        bridge.Notify(master.source, format(messages.mentorshipEnded, label, name), 'info')
        VavaSkills.experience.push(master, mentorship.skill)
    end
    if apprentice then
        local name = sheets.nameOf(apprentice, mentorship.masterId)
        push(apprentice.source, { action = 'ended', mentorshipId = mentorship.id, skill = mentorship.skill, skillLabel = label, role = 'apprentice', other = { characterId = mentorship.masterId, name = name }, reason = endedBy })
        bridge.Notify(apprentice.source, format(messages.mentorshipEnded, label, name), 'info')
        VavaSkills.experience.push(apprentice, mentorship.skill)
    end
end

--- Rompt un mentorat (maître ou apprenti). Bloque le thread courant (écriture).
---@param src integer
---@param mentorshipId any
---@return boolean ok
---@return string|nil code
function mentoring.breakUp(src, mentorshipId)
    local sheet = sheets.get(src)
    if not sheet then return false, 'no_character' end
    local mentorship = mathType(mentorshipId) == 'integer' and sheets.mentorship(mentorshipId)
    if not mentorship then return false, 'not_found' end
    local role
    if mentorship.masterId == sheet.characterId then role = 'master'
    elseif mentorship.apprenticeId == sheet.characterId then role = 'apprentice'
    else return false, 'not_party' end
    -- compteurs à jour avant la fin
    local _, err = bridge.db.update(COUNTERS_SQL, { mentorship.xpGranted, mentorship.renownGranted, mentorship.id })
    if err then return false, 'db_error' end
    local affected
    affected, err = bridge.db.update(END_SQL, { time(), role, mentorship.id })
    if err then return false, 'db_error' end
    if affected == 0 then
        -- déjà terminé en base (autre serveur, correction manuelle) : la mémoire se met en accord
        sheets.detachMentorship(mentorship)
        return false, 'not_found'
    end
    finish(mentorship, role, sheet.characterId)
    return true
end

--- Personnage supprimé : ses mentorats prennent fin. Bloque le thread courant.
---@param characterId integer
function mentoring.forgetCharacter(characterId)
    bridge.db.update(END_ALL_SQL, { time(), 'system', characterId, characterId })
    for _, sheet in pairs(sheets.all()) do
        for _, mentorship in pairs(sheet.mentors) do
            if mentorship.masterId == characterId then finish(mentorship, 'system', nil) end
        end
        for _, list in pairs(sheet.apprentices) do
            for apprenticeId, mentorship in pairs(list) do
                if apprenticeId == characterId then finish(mentorship, 'system', nil) end
            end
        end
    end
end

--- Joueur parti : ses propositions tombent.
---@param src integer
function mentoring.forget(src)
    for _, proposal in pairs(proposals) do
        if proposal.masterSrc == src or proposal.apprenticeSrc == src then dropProposal(proposal, 'gone') end
    end
end

-- Persistance des compteurs (avec les fiches) --------------------------------------------------------------------

---@param queries table[]
function mentoring.collectQueries(queries)
    for _, mentorship in pairs(dirty) do
        queries[#queries + 1] = { query = COUNTERS_SQL, values = { mentorship.xpGranted, mentorship.renownGranted, mentorship.id } }
    end
end

function mentoring.markClean()
    dirty = {}
end
