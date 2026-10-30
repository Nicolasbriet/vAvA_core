--[[
    vava_inventory/server/catalog.lua
    Rôle : catalogue de développement : un conteneur temporaire par joueur, garni d'une pile pleine de chaque objet
           connu du registre (par catégorie puis libellé, filtré par une recherche, découpé en pages à la taille de sa
           grille), ouvert par une commande réservée au Conseil (droit vava_admin `staff` ; sans vava_admin, ACE ;
           console) puis piloté depuis le bandeau de son panneau (RPC, même droit). Ce qu'on en prend est aussitôt
           regarni (stock sans fin) ; ce qu'on y dépose disparaît au remplissage suivant. Rien n'est écrit en base.
           Désactivé par défaut (config.catalog.enabled) : à n'activer que sur un serveur de test.
    Dépendances : shared/constants.lua, config.lua, shared/grid.lua, server/core.lua, server/items.lua,
                  server/containers.lua, server/viewers.lua, server/operations.lua
]]

local pairs, ipairs, pcall, tostring, tonumber = pairs, ipairs, pcall, tostring, tonumber
local tointeger, max, min = math.tointeger, math.max, math.min
local sort, concat = table.sort, table.concat
local char, format = string.char, string.format
local RegisterCommand, GetResourceState, IsPlayerAceAllowed = RegisterCommand, GetResourceState, IsPlayerAceAllowed
local TriggerClientEvent = TriggerClientEvent

local grid = VavaInventory.grid
local items = VavaInventory.items
local containers = VavaInventory.containers
local viewers = VavaInventory.viewers
local operations = VavaInventory.operations
local cfg = VavaInventory.config.catalog
local EVENTS = VavaInventory.EVENTS
local KIND = VavaInventory.KIND
local REGISTRY = VavaInventory.REGISTRY
local CONSOLE = 0
local ADMIN = 'vava_admin'
-- case occupée pendant la mise en page : même parcours que la planification d'un échange, donc même résultat
local PLANNED = -1
-- gestes du joueur qui sortent une pile d'un conteneur : le catalogue se regarnit d'autant
local TAKING_HOOKS = { 'vava_inventory:move', 'vava_inventory:split', 'vava_inventory:merge', 'vava_inventory:drop' }
-- lettres accentuées (UTF-8, deux octets) ramenées à leur lettre nue : la recherche ignore accents et casse
local FOLD = {
    ['à'] = 'a', ['â'] = 'a', ['ä'] = 'a', ['á'] = 'a', ['ã'] = 'a', ['À'] = 'a', ['Â'] = 'a', ['Ä'] = 'a', ['Á'] = 'a',
    ['é'] = 'e', ['è'] = 'e', ['ê'] = 'e', ['ë'] = 'e', ['É'] = 'e', ['È'] = 'e', ['Ê'] = 'e', ['Ë'] = 'e',
    ['î'] = 'i', ['ï'] = 'i', ['í'] = 'i', ['Î'] = 'i', ['Ï'] = 'i',
    ['ô'] = 'o', ['ö'] = 'o', ['ó'] = 'o', ['õ'] = 'o', ['Ô'] = 'o', ['Ö'] = 'o',
    ['ù'] = 'u', ['û'] = 'u', ['ü'] = 'u', ['ú'] = 'u', ['Ù'] = 'u', ['Û'] = 'u', ['Ü'] = 'u',
    ['ç'] = 'c', ['Ç'] = 'c', ['ñ'] = 'n', ['Ñ'] = 'n', ['œ'] = 'oe', ['Œ'] = 'oe', ['æ'] = 'ae', ['Æ'] = 'ae',
}
local ASCII_LOWER = {}
for code = 65, 90 do ASCII_LOWER[char(code)] = char(code + 32) end

local catalog = {}
VavaInventory.catalog = catalog

---@type table<integer, vAvA.Container>  catalogue de chaque joueur qui l'a ouvert (clé : source)
local active = {}
---@type table<integer, integer>  source de chaque catalogue (clé : id du conteneur)
local ownerOf = {}
-- objets trop grands pour une page, signalés une fois
local oversized = {}

---@param text string
---@return string
local function fold(text)
    -- accents d'abord, puis casse ASCII seulement : string.lower suit la locale du système (sous Windows, 0xC3 → 0xE3
    -- avant le repli, qui ne reconnaissait plus aucun accent)
    local folded = text:gsub('\xC3[\x80-\xBF]', FOLD)
    folded = folded:gsub('\xC5[\x92\x93]', FOLD)
    return (folded:gsub('[A-Z]', ASCII_LOWER))
end

--- Objets du registre, par catégorie puis libellé, éventuellement d'une seule catégorie et répondant à une
--- recherche (sur le libellé ou le nom technique). Les comptes par catégorie portent sur tout le registre.
---@param category string|nil
---@param query string
---@return { item: string, def: vAvA.ItemDefinition }[] list
---@return table<string, integer> counts
local function listing(category, query)
    local needle = query ~= '' and fold(query) or nil
    local list, counts = {}, {}
    local all = VavaInventory.core.registry.all(REGISTRY) or {}
    for name in pairs(all) do
        local def = items.get(name)
        if def then
            local own = def.category or ''
            counts[own] = (counts[own] or 0) + 1
            local kept = category == nil or own == category
            if kept and needle then kept = fold(def.label):find(needle, 1, true) ~= nil or fold(name):find(needle, 1, true) ~= nil end
            if kept then list[#list + 1] = { item = name, def = def } end
        end
    end
    sort(list, function(a, b)
        local ca, cb = a.def.category or '', b.def.category or ''
        if ca ~= cb then return ca < cb end
        if a.def.label ~= b.def.label then return a.def.label < b.def.label end
        return a.item < b.item
    end)
    return list, counts
end

--- Catégories par ordre alphabétique, les objets sans catégorie en dernier : pour le bandeau et les messages.
---@param counts table<string, integer>
---@return { id: string, count: integer }[]
local function categoryList(counts)
    local names = {}
    for name in pairs(counts) do names[#names + 1] = name end
    sort(names, function(a, b)
        if (a == '') ~= (b == '') then return b == '' end
        return a < b
    end)
    local list = {}
    for i, name in ipairs(names) do list[i] = { id = name, count = counts[name] } end
    return list
end

---@param categories { id: string, count: integer }[]
---@return string
local function categoriesText(categories)
    local parts = {}
    for i, entry in ipairs(categories) do
        parts[i] = format('%s (%d)', entry.id == '' and 'sans catégorie' or entry.id, entry.count)
    end
    return concat(parts, ', ')
end

--- Découpe la liste en pages : chaque objet prend la première place libre, comme le fera l'échange ; un objet qui
--- ne tient plus ouvre la page suivante ; un objet plus grand qu'une page est laissé de côté.
---@param list { item: string, def: vAvA.ItemDefinition }[]
---@return vAvA.ItemRequest[][] pages
local function paginate(list)
    local pages, page, view = {}, nil, nil
    local function newPage()
        page, view = {}, { width = cfg.width, height = cfg.height, occupancy = {} }
        pages[#pages + 1] = page
    end
    newPage()
    for _, entry in ipairs(list) do
        local def = entry.def
        local x, y, rotated = grid.findSpace(view, def)
        if not x and #page > 0 then
            newPage()
            x, y, rotated = grid.findSpace(view, def)
        end
        if x then
            local w, h = grid.footprint(def, rotated)
            grid.mark(view, w, h, x, y, PLANNED)
            page[#page + 1] = { item = entry.item, quantity = def.stack }
        elseif not oversized[entry.item] then
            oversized[entry.item] = true
            VavaInventory.log.warn('catalogue : %s (%d×%d) ne tient pas dans une page de %d×%d', entry.item, def.width, def.height,
                cfg.width, cfg.height)
        end
    end
    if #page == 0 then pages[#pages] = nil end
    return pages
end

--- Garnit le catalogue d'un joueur avec une page et le lui ouvre. L'état (catégorie, page, recherche, catégories)
--- voyage avec le conteneur jusqu'au bandeau de l'interface.
---@param src integer
---@param category string|nil
---@param page integer|nil   1 par défaut, ramenée dans les bornes
---@param query string|nil   recherche sur le libellé ; sans résultat, la page est vide (pas une erreur)
---@return boolean ok
---@return string message   compte rendu, pour le joueur ou la console
function catalog.open(src, category, page, query)
    if not operations.ownContainer(src) then return false, 'Ce joueur n\'a pas de personnage en jeu.' end
    query = query or ''
    local list, counts = listing(category, query)
    local categories = categoryList(counts)
    if #list == 0 and query == '' then
        if category then return false, format('Aucun objet de catégorie « %s ». Catégories : %s.', category, categoriesText(categories)) end
        return false, 'Aucun objet déclaré à l\'inventaire.'
    end
    local pages = paginate(list)
    if #pages == 0 and query == '' then return false, 'Aucun objet ne tient dans une page du catalogue.' end
    if #pages == 0 then pages[1] = {} end
    page = max(1, min(page or 1, #pages))

    local container = active[src]
    if not container then
        local err
        container, err = containers.createTransient({
            kind = KIND.CATALOG, width = cfg.width, height = cfg.height, maxWeight = 0, label = cfg.label,
        })
        if not container then return false, 'Catalogue impossible : ' .. tostring(err) end
        active[src], ownerOf[container.id] = container, src
    end
    container.catalog = {
        category = category or '', page = page, pages = #pages, query = query, total = #list, categories = categories,
    }
    -- vidé puis garni d'un bloc : ce qui y avait été déposé disparaît
    local removals = {}
    for id in pairs(container.items) do removals[#removals + 1] = { instanceId = id } end
    local ok, code = operations.exchange(container, removals, pages[page], VavaInventory.resource)
    if not ok then return false, 'Catalogue non garni : ' .. tostring(code) end
    ok, code = operations.openContainer(src, container)
    if not ok then return false, 'Catalogue non ouvert : ' .. tostring(code) end

    if #list == 0 then return true, format('Catalogue : aucun objet ne répond à « %s ».', query) end
    local parts = { format('Catalogue : %d objet(s), page %d/%d.', #pages[page], page, #pages) }
    if page < #pages then parts[#parts + 1] = format('Suite : /%s %s%d.', cfg.command, category and (category .. ' ') or '', page + 1) end
    if not category then parts[#parts + 1] = 'Catégories : ' .. categoriesText(categories) .. '.' end
    return true, concat(parts, ' ')
end

--- Le joueur a sorti une pile du catalogue : la même quantité y revient (le stock ne s'épuise pas).
---@param payload { from: integer, to: integer, item: string, quantity: integer }
local function refill(payload)
    local src = ownerOf[payload.from]
    local container = src and active[src]
    if not container or payload.to == payload.from then return end
    local ok, code = operations.exchange(container, {}, { { item = payload.item, quantity = payload.quantity } }, VavaInventory.resource)
    if not ok then VavaInventory.log.warn('catalogue : %s ×%d non regarni (%s)', payload.item, payload.quantity, tostring(code)) end
end

--- Le personnage quitte le jeu : son catalogue disparaît.
---@param src integer
function catalog.forget(src)
    local container = active[src]
    if not container then return end
    active[src], ownerOf[container.id] = nil, nil
    viewers.closeContainer(container.id)
    containers.unload(container.id)
end

-- Commande et bandeau ---------------------------------------------------------------------------------------------

---@param src integer
---@return boolean
local function allowed(src)
    if src == CONSOLE then return true end
    if GetResourceState(ADMIN) == 'started' then
        local called, can = pcall(function() return exports[ADMIN]:can(src, cfg.permission) end)
        return called and can == true
    end
    return IsPlayerAceAllowed(src, cfg.ace) == true
end

--- Journal du Conseil quand il est là : des objets ont été donnés sans contrepartie.
---@param src integer
---@param details table
local function adminLog(src, details)
    if src == CONSOLE or GetResourceState(ADMIN) ~= 'started' then return end
    pcall(function() exports[ADMIN]:log(src, 'Catalogue de développement', details) end)
end

---@param src integer
---@param message string
local function reply(src, message)
    if src == CONSOLE then
        VavaInventory.log.info('%s', message)
    else
        TriggerClientEvent(EVENTS.NOTIFY, src, message)
    end
end

--- `/catalogue [catégorie] [page]` en jeu ; `catalogue <joueur> [catégorie] [page]` depuis la console. Les deux
--- arguments facultatifs se reconnaissent à leur forme (un nombre est une page) et s'écrivent dans n'importe quel ordre.
---@param source integer
---@param args string[]
local function command(source, args)
    if not allowed(source) then return reply(source, 'Le catalogue est réservé au Conseil.') end
    local target, first = source, 1
    if source == CONSOLE then
        target, first = tointeger(tonumber(args[1])), 2
        if not target then return reply(source, format('usage : %s <joueur> [catégorie] [page]', cfg.command)) end
    end
    local category, page
    for i = first, #args do
        local n = tointeger(tonumber(args[i]))
        if n then page = n else category = tostring(args[i]):lower() end
    end
    local ok, message = catalog.open(target, category, page)
    if ok then adminLog(source, { joueur = target, categorie = category or 'toutes', page = page or 1 }) end
    reply(source, message)
end

--- Bandeau de l'interface (RPC) : catégorie ('' pour toutes), page, recherche. Même droit que la commande ; le
--- conteneur renvoyé au joueur porte le nouvel état. Les gestes du bandeau ne passent pas au journal du Conseil :
--- l'ouverture y est déjà.
---@param src integer
---@param category string
---@param page integer
---@param query string
---@return boolean ok
---@return string|nil code
function catalog.request(src, category, page, query)
    if not cfg.enabled or not allowed(src) then return false, 'refused' end
    local ok, message = catalog.open(src, category ~= '' and category or nil, page, query)
    if not ok then return false, message end
    return true
end

--- Enregistre la commande, le regarnissage et le nettoyage, si le catalogue est activé. Appelé pendant le setup.
---@return boolean ok
---@return string|nil err
function catalog.start()
    if not cfg.enabled then return true end
    local hooks = VavaInventory.core.hooks
    local id, err = hooks.after('core:character:unloading', function(payload) catalog.forget(payload.source) end)
    if not id then return false, err end
    for _, hook in ipairs(TAKING_HOOKS) do
        id, err = hooks.after(hook, refill)
        if not id then return false, err end
    end
    RegisterCommand(cfg.command, command, false)
    VavaInventory.log.warn('catalogue de développement activé (/%s) : tout objet y est gratuit, à désactiver en production (config.catalog.enabled)',
        cfg.command)
    return true
end
