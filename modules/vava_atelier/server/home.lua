--[[
    vava_atelier/server/home.lua
    Rôle : l'accueil de l'Atelier, calculé avec les droits du moment : familles qui ont une carte visible, cartes
           (ateliers déclarés et cartes « Bientôt »), note du bas ; ce contenu stable ne part que si son empreinte
           diffère de celle que la page garde. Étiquettes des cartes (« 4 zones » lue chez le module), brouillons
           (T-100 : aucun), journal récent filtré par les droits détenus et rang du membre partent à chaque fois.
           Points d'extension `drafts` et `tag`.
    Dépendances : shared/constants.lua, config.lua, shared/rights.lua, shared/fingerprint.lua, bridge/server.lua,
                  server/core.lua, server/editors.lua, server/entries.lua, server/journal.lua
]]

local ipairs, type, format, min = ipairs, type, string.format, math.min
local sort = table.sort

local core = VavaAtelier.core
if not core then return end

local cfg = VavaAtelier.config
local texts = cfg.texts
local Bridge = VavaAtelier.bridge
local editors = VavaAtelier.editors
local entries = VavaAtelier.entries
local journal = VavaAtelier.journal
local providers = VavaAtelier.providers
local rights = VavaAtelier.rights

-- brouillons montrés sur l'accueil
local MAX_DRAFTS = cfg.drafts.homeLines

local home = {}
VavaAtelier.home = home

--- Brouillons d'un membre dans ses ateliers visibles (T-100 : aucun, la table vient avec T-101).
---@return table[]
function providers.drafts()
    return {}
end

--- Étiquette d'une carte venue de T-101 (« 1 en essai », ton `trial`) ; T-100 : aucune, le nombre d'entrées est pris.
---@return string|{ text: string, tone?: string }|nil
function providers.tag()
    return nil
end

--- Droits détenus par un membre, relus auprès de vava_admin.
---@param source integer
---@return string[]
function home.held(source)
    return rights.held(cfg.rights.allowed, function(right) return Bridge.Can(source, right) end)
end

--- Ateliers déclarés ouverts à ces droits, dans l'ordre de l'accueil.
---@param held string[]
---@return vAvA.AtelierEditor[]
function home.visible(held)
    local out = {}
    for _, editor in ipairs(editors.list()) do
        if rights.holds(held, editor.right) then out[#out + 1] = editor end
    end
    return out
end

--- Étiquette d'un atelier déclaré : celle du fournisseur, sinon le nombre d'entrées du type principal (« 2 panneaux »,
--- ton `count`, omis : c'est celui que la page prend par défaut) ; nil si le module ne répond pas.
---@param editor vAvA.AtelierEditor
---@return { text: string, tone?: string }|nil
local function tagOf(editor)
    local tag = providers.tag(editor.id)
    if type(tag) == 'string' then return { text = tag } end
    if type(tag) == 'table' and type(tag.text) == 'string' then
        return { text = tag.text, tone = type(tag.tone) == 'string' and tag.tone ~= 'count' and tag.tone or nil }
    end
    local count = entries.count(editor)
    if not count then return nil end
    local kind = editor.kinds[editor.firstKind].def
    return { text = format('%d %s', count, count > 1 and kind.nounPlural or kind.noun) }
end

--- Étiquettes des ateliers visibles, qui changent sans que l'accueil change (nombre d'entrées, essais) : envoyées à
--- chaque fois, hors de l'empreinte. { [atelier] = { text, tone? } } ; un atelier qui ne répond pas n'en a pas.
---@param visible vAvA.AtelierEditor[]
---@return table<string, { text: string, tone?: string }>
function home.tags(visible)
    local tags = {}
    for _, editor in ipairs(visible) do tags[editor.id] = tagOf(editor) end
    return tags
end

--- Contenu stable de l'accueil vu avec ces droits : { families, cards, footnote } (ni fonction, ni droit, ni réglage,
--- ni étiquette : celles-ci partent à part). Une carte « Bientôt » a `upcoming = true` (la page écrit « Bientôt »).
---@param held string[]
---@param visible vAvA.AtelierEditor[]
---@return table
function home.content(held, visible)
    local shown = {}
    for _, editor in ipairs(visible) do
        shown[#shown + 1] = {
            id = editor.id, family = editor.family, label = editor.label, description = editor.description,
            icon = editor.icon, upcoming = false, order = editor.order,
        }
    end
    for _, card in ipairs(editors.upcoming()) do
        if rights.holds(held, card.right) then
            shown[#shown + 1] = {
                id = card.id, family = card.family, label = card.label, description = card.description,
                icon = card.icon, upcoming = true, order = 0,
            }
        end
    end
    sort(shown, editors.before)
    local used, cards = {}, {}
    for i, card in ipairs(shown) do
        used[card.family] = true
        cards[i] = {
            editor = card.id, family = card.family, label = card.label, description = card.description,
            icon = card.icon, upcoming = card.upcoming,
        }
    end
    local families = {}
    for _, family in ipairs(cfg.families) do
        if used[family.id] then families[#families + 1] = { id = family.id, label = family.label } end
    end
    return { families = families, cards = cards, footnote = texts.footnote }
end

--- Réponse du RPC `home` : { version, content?, tags, drafts, journal, rank }. Le contenu part si son empreinte
--- diffère de `known` (ou s'il n'a pu en avoir aucune) ; étiquettes, brouillons, journal et rang partent toujours
--- (≈ 1 Ko).
---@param ctx vAvA.AtelierContext
---@param known string
---@return boolean ok
---@return table result
function home.answer(ctx, known)
    local held = home.held(ctx.source)
    local visible = home.visible(held)
    local content = home.content(held, visible)
    local version = VavaAtelier.fingerprint(content) or ''
    local ids = {}
    for i, editor in ipairs(visible) do ids[i] = editor.id end
    local drafts = providers.drafts(ctx.source, ids)
    if type(drafts) ~= 'table' then drafts = {} end
    local limited = {}
    for i = 1, min(#drafts, MAX_DRAFTS) do limited[i] = drafts[i] end
    local recent = journal.read(held, 0, '', cfg.journal.homeLines)
    local answer = {
        version = version,
        tags = home.tags(visible),
        drafts = limited,
        journal = recent and recent.lines or {},
        rank = Bridge.RankLabel(ctx.source) or '',
    }
    if known == '' or version == '' or version ~= known then answer.content = content end
    VavaAtelier.log.debug('accueil (joueur %d, %d atelier(s) visible(s)) : contenu %s', ctx.source, #visible,
        answer.content and 'envoyé' or 'gardé par la page')
    return true, answer
end
