--[[
    vava_atelier/server/trials.lua
    Rôle : essais en cours (§ 5.6, § 7.5 de la spec T-101), en mémoire seulement : un essai ne survit jamais à un
           redémarrage (les lignes sont rendues aux brouillons au démarrage). Un essai par membre (`trial.perMember`) ;
           il prend fin à la demande du membre, à la publication ou à l'abandon de son brouillon, à sa reprise par un
           autre, à la fermeture de la séance, au départ, au délai (`trial.maxMinutes`), au retrait de l'atelier. À la
           fin : `endTrial` du module (ce que l'essai montrait à l'auteur est retiré), lignes rendues aux brouillons,
           ligne `trial_ended` au journal (au nom gardé au début de l'essai quand le membre n'est plus là), hook
           vava_atelier:trial, avis `entryChanged` aux membres sur l'atelier et au tenant qui ne l'a pas demandé.
    Dépendances : shared/constants.lua, config.lua, bridge/server.lua, server/core.lua, server/editors.lua,
                  server/journal.lua, server/store.lua, server/index.lua, server/calls.lua
]]

local pairs, ipairs, tostring, format = pairs, ipairs, tostring, string.format
local CreateThread, SetTimeout, GetGameTimer = CreateThread, SetTimeout, GetGameTimer

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local texts = cfg.texts
local editors, journal, store, index, calls = VavaAtelier.editors, VavaAtelier.journal, VavaAtelier.store,
    VavaAtelier.index, VavaAtelier.calls
local HOOK_TRIAL = VavaAtelier.HOOKS.TRIAL

local trials = {}
VavaAtelier.trials = trials

---@class vAvA.AtelierTrial
---@field editor string
---@field kind string
---@field id string
---@field title string
---@field version integer          numéro qu'elle prendrait
---@field rows integer[]           lignes en essai (fiche et enfants)
---@field children { kind: string, id: string }[]
---@field source integer
---@field accountId integer
---@field label string              nom du membre au début de l'essai (journal après son départ)
---@field def table                 fiche montrée (relance après une sauvegarde d'un enfant, sans relire la base)
---@field started integer

---@type table<integer, vAvA.AtelierTrial>
local byAccount = {}

-- fins qui ne viennent pas du membre : ligne au journal au nom gardé, avis au tenant
local IMPOSED = { session = true, dropped = true, timeout = true, editor = true, taken = true }
-- fins couvertes par une autre ligne du journal (publication, abandon)
local SILENT = { publish = true, discard = true }

--- Essai en cours d'un compte, ou nil.
---@param accountId integer|nil
---@return vAvA.AtelierTrial|nil
function trials.of(accountId)
    return accountId and byAccount[accountId] or nil
end

--- Nombre d'essais en cours d'un compte (borne `trial.perMember`).
---@param accountId integer
---@return integer
function trials.count(accountId)
    return byAccount[accountId] and 1 or 0
end

--- Nombre d'essais en cours dans un atelier (étiquette « 1 en essai » de l'accueil).
---@param editorId string
---@return integer
function trials.inEditor(editorId)
    local count = 0
    for _, trial in pairs(byAccount) do
        if trial.editor == editorId then count = count + 1 end
    end
    return count
end

--- Compte qui essaie une fiche, ou nil.
function trials.holderOf(editorId, kindId, id)
    for accountId, trial in pairs(byAccount) do
        if trial.editor == editorId and trial.kind == kindId and trial.id == id then return accountId end
    end
    return nil
end

--- Retient un essai commencé et arme son délai.
---@param trial vAvA.AtelierTrial
function trials.start(trial)
    trial.started = GetGameTimer()
    byAccount[trial.accountId] = trial
    core.hooks.runAfter(HOOK_TRIAL, {
        editor = trial.editor, kind = trial.kind, id = trial.id, accountId = trial.accountId, source = trial.source,
        on = true,
    })
    SetTimeout(cfg.trial.maxMinutes * 60000, function()
        if byAccount[trial.accountId] ~= trial then return end
        CreateThread(function()
            if byAccount[trial.accountId] == trial then trials.finish(trial.accountId, 'timeout') end
        end)
    end)
end

--- Met à jour la source d'un essai relancé après une sauvegarde (le membre a pu rouvrir l'Atelier).
---@param accountId integer
---@param source integer
function trials.touch(accountId, source)
    local trial = byAccount[accountId]
    if trial then trial.source = source end
end

---@class vAvA.AtelierTrialEnd
---@field requester? integer   joueur qui a demandé la fin (aucun avis à lui)
---@field by? string           nom de qui a repris le brouillon (raison `taken`)
---@field online? boolean      false : le membre est parti (aucun envoi, `source` absent pour le module)
---@field editor? table        atelier déjà retiré du registre (raison `editor`) : journal écrit à son nom

--- Fin d'un essai : endTrial du module, lignes rendues aux brouillons, journal, hook, avis. Rien s'il n'y en a pas.
--- À appeler dans un fil (attente de la base).
---@param accountId integer
---@param reason string  stop | publish | discard | taken | session | dropped | timeout | editor
---@param options? vAvA.AtelierTrialEnd
---@return boolean ended
function trials.finish(accountId, reason, options)
    local trial = byAccount[accountId]
    if not trial then return false end
    byAccount[accountId] = nil
    options = options or {}
    local online = options.online ~= false and reason ~= 'dropped'
    local declared = editors.get(trial.editor)
    local editor = declared or options.editor
    if declared and reason ~= 'editor' then
        local children = {}
        for i, child in ipairs(trial.children) do children[i] = { kind = child.kind, id = child.id } end
        calls.endTrial(editor, trial.kind, trial.id, {
            source = online and trial.source or nil, accountId = accountId, children = children, reason = reason,
        })
    end
    local reset = store.setStatus(trial.rows, 'trial', 'draft')
    if reset == nil then
        VavaAtelier.log.error('essai de %s (%s) : lignes non rendues aux brouillons, elles le seront au démarrage',
            trial.id, trial.editor)
    end
    -- têtes en mémoire
    local refs = { { kind = trial.kind, id = trial.id } }
    for _, child in ipairs(trial.children) do refs[#refs + 1] = child end
    for _, ref in ipairs(refs) do
        local head = index.get(trial.editor, ref.kind, ref.id)
        if head and head.draft and head.draft.status == 'trial' then
            head.draft.status = 'draft'
            index.touch(trial.editor, head)
        end
    end
    if editor and not SILENT[reason] then
        local summary = texts.trialReasons[reason] or reason
        if reason == 'taken' then summary = format(summary, tostring(options.by or '')) end
        local entry = { editor = trial.editor, kind = trial.kind, id = trial.id, action = 'trial_ended',
            title = trial.title, summary = summary, version = trial.version }
        local ok, code
        if IMPOSED[reason] then
            ok, code = journal.write(0, entry, nil, { accountId = accountId, label = trial.label }, options.editor)
        else
            ok, code = journal.write(trial.source, entry)
        end
        if not ok then VavaAtelier.log.warn('fin d\'essai non journalisée : %s', tostring(code)) end
    end
    core.hooks.runAfter(HOOK_TRIAL, {
        editor = trial.editor, kind = trial.kind, id = trial.id, accountId = accountId,
        source = online and trial.source or nil, on = false, reason = reason,
    })
    if editor then
        local extra = (online and IMPOSED[reason] and reason ~= 'session') and trial.source or nil
        calls.notify(editor, trial.kind, trial.id, 'trialEnded', options.requester or (not extra and trial.source
            or nil), extra, trial.title)
    end
    return true
end

--- La même, dans un fil (hooks, délais). La première raison donnée l'emporte (départ, puis fermeture de la séance).
function trials.finishLater(accountId, reason, options)
    local trial = byAccount[accountId]
    if not trial or trial.ending then return end
    trial.ending = reason
    CreateThread(function()
        if byAccount[accountId] == trial then trials.finish(accountId, reason, options) end
    end)
end

--- Atelier retiré du registre : chaque essai qui y est prend fin (raison `editor`), dans un fil ; `gone` : l'atelier
--- tel qu'il était déclaré (journal).
---@param gone vAvA.AtelierEditor
function trials.editorGone(gone)
    for accountId, trial in pairs(byAccount) do
        if trial.editor == gone.id then trials.finishLater(accountId, 'editor', { editor = gone }) end
    end
end

--- Séance fermée (hook vava_atelier:session, open = false) : l'essai du compte prend fin.
---@param accountId integer
---@param reason 'session'|'dropped'
function trials.sessionClosed(accountId, reason)
    trials.finishLater(accountId, reason, { online = reason ~= 'dropped' })
end
