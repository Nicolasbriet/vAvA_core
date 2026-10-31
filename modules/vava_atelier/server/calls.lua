--[[
    vava_atelier/server/calls.lua
    Rôle : les fonctions de rechargement d'un module gardé (§ 5.2 de la spec T-101), appelées isolées et chronométrées
           par le pont : `apply`, `remove`, `trial`, `endTrial`, `diff`, `upgrade`, et la lecture de ses entrées
           (`index`, `read`) pour la graine et le rapprochement. Une erreur levée vaut un refus, avec une ligne en
           console ; le texte d'un refus est borné (160 octets). Lecture d'une ligne gardée pour un type (JSON décodé,
           format monté, data normalisée par le formulaire en vigueur, lieu contrôlé : shared/stored.lua). Avis
           `vava_atelier:entryChanged` aux seuls membres dont la séance est sur l'atelier.
    Dépendances : shared/constants.lua, config.lua, shared/text.lua, shared/place.lua, shared/stored.lua,
                  shared/changes.lua, bridge/server.lua, server/core.lua, server/access.lua
]]

local type, ipairs, pairs, tostring = type, ipairs, pairs, tostring
local find = string.find

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local Bridge = VavaAtelier.bridge
local access = VavaAtelier.access
local text, place, stored, changes = VavaAtelier.text, VavaAtelier.place, VavaAtelier.stored, VavaAtelier.changes
local EVENTS = VavaAtelier.EVENTS
local DEF = VavaAtelier.DEF
local ENTRY_PATTERN, MAX_ENTRY = VavaAtelier.ENTRY_PATTERN, VavaAtelier.MAX_ENTRY

local calls = {}
VavaAtelier.calls = calls

--- Retour `true` / `false, 'texte'` d'une fonction de rechargement : true, ou false et un texte borné.
---@return boolean ok
---@return string|nil text
local function verdict(editorId, name, called, ok, detail)
    if not called then return false, cfg.texts.refused.editor_error end
    if ok == true then return true end
    if ok ~= false then
        VavaAtelier.log.error('%s.%s : true ou false, texte attendus (reçu %s)', editorId, name, tostring(ok))
        return false, cfg.texts.refused.editor_error
    end
    local message = changes.moduleText(detail) or cfg.texts.refused.editor_error
    return false, message
end

--- `apply(kind, def, info)` : true, ou false et le texte du module.
function calls.apply(editor, kindId, def, info)
    local called, ok, detail = Bridge.CallEditor(editor.id, 'apply', editor.fns.apply, kindId, def, info)
    return verdict(editor.id, 'apply', called, ok, detail)
end

--- `remove(kind, id, info)` : true, ou false et le texte du module.
function calls.remove(editor, kindId, id, info)
    local called, ok, detail = Bridge.CallEditor(editor.id, 'remove', editor.fns.remove, kindId, id, info)
    return verdict(editor.id, 'remove', called, ok, detail)
end

--- `trial(kind, def, ctx)` : true, ou false et le texte du module.
function calls.trial(editor, kindId, def, ctx)
    if not editor.fns.trial then return false, cfg.texts.refused.no_trial end
    local called, ok, detail = Bridge.CallEditor(editor.id, 'trial', editor.fns.trial, kindId, def, ctx)
    return verdict(editor.id, 'trial', called, ok, detail)
end

--- `endTrial(kind, id, ctx)` : retour ignoré (une erreur est écrite en console par le pont).
function calls.endTrial(editor, kindId, id, ctx)
    if not editor.fns.endTrial then return end
    Bridge.CallEditor(editor.id, 'endTrial', editor.fns.endTrial, kindId, id, ctx)
end

--- `diff(kind, avant, après)` : texte du module, ou nil (résumé générique).
function calls.diff(editor, kindId, before, after)
    if not editor.fns.diff then return nil end
    local called, result = Bridge.CallEditor(editor.id, 'diff', editor.fns.diff, kindId, before, after)
    if not called then return nil end
    return changes.moduleText(result)
end

--- Contexte de lecture d'une ligne gardée pour un type (formulaire, lieu, format, montée de format isolée).
---@param editor vAvA.AtelierEditor
---@param kind vAvA.AtelierKind
---@return vAvA.AtelierStoredContext
local function readContext(editor, kind)
    local upgrade = nil
    if editor.fns.upgrade then
        upgrade = function(data, from)
            local called, result, err = Bridge.CallEditor(editor.id, 'upgrade', editor.fns.upgrade, kind.def.id, data,
                from)
            if not called then return nil, 'erreur' end
            return result, err
        end
    end
    return {
        decode = Bridge.JsonDecode, form = kind.def.form, placement = kind.def.placement, limits = cfg.place,
        format = editor.format, upgrade = upgrade,
    }
end

--- Fiche lue d'une ligne gardée, ou nil et la raison (console : version illisible par cet atelier).
---@param editor vAvA.AtelierEditor
---@param kind vAvA.AtelierKind
---@param row table
---@return vAvA.AtelierStoredEntry|nil
---@return string|nil
function calls.entryOf(editor, kind, row)
    local entry, err = stored.read(row, readContext(editor, kind))
    if not entry then
        VavaAtelier.log.error("%s, %s '%s' (ligne %s) : version illisible par cet atelier : %s", editor.id,
            kind.def.id, tostring(row.def_id), tostring(row.id), tostring(err))
        return nil, err
    end
    return entry
end

-- contexte du retour à l'original : le module rend ses entrées telles que sa config les donne (avant tout `apply`)
local ORIGINAL = { original = true }

--- Identifiants rendus par `index(kind)` du module (au motif, sans double), ou nil s'il ne répond pas. `original` :
--- `index(kind, { original = true })`, les entrées de la config du module (retour à l'original).
---@param editor vAvA.AtelierEditor
---@param kindId string
---@param original? boolean
---@return string[]|nil
function calls.moduleIndex(editor, kindId, original)
    local called, raw = Bridge.CallEditor(editor.id, 'index', editor.fns.index, kindId, original and ORIGINAL or nil)
    if not called or type(raw) ~= 'table' then
        if called then VavaAtelier.log.error('%s.index(%s) : liste attendue', editor.id, kindId) end
        return nil
    end
    local out, seen = {}, {}
    for _, item in ipairs(raw) do
        local id = type(item) == 'table' and item.id or nil
        if type(id) == 'string' and #id <= MAX_ENTRY and find(id, ENTRY_PATTERN) and not seen[id] then
            seen[id] = true
            out[#out + 1] = id
        end
    end
    return out
end

--- Entrée en vigueur chez le module, normalisée (`read(kind, id)`) : fiche, ou nil et 'absent' | 'error' | raison.
--- `original` : `read(kind, id, { original = true })`, l'entrée telle que la config du module la donne.
---@param editor vAvA.AtelierEditor
---@param kind vAvA.AtelierKind
---@param id string
---@param original? boolean
---@return vAvA.AtelierStoredEntry|nil
---@return string|nil
function calls.moduleRead(editor, kind, id, original)
    local called, raw = Bridge.CallEditor(editor.id, 'read', editor.fns.read, kind.def.id, id,
        original and ORIGINAL or nil)
    if not called then return nil, 'error' end
    if raw == nil then return nil, 'absent' end
    if type(raw) ~= 'table' then
        VavaAtelier.log.error('%s.read(%s, %s) : table attendue', editor.id, kind.def.id, id)
        return nil, 'error'
    end
    if place.ignored(kind.def.placement, raw.place) then
        VavaAtelier.log.warn("%s, %s '%s' : lieu ignoré (type sans placement)", editor.id, kind.def.id, id)
    end
    local entry, err = stored.fromModule(raw, kind.def.form, kind.def.placement, cfg.place)
    if not entry then
        VavaAtelier.log.error("%s, %s '%s' : %s", editor.id, kind.def.id, id, tostring(err))
        return nil, err
    end
    return entry
end

--- Titre d'une data (champ titre du formulaire), borné ; l'identifiant s'il est vide.
---@param kind vAvA.AtelierKind
---@param data table
---@param fallback string
---@return string
function calls.titleOf(kind, data, fallback)
    local value = data[kind.def.form.titleField]
    if type(value) ~= 'string' or value == '' or not text.isUtf8(value) then return fallback end
    return text.truncate(value, DEF.title)
end

--- JSON d'une fiche (data, lieu) : dataJson, placeJson ; nil, code (too_large, invalid).
---@param data table
---@param where table|nil
---@return string|nil
---@return string
function calls.encode(data, where)
    local dataJson, placeJson = stored.encode(Bridge.JsonEncode, data, where, cfg.definitions.maxBytes)
    if not dataJson then return nil, placeJson == 'too_large' and 'too_large' or 'editor_error' end
    return dataJson, placeJson
end

--- Avis `entryChanged` aux membres dont la séance est sur cet atelier (sauf `except`), et à `extra` en plus.
---@param editorId string
---@param kindId string
---@param id string
---@param what string  saved | published | restored | removed | discarded | taken | trialEnded
---@param except integer|nil
---@param extra integer|nil
---@param title string|nil  nom de la fiche (fin d'essai : notification hors de l'Atelier)
function calls.notify(editorId, kindId, id, what, except, extra, title)
    local sent = {}
    for source, session in pairs(access.sessions()) do
        if session.editor == editorId and source ~= except then
            sent[source] = true
            Bridge.Send(source, EVENTS.ENTRY_CHANGED, editorId, kindId, id, what, title)
        end
    end
    if extra and extra ~= except and not sent[extra] then
        Bridge.Send(extra, EVENTS.ENTRY_CHANGED, editorId, kindId, id, what, title)
    end
end
