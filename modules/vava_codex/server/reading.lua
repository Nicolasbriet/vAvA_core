--[[
    vava_codex/server/reading.lua
    Rôle : pages de lecture du Codex (1.5.0), côté serveur. Au setup : la graine (`VavaCodex.seed`, écrite par
           content/*.lua) est analysée et validée (shared/pages.lua) ; une page refusée est écrite en console avec son
           code et sa ligne et écartée seule ; la graine est ensuite oubliée. À chaque ouverture : l'index des pages
           que ce joueur peut voir maintenant (module requis démarré, page du Conseil selon son rang et son droit),
           rangé dans le contenu du Codex (même empreinte, gardé par la page). À la demande : le texte d'une page, en
           blocs déjà construits, après avoir revérifié qu'il peut la voir (sinon un seul code, `unknown_page`, qui ne
           trahit pas l'existence d'une page réservée). Commande de console : bilan des pages.
    Dépendances : shared/constants.lua, config.lua, server/core.lua, bridge/server.lua, shared/pages.lua,
                  content/*.lua (graine) ; server/prefs.lua (lu à l'appel : chargé après ce fichier)
]]

local ipairs, pcall, tostring, tonumber, type = ipairs, pcall, tostring, tonumber, type
local format = string.format
local RegisterCommand = RegisterCommand

local core = VavaCodex.core
if not core then return end

local cfg = VavaCodex.config
local bridge = VavaCodex.bridge
local pages = VavaCodex.pages
local REGISTRY = VavaCodex.REGISTRY
local MESSAGES = cfg.messages.pages
local CONSOLE = 0
local UNKNOWN = 'unknown_page'

local reading = {}
VavaCodex.reading = reading

local function empty()
    return { chapters = {}, pages = {}, byId = {} }
end

-- Pages gardées en mémoire (analysées une fois, au setup).
local book = empty()

---@param code string
---@return string
local function errorText(code)
    local errors = cfg.reading.errors
    return errors and errors[code] or code
end

--- Charge la graine. Appelé pendant le setup ; ne fait jamais échouer le module (au pire : aucune page).
function reading.load()
    local log = VavaCodex.log
    local seed = VavaCodex.seed
    VavaCodex.seed = nil
    book = empty()
    if type(seed) ~= 'table' then
        log.warn(MESSAGES.noSeed)
        return
    end
    local ok, result, refused = pcall(pages.build, seed)
    if not ok or type(result) ~= 'table' then
        log.error(MESSAGES.failed, tostring(result))
        return
    end
    local refusedPages = 0
    for _, entry in ipairs(refused) do
        if entry.kind == 'chapter' then
            log.warn(MESSAGES.chapterRefused, entry.id, errorText(entry.code))
        else
            refusedPages = refusedPages + 1
            log.warn(MESSAGES.refused, entry.id, errorText(entry.code), entry.line)
        end
    end
    book = result
    log.info(MESSAGES.loaded, #book.pages, refusedPages)
end

--- Le joueur peut-il voir cette page maintenant ? Module requis démarré ; page du Conseil : membre (`staff`, calculé
--- ici s'il est nil) et, si la page porte un droit, ce droit (repli ACE de la config sans vava_admin).
---@param page table
---@param src integer
---@param staff boolean|nil
---@param started table<string, boolean>|nil  ressources déjà vues pendant ce calcul
---@return boolean
local function visibleTo(page, src, staff, started)
    local requires = page.requires
    if requires ~= '' then
        local up
        if started and started[requires] ~= nil then
            up = started[requires]
        else
            up = bridge.Started(requires)
            if started then started[requires] = up end
        end
        if not up then return false end
    end
    if page.audience == 'player' then return true end
    if staff == nil then staff = bridge.IsStaff(src) end
    if not staff then return false end
    return page.permission == '' or bridge.Can(src, page.permission, nil)
end

--- Index des pages qu'un joueur peut voir maintenant, rangé dans le contenu de l'ouverture : `{ chapters = { { id,
--- label } }, pages = { { id, chapter, title, summary, hash, staff? } } }`, ordre total (chapitres par rang puis id,
--- pages par chapitre, rang, id). Un chapitre sans page visible est omis. nil si les pages sont fermées
--- (`reading.enabled = false`).
---@param src integer
---@param staff boolean  membre du Conseil (catalog.visible)
---@return table|nil
function reading.index(src, staff)
    if not cfg.reading.enabled then return nil end
    local chapters, list, shown, started = {}, {}, {}, {}
    for _, page in ipairs(book.pages) do
        if visibleTo(page, src, staff, started) then
            list[#list + 1] = {
                id = page.id, chapter = page.chapter, title = page.title, summary = page.summary, hash = page.hash,
                staff = page.audience == 'admin' or nil,
            }
            shown[page.chapter] = true
        end
    end
    for _, chapter in ipairs(book.chapters) do
        if shown[chapter.id] then chapters[#chapters + 1] = { id = chapter.id, label = chapter.label } end
    end
    return { chapters = chapters, pages = list }
end

--- RPC `vava_codex:page` : texte d'une page en blocs, `{ id, chapter, title, hash, body }`. Droits relus à l'appel :
--- un rang retiré entre l'ouverture et la lecture ferme la page. Aucune écriture, aucun journal (lecture).
---@param src integer
---@param id string  identifiant validé par le schéma
---@return boolean ok
---@return table|string page_or_code  disabled | no_character | unknown_page
function reading.page(src, id)
    if not cfg.reading.enabled then return false, 'disabled' end
    if not VavaCodex.prefs.get(src) then return false, 'no_character' end
    local page = book.byId[id]
    if not page or not visibleTo(page, src, nil, nil) then return false, UNKNOWN end
    return true, page.response
end

---@param page table
---@return string
local function audienceText(page)
    local text = page.audience == 'admin' and 'Conseil' or 'public'
    if page.permission ~= '' then text = text .. ' (droit ' .. page.permission .. ')' end
    if page.requires ~= '' then text = text .. ', module ' .. page.requires end
    return text
end

---@param def table|nil
---@param action string
---@return boolean
local function commandKnown(def, action)
    if type(def) ~= 'table' or def.kind ~= 'command' then return false end
    if action == '' then return true end
    for _, entry in ipairs(def.actions or {}) do
        if entry.id == action then return true end
    end
    return false
end

--- Commande de console `vava_codex_pages` : une ligne par page (id, chapitre, poids réseau, public), puis chaque
--- touche ou commande citée absente du registre `core:commands` à cet instant. Rien depuis un joueur.
---@param source integer
function reading.report(source)
    if source ~= CONSOLE then return end
    local log = VavaCodex.log
    for _, page in ipairs(book.pages) do
        log.info(MESSAGES.line, page.id, page.chapter, page.wire, audienceText(page))
    end
    local registry = core.registry.all(REGISTRY) or {}
    for _, page in ipairs(book.pages) do
        local module = page.requires ~= '' and page.requires or 'aucun module requis'
        for _, name in ipairs(page.refs.keys) do
            local def = registry[name]
            if type(def) ~= 'table' or not def.key then log.warn(MESSAGES.missing, page.id, 'touche ' .. name, module) end
        end
        for _, command in ipairs(page.refs.commands) do
            if not commandKnown(registry[command.name], command.action) then
                local shown = command.action ~= '' and format('/%s %s', command.name, command.action) or '/' .. command.name
                log.warn(MESSAGES.missing, page.id, 'commande ' .. shown, module)
            end
        end
    end
end

--- Enregistre la commande de console. Appelé pendant le setup.
function reading.listen()
    -- `true` : restreinte pour le jeu (ACE) ; le handler ne répond de toute façon qu'à la console
    RegisterCommand(cfg.pagesCommand, function(source)
        reading.report(tonumber(source) or -1)
    end, true)
end
