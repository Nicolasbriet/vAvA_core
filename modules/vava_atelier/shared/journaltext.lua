--[[
    vava_atelier/shared/journaltext.lua
    Rôle : logique pure du journal de l'Atelier : début d'une ligne (« A publié la station », « A créé l'enclume »,
           « A enregistré le brouillon du panneau »), âge d'une ligne (« à l'instant », « il y a 12 min », « hier »,
           « le 12/10 »), résumé borné sans briser un caractère, ligne prête pour l'interface. Tout est calculé par le
           serveur : le client n'affiche que ces textes.
           Testée : tests/spec/atelier_journaltext_spec.lua.
    Dépendances : shared/constants.lua, shared/text.lua
]]

local type, tostring, floor = type, tostring, math.floor
local format, sub = string.format, string.sub
local date = os.date

local text = VavaAtelier.text
local OUT = VavaAtelier.OUT

local MINUTE, HOUR, DAY = 60, 3600, 86400

local jt = {}
VavaAtelier.journaltext = jt

--- Début d'une ligne : verbe, puis article et nom du type. « de le » devient « du » ; pas d'espace après « l' ».
---@param verb string|nil  « A publié »
---@param article string|nil  le | la | l'
---@param noun string|nil  « station »
---@return string
function jt.lead(verb, article, noun)
    if type(verb) ~= 'string' then return '' end
    if type(noun) ~= 'string' or noun == '' then return verb end
    if article == 'l\'' then return verb .. ' l\'' .. noun end
    if article == 'le' and sub(verb, -3) == ' de' then return sub(verb, 1, -4) .. ' du ' .. noun end
    if article == 'le' or article == 'la' then return verb .. ' ' .. article .. ' ' .. noun end
    return verb .. ' ' .. noun
end

--- Âge d'une ligne, vu à `now` (secondes). `dateOf(fmt, at)` : os.date par défaut (« le 12/10 » au-delà d'une
--- semaine).
---@param now number
---@param at number
---@param dateOf? fun(fmt: string, at: number): string
---@return string
function jt.age(now, at, dateOf)
    local elapsed = floor(now - at)
    if elapsed < MINUTE then return 'à l\'instant' end
    if elapsed < HOUR then return format('il y a %d min', elapsed // MINUTE) end
    if elapsed < DAY then return format('il y a %d h', elapsed // HOUR) end
    if elapsed < 2 * DAY then return 'hier' end
    if elapsed < 7 * DAY then return format('il y a %d jours', elapsed // DAY) end
    return 'le ' .. tostring((dateOf or date)('%d/%m', floor(at)))
end

--- Résumé coupé à `maxBytes` octets (160 par défaut) sans briser un caractère UTF-8 ; nil s'il est absent ou vide.
---@param summary any
---@param maxBytes? integer
---@return string|nil
function jt.summary(summary, maxBytes)
    if type(summary) ~= 'string' or summary == '' then return nil end
    return text.truncate(summary, maxBytes or OUT.summary)
end

---@class vAvA.AtelierJournalRow
---@field id integer
---@field editor string
---@field kind string
---@field action string
---@field title string
---@field summary string|nil
---@field actor_label string
---@field at number  secondes (UNIX_TIMESTAMP)

--- Ligne du journal pour l'interface : { id, lead, title, summary?, actor, when, editor? }. `sameEditor` : la page a
--- demandé un seul atelier, qu'elle connaît déjà (filtre) : `editor` n'est pas répété sur chaque ligne.
---@param row vAvA.AtelierJournalRow
---@param verbs table<string, string>
---@param kind? { article: string, noun: string }  type de l'éditeur s'il est encore déclaré
---@param now number
---@param dateOf? fun(fmt: string, at: number): string
---@param sameEditor? boolean
---@return table
function jt.line(row, verbs, kind, now, dateOf, sameEditor)
    return {
        id = row.id,
        lead = jt.lead(verbs[row.action] or verbs.note, kind and kind.article, kind and kind.noun),
        title = row.title,
        summary = jt.summary(row.summary),
        actor = row.actor_label,
        when = jt.age(now, row.at or now, dateOf),
        editor = not sameEditor and row.editor or nil,
    }
end
