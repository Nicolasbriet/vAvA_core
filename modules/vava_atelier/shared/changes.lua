--[[
    vava_atelier/shared/changes.lua
    Rôle : logique pure des résumés d'un changement, écrits par le serveur pour le Conseil (§ 5.7, § 9.4 de la spec
           T-101) :
             - valeur d'un champ mise en mots (« 1,5 m », « 7 jours », « oui ») — `show` vient de server/check.lua ;
             - champs changés d'une fiche : « Hauteur de 1,5 m à 2 m », « Matière : pierre », « Éclairé la nuit : oui »,
               « Retouché : Nom du panneau, Ce qui est écrit », « 4 réglages changés : … » ; le texte du module
               (`diff`) passe devant, borné ;
             - fiches enfants d'un lot : « 2 points ajoutés, 1 retiré », « 1 affiche ajoutée » (accords en genre et en
               nombre) ;
             - numéros : « La version 3 sera archivée ; celle-ci deviendra la version 4. » ;
             - ligne d'un brouillon sur l'accueil : « Nouvelle zone, pas encore publiée », « Zone en essai, vous seul la
               voyez en jeu », « Retrait de l'affiche, pas encore publié ».
           Tout texte est coupé à 160 octets sans briser un caractère. Aucune fonction dépendante de la locale.
           Testée : tests/spec/atelier_changes_spec.lua.
    Dépendances : shared/constants.lua, shared/text.lua
]]

local type, ipairs, tostring = type, ipairs, tostring
local byte, char, format, sub = string.byte, string.char, string.format, string.sub
local concat = table.concat

local text = VavaAtelier.text
local DEF = VavaAtelier.DEF

local changes = {}
VavaAtelier.changes = changes

local TEXT_WIDGETS = { text = true }
local CHOICE_WIDGETS = { segmented = true, select = true, model = true }

--- Texte coupé à 160 octets sans briser un caractère.
---@param value string
---@return string
function changes.fit(value)
    return text.truncate(value, DEF.summary)
end

--- Première lettre en minuscule (ASCII et lettres latines accentuées : « Pierre » → « pierre », « Éclat » → « éclat »).
---@param value string
---@return string
function changes.lowerFirst(value)
    local b1, b2 = byte(value, 1, 2)
    if not b1 then return value end
    if b1 >= 65 and b1 <= 90 then return char(b1 + 32) .. sub(value, 2) end
    if b1 == 0xC3 and b2 and b2 >= 0x80 and b2 <= 0x9E and b2 ~= 0x97 then
        return char(0xC3, b2 + 0x20) .. sub(value, 3)
    end
    return value
end

--- Première lettre en capitale (« zone » → « Zone », « épée » → « Épée »).
---@param value string
---@return string
function changes.capital(value)
    local b1, b2 = byte(value, 1, 2)
    if not b1 then return value end
    if b1 >= 97 and b1 <= 122 then return char(b1 - 32) .. sub(value, 2) end
    if b1 == 0xC3 and b2 and b2 >= 0xA0 and b2 <= 0xBE and b2 ~= 0xB7 then
        return char(0xC3, b2 - 0x20) .. sub(value, 3)
    end
    return value
end

--- Genre d'un type : `feminine` déclaré, sinon vrai pour l'article « la ».
---@param kind { article: string, feminine?: boolean }
---@return boolean
function changes.feminine(kind)
    if type(kind.feminine) == 'boolean' then return kind.feminine end
    return kind.article == 'la'
end

--- Compteur accordé : `forms.one` pour 0 et 1, `forms.many` au-delà (« 1 fiche », « 3 fiches »).
---@param n integer
---@param forms { one: string, many: string }
---@return string
function changes.count(n, forms)
    return format(n <= 1 and forms.one or forms.many, n)
end

--- Participe accordé : « ajouté », « ajoutée », « ajoutés », « ajoutées ».
---@param word string
---@param feminine boolean
---@param plural boolean
---@return string
function changes.agree(word, feminine, plural)
    return word .. (feminine and 'e' or '') .. (plural and 's' or '')
end

--- Complément d'un type : « de la zone », « du panneau », « de l'affiche ».
---@param kind { article: string, noun: string }
---@return string
function changes.of(kind)
    if kind.article == 'la' then return 'de la ' .. kind.noun end
    if kind.article == 'le' then return 'du ' .. kind.noun end
    return 'de l\'' .. kind.noun
end

--- Valeur numérique d'un champ pour un message d'erreur : « 1,5 m », « × 2 », « 7 jours » (décimales du champ).
---@param field table
---@param value number
---@return string
function changes.show(field, value)
    if field.widget == 'duration' then return text.duration(value) end
    local written = text.number(value, field.decimals)
    if field.prefix and field.prefix ~= '' then written = field.prefix .. ' ' .. written end
    if field.unit and field.unit ~= '' then written = written .. ' ' .. field.unit end
    return written
end

--- La même, sans décimales imposées (résumés : « de 1,5 m à 2 m »).
---@param field table
---@param value number
---@return string
function changes.brief(field, value)
    if field.widget == 'duration' then return text.duration(value) end
    local written = text.number(value)
    if field.prefix and field.prefix ~= '' then written = field.prefix .. ' ' .. written end
    if field.unit and field.unit ~= '' then written = written .. ' ' .. field.unit end
    return written
end

--- Libellé d'un choix déclaré (options ou choices), sinon la valeur.
local function optionLabel(field, value)
    for _, option in ipairs(field.options or field.choices or {}) do
        if option.value == value then return option.label end
    end
    return tostring(value)
end

--- Phrase d'un seul champ changé (hors texte).
local function single(field, before, after, texts)
    local widget = field.widget
    if widget == 'slider' or widget == 'duration' then
        if type(before) == 'number' and type(after) == 'number' then
            return format(texts.fromTo, field.label, changes.brief(field, before), changes.brief(field, after))
        end
    elseif widget == 'toggle' then
        return format(texts.choice, field.label, after == true and texts.yes or texts.no)
    elseif CHOICE_WIDGETS[widget] then
        return format(texts.choice, field.label, changes.lowerFirst(optionLabel(field, after)))
    end
    return format(texts.choice, field.label, after == '' and '—' or tostring(after))
end

--- Champs changés entre deux data, dans l'ordre du formulaire : liste de champs.
---@param form table
---@param before table|nil
---@param after table
---@return table[]
function changes.changed(form, before, after)
    local out = {}
    before = before or {}
    for _, field in ipairs(form.fields) do
        if before[field.id] ~= after[field.id] then out[#out + 1] = field end
    end
    return out
end

--- Résumé des champs changés (« Hauteur de 1,5 m à 2 m », « Retouché : … », « 4 réglages changés : … ») ; '' si rien
--- n'a changé.
---@param form table
---@param before table|nil
---@param after table
---@param texts table  config.texts.changes
---@return string summary
---@return integer count  champs changés
function changes.fields(form, before, after, texts)
    local changed = changes.changed(form, before, after)
    local count = #changed
    if count == 0 then return '', 0 end
    local labels, onlyText = {}, true
    for i, field in ipairs(changed) do
        labels[i] = field.label
        if not TEXT_WIDGETS[field.widget] then onlyText = false end
    end
    if onlyText then return changes.fit(format(texts.retouched, concat(labels, ', '))), count end
    if count == 1 then
        local field = changed[1]
        return changes.fit(single(field, (before or {})[field.id], after[field.id], texts)), count
    end
    local listed = format(texts.settingsList, count, concat(labels, ', '))
    if #listed > DEF.summary then return changes.fit(format(texts.settings, count)), count end
    return listed, count
end

--- Texte rendu par la fonction `diff` d'un module, s'il est utilisable : texte UTF-8 non vide, sans contrôle, borné.
---@param value any
---@return string|nil
function changes.moduleText(value)
    if type(value) ~= 'string' or value == '' or not text.isUtf8(value) or text.hasControl(value) then return nil end
    return changes.fit(value)
end

--- Résumé d'une fiche : le texte du module s'il en donne un, sinon les champs changés.
---@param form table
---@param before table|nil
---@param after table
---@param texts table  config.texts.changes
---@param fromModule any  retour de `diff` (texte ou nil)
---@return string
function changes.summary(form, before, after, texts, fromModule)
    return changes.moduleText(fromModule) or (changes.fields(form, before, after, texts))
end

--- « 1 réglage changé », « 3 réglages changés » (résumé court d'un brouillon).
---@param count integer
---@param texts table  config.texts.changes
---@return string
function changes.settingsCount(count, texts)
    local plural = count > 1
    return format('%d %s %s', count, plural and texts.settingPlural or texts.setting,
        changes.agree(texts.changed, false, plural))
end

---@class vAvA.AtelierChildCount
---@field noun string
---@field nounPlural string
---@field feminine boolean
---@field added integer
---@field removed integer
---@field changed integer

--- Fiches enfants d'un lot, par type : « 2 points ajoutés, 1 retiré », « 1 affiche ajoutée » ; '' s'il n'y en a pas.
---@param groups vAvA.AtelierChildCount[]
---@param texts table  config.texts.changes
---@return string summary
---@return integer total  fiches comptées
function changes.children(groups, texts)
    local parts, total = {}, 0
    for _, group in ipairs(groups) do
        local first = true
        for _, key in ipairs({ 'added', 'removed', 'changed' }) do
            local count = group[key] or 0
            if count > 0 then
                total = total + count
                local word = changes.agree(texts[key], group.feminine == true, count > 1)
                if first then
                    parts[#parts + 1] = format('%d %s %s', count, count > 1 and group.nounPlural or group.noun, word)
                    first = false
                else
                    parts[#parts + 1] = format('%d %s', count, word)
                end
            end
        end
    end
    return changes.fit(concat(parts, ', ')), total
end

--- Ligne des numéros : publication (« La version 3 sera archivée ; celle-ci deviendra la version 4. », ou « Ce sera
--- la version 1. ») ou retour en arrière (« La version 2 sera rétablie et deviendra la version 5. »).
---@param what 'publish'|'restore'
---@param texts table  config.texts.changes
---@param current integer|nil  version publiée (publish) ou visée (restore)
---@param nextVersion integer
---@return string
function changes.versionLine(what, texts, current, nextVersion)
    if what == 'restore' then return format(texts.restoreFrom, current, nextVersion) end
    if not current then return texts.first end
    return format(texts.versionNext, current, nextVersion)
end

--- Retrait d'une fiche et de ses enfants : « Retrait du panneau », « et de ses 2 affiches » (ligne du résumé).
---@param kind table
---@param groups { count: integer, noun: string, nounPlural: string }[]
---@param texts table  config.texts.changes
---@param journal? boolean  forme du journal : « et ses 2 affiches »
---@return string removal
---@return string children  '' sans enfant
function changes.removal(kind, groups, texts, journal)
    local parts = {}
    for _, group in ipairs(groups) do
        if group.count > 0 then
            parts[#parts + 1] = { group.count, group.count > 1 and group.nounPlural or group.noun }
        end
    end
    local line = ''
    if #parts > 0 then
        local pattern = journal and texts.removedWith or texts.removalChildren
        local more = {}
        for i = 2, #parts do more[#more + 1] = format('%d %s', parts[i][1], parts[i][2]) end
        line = format(pattern, parts[1][1], parts[1][2])
        if #more > 0 then line = line .. ', ' .. concat(more, ', ') end
    end
    return format(texts.removal, changes.of(kind)), changes.fit(line)
end

-- T-102 : lieu changé ------------------------------------------------------------------------------------------------

-- en deçà, un déplacement (m) ou une rotation (degrés) ne se dit pas
local MOVED_MIN, TURNED_MIN = 0.5, 1

--- Deux tracés de mêmes sommets ?
local function samePoints(a, b)
    if type(a) ~= 'table' or type(b) ~= 'table' or #a ~= #b then return false end
    for i = 1, #a do
        if a[i].x ~= b[i].x or a[i].y ~= b[i].y then return false end
    end
    return true
end

--- Résumé d'un lieu changé (aperçu de publication, journal) : « posée » (premier lieu), « déplacée de 12 m »,
--- « tournée de 40° », « rayon de 120 m à 140 m », « tracé redessiné (6 sommets) », séparés par des virgules ; '' si
--- rien ne se dit (déplacement de moins de 0,5 m, rotation de moins de 1°, lieu retiré).
---@param before table|nil  lieu de la version publiée
---@param after table|nil   lieu de la nouvelle version
---@param feminine boolean  genre du type (« déplacée »)
---@param texts table  config.texts.changes.place
---@return string
function changes.place(before, after, feminine, texts)
    if type(after) ~= 'table' then return '' end
    local gender = feminine and 'feminine' or 'masculine'
    if type(before) ~= 'table' then return texts.placed[gender] end
    if after.points then
        if before.points and samePoints(before.points, after.points) and before.z == after.z then return '' end
        return format(texts.redrawn, #after.points)
    end
    local parts = {}
    if type(before.x) == 'number' and type(after.x) == 'number' then
        local dx, dy = after.x - before.x, after.y - before.y
        local moved = (dx * dx + dy * dy) ^ 0.5
        if moved >= MOVED_MIN then
            parts[#parts + 1] = format(texts.moved[gender], text.number(math.max(1, math.floor(moved + 0.5))))
        end
    end
    if type(before.h) == 'number' and type(after.h) == 'number' then
        local turned = math.abs(after.h - before.h) % 360
        if turned > 180 then turned = 360 - turned end
        if turned >= TURNED_MIN then parts[#parts + 1] = format(texts.turned[gender], math.floor(turned + 0.5)) end
    end
    if type(before.r) == 'number' and type(after.r) == 'number' and before.r ~= after.r then
        parts[#parts + 1] = format(texts.radius, text.number(before.r), text.number(after.r))
    end
    return changes.fit(concat(parts, ', '))
end

--- Résumé d'une publication : les réglages changés, puis le lieu et les enfants (« déplacée de 12 m, 2 points
--- ajoutés »), séparés par « ; » des réglages ; '' si rien.
---@param fields string
---@param where string
---@param children string
---@return string
function changes.combine(fields, where, children)
    local tail = {}
    if where ~= '' then tail[#tail + 1] = where end
    if children ~= '' then tail[#tail + 1] = children end
    local parts = {}
    if fields ~= '' then parts[#parts + 1] = fields end
    if #tail > 0 then parts[#parts + 1] = concat(tail, ', ') end
    return changes.fit(concat(parts, ' ; '))
end

---@class vAvA.AtelierDraftInfo
---@field new? boolean        fiche jamais publiée
---@field trial? boolean      en essai
---@field removal? boolean    brouillon de retrait
---@field summary? string     résumé court (« 1 réglage changé », « 2 points ajoutés »)
---@field count? integer      choses comptées dans le résumé (accord de « publié »)

--- Ligne d'un brouillon sur l'accueil.
---@param kind table  type déclaré (noun, article, newLabel, feminine?)
---@param info vAvA.AtelierDraftInfo
---@param texts table  config.texts.drafts
---@return string
function changes.draftLine(kind, info, texts)
    local gender = changes.feminine(kind) and 'feminine' or 'masculine'
    local line
    if info.removal then
        line = format(texts.removal, changes.of(kind))
    elseif info.trial then
        line = format(texts.trial[gender], changes.capital(kind.noun))
    elseif info.new then
        line = format(texts.new[gender], kind.newLabel)
    elseif type(info.summary) == 'string' and info.summary ~= '' then
        line = format((info.count or 1) > 1 and texts.changes.many or texts.changes.one, info.summary)
    else
        line = texts.unchanged
    end
    return changes.fit(line)
end
